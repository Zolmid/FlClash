package com.zolmid.zolnit.renewal

import android.os.SystemClock
import com.zolmid.zolnit.ServiceController
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
            transport = ClientBundleHttpTransport(),
            mainBarrier = { action -> withContext(Dispatchers.Main.immediate) { action() } },
            monotonicMillis = SystemClock::elapsedRealtime,
        )
    }

    suspend fun configure(accountId: String, authorization: String, accountGeneration: Long) =
        coordinator.configure(accountId, authorization, accountGeneration)

    suspend fun logout(epoch: Long) = coordinator.logout(epoch)
    suspend fun status() = coordinator.authoritativeStatus()
    suspend fun start() = coordinator.start()
    suspend fun stop() = coordinator.stop()

    private suspend fun invoke(method: String, arguments: JSONObject?): Any? =
        suspendCancellableCoroutine { continuation ->
            val id = "android-bundle-${ids.incrementAndGet()}"
            val request = JSONObject().put("id", id).put("method", method)
                .put("arguments", arguments ?: JSONObject.NULL).toString()
            ServiceController.invokeMethod(request) { bytes ->
                val result = runCatching {
                    val response = JSONObject(bytes.toString(Charsets.UTF_8))
                    check(response.optString("id") == id && response.isNull("error") && response.isNull("file"))
                    response.opt("result").takeUnless { it == JSONObject.NULL }
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
