package com.zolmid.zolnit.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Process
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import okhttp3.Call
import okhttp3.Dns
import okhttp3.OkHttpClient
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal data class FirstPartyNetwork<N>(
    val network: N,
    val internet: Boolean,
    val vpn: Boolean,
    val validated: Boolean,
    val ownerUid: Int? = null,
)

internal interface FirstPartyNetworks<N> {
    val apiLevel: Int
    val myUid: Int
    fun active(): FirstPartyNetwork<N>?
    fun all(): List<FirstPartyNetwork<N>>
    suspend fun awaitDefault(): FirstPartyNetwork<N>
    suspend fun awaitUnderlying(): FirstPartyNetwork<N>
}

internal class FirstPartyNetworkSelector<N>(
    private val networks: FirstPartyNetworks<N>,
    private val ownVpnActive: suspend () -> Boolean,
) {
    suspend fun select(): N {
        val active = networks.active() ?: networks.awaitDefault()
        val legacyOwnVpn = networks.apiLevel < 29 && active.vpn && ownVpnActive()
        if (!shouldBypassOwnVpn(networks.apiLevel, active.vpn, active.ownerUid, networks.myUid, legacyOwnVpn)) {
            return active.network
        }
        val candidates = networks.all().filter { it.internet && !it.vpn }
        val selected = candidates.firstOrNull { it.validated } ?: candidates.firstOrNull()
            ?: networks.awaitUnderlying()
        require(selected.internet && !selected.vpn)
        return selected.network
    }
}

internal fun shouldBypassOwnVpn(
    apiLevel: Int,
    vpn: Boolean,
    ownerUid: Int?,
    myUid: Int,
    ownVpnActive: Boolean,
): Boolean = vpn && if (apiLevel >= 29) ownerUid == myUid else ownVpnActive

internal fun firstPartyNetworkRequestCapabilities(): List<Int> = listOf(
    NetworkCapabilities.NET_CAPABILITY_INTERNET,
    NetworkCapabilities.NET_CAPABILITY_NOT_VPN,
)

internal class AndroidFirstPartyCalls(
    context: Context,
    private val client: OkHttpClient,
    ownVpnActive: suspend () -> Boolean,
) {
    private val networks = FirstPartyNetworkSelector(AndroidFirstPartyNetworks(context), ownVpnActive)

    suspend fun select(): Call.Factory {
        val network = networks.select()
        return client.newBuilder().socketFactory(network.socketFactory)
            .dns(object : Dns {
                override fun lookup(hostname: String) = network.getAllByName(hostname).toList()
            }).build()
    }
}

internal class AndroidFirstPartyNetworks(context: Context) : FirstPartyNetworks<Network> {
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    override val apiLevel get() = Build.VERSION.SDK_INT
    override val myUid get() = Process.myUid()

    private fun snapshot(network: Network, capabilities: NetworkCapabilities) = FirstPartyNetwork(
        network,
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN),
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
        if (Build.VERSION.SDK_INT >= 29) capabilities.ownerUid else null,
    )

    override fun active() = connectivity.activeNetwork?.let { network ->
        connectivity.getNetworkCapabilities(network)?.let { snapshot(network, it) }
    }

    override fun all() = connectivity.allNetworks.mapNotNull { network ->
        connectivity.getNetworkCapabilities(network)?.let { snapshot(network, it) }
    }

    override suspend fun awaitDefault() = awaitNetwork(underlying = false)
    override suspend fun awaitUnderlying() = awaitNetwork(underlying = true)

    private suspend fun awaitNetwork(underlying: Boolean): FirstPartyNetwork<Network> =
        withTimeout(5_000) {
            suspendCancellableCoroutine { continuation ->
                val finished = AtomicBoolean()
                lateinit var registration: FirstPartyCallbackRegistration
                val callback = object : ConnectivityManager.NetworkCallback() {
                    override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                        val candidate = snapshot(network, capabilities)
                        if (underlying && (!candidate.internet || candidate.vpn)) return
                        if (finished.compareAndSet(false, true)) {
                            registration.close()
                            continuation.resume(candidate)
                        }
                    }

                    override fun onUnavailable() {
                        if (finished.compareAndSet(false, true)) {
                            registration.close()
                            continuation.resumeWithException(IOException("first_party_network_unavailable"))
                        }
                    }
                }
                registration = FirstPartyCallbackRegistration {
                    runCatching { connectivity.unregisterNetworkCallback(callback) }
                }
                continuation.invokeOnCancellation {
                    finished.set(true)
                    registration.close()
                }
                if (!continuation.isActive) return@suspendCancellableCoroutine
                try {
                    if (underlying) {
                        val builder = NetworkRequest.Builder().clearCapabilities()
                        firstPartyNetworkRequestCapabilities().forEach(builder::addCapability)
                        connectivity.requestNetwork(builder.build(), callback, 5_000)
                    } else {
                        connectivity.registerDefaultNetworkCallback(callback)
                    }
                    registration.registered()
                } catch (error: Exception) {
                    registration.close()
                    if (finished.compareAndSet(false, true)) continuation.resumeWithException(error)
                }
            }
        }
}

internal class FirstPartyCallbackRegistration(private val unregister: () -> Unit) {
    private var registered = false
    private var closed = false

    @Synchronized fun registered() {
        registered = true
        if (closed) {
            registered = false
            unregister()
        }
    }

    @Synchronized fun close() {
        closed = true
        if (registered) {
            registered = false
            unregister()
        }
    }
}
