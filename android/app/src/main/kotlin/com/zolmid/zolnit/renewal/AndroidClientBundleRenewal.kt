package com.zolmid.zolnit.renewal

import android.os.SystemClock
import android.util.Base64
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import com.zolmid.zolnit.ServiceController
import com.zolmid.zolnit.ServiceState
import com.zolmid.zolnit.common.GlobalState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicLong
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal object AndroidClientBundleRenewal {
    private val ids = AtomicLong()
    private val coordinator by lazy {
        ClientBundleRenewal(
            scope = GlobalState,
            store = ClientBundleEpochStore(FlutterBundleSecurePreferences(GlobalState.application)),
            rpc = BundleRpc { method, args -> invoke(method, args) },
            transport = ClientBundleHttpTransport.android(GlobalState.application) {
                ServiceState.awaitActiveVpnOptions()?.enable == true
            },
            mainBarrier = { action -> withContext(Dispatchers.Main.immediate) { action() } },
            monotonicMillis = SystemClock::elapsedRealtime,
        )
    }

    suspend fun configure(accountId: String, authorization: String, accountGeneration: Long, device: SignedDevice?) =
        coordinator.configure(accountId, authorization, accountGeneration, device)

    suspend fun logout(epoch: Long) = coordinator.logout(epoch)
    suspend fun status() = coordinator.authoritativeStatus()
    suspend fun start() = coordinator.start()
    suspend fun stop() = coordinator.stop()

    internal suspend fun ownedExchange(url: String, authorization: String, version: String,
        extra: Map<String, String>): BundleHttpResponse? {
        val request = "dns-${ids.incrementAndGet()}"
        val headers = JSONObject(extra).put("Authorization", authorization).put("Accept", "application/json")
            .put("X-ZolNit-Core-Version", version).put("X-ZolNit-Platform", "android")
            .put("X-ZolNit-Distribution", "direct")
        val arguments = JSONObject().put("client-id", "android-owned-dns").put("request-id", request)
            .put("owned-dns-only", true).put("method", "GET").put("url", url)
            .put("headers", headers).put("body", "").put("timeout", 15000)
        try {
            val value = checkNotNull(invoke("firstPartyHTTP", arguments) as? JSONObject)
            if (value.optBoolean("ownedDnsDisabled")) return null
            val bytes = Base64.decode(value.getString("body"), Base64.DEFAULT)
            require(bytes.size <= 8 * 1024 * 1024)
            val status = value.getInt("status")
            require(status in 100..599 && (status != 401 || bytes.size <= 8 * 1024))
            return BundleHttpResponse(status, bytes.toString(Charsets.UTF_8),
                ClientBundleHttpTransport.retryAfter(value.optJSONObject("headers")?.optString("Retry-After")))
        } finally {
            if (!currentCoroutineContext().isActive) withContext(NonCancellable) {
                invoke("cancelFirstPartyHTTP", JSONObject().put("client-id", "android-owned-dns").put("request-id", request))
            }
        }
    }

    private suspend fun invoke(method: String, arguments: JSONObject?): Any? =
        suspendCancellableCoroutine { continuation ->
            val id = "android-bundle-${ids.incrementAndGet()}"
            val request = JSONObject().put("id", id).put("method", method)
                .put("arguments", arguments ?: JSONObject.NULL).toString()
            ServiceController.invokeMethod(request) { bytes ->
                val result = runCatching {
                    val response = JSONObject(bytes.toString(Charsets.UTF_8))
                    check(response.optString("id") == id && response.isNull("file"))
                    if (method == "firstPartyHTTP" && response.optJSONObject("error")?.optString("code") == "owned_dns_disabled") {
                        JSONObject().put("ownedDnsDisabled", true)
                    } else {
                    check(response.isNull("error"))
                        response.opt("result").takeUnless { it == JSONObject.NULL }
                    }
                }
                if (continuation.isActive) result.fold(
                    { continuation.resume(it) },
                    { continuation.resumeWithException(IllegalStateException("bundle_core_rpc_failed")) },
                )
            }.onFailure {
                if (continuation.isActive) continuation.resumeWithException(IllegalStateException("bundle_core_rpc_failed"))
            }
        }
}
