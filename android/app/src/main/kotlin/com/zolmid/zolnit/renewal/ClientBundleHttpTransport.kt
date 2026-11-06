package com.zolmid.zolnit.renewal

import android.content.Context
import com.zolmid.zolnit.network.AndroidFirstPartyCalls
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import okhttp3.Call
import okhttp3.Callback
import okhttp3.CookieJar
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.Proxy
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class ClientBundleHttpTransport(
    private val calls: Call.Factory = newClient(),
    private val selectCalls: (suspend () -> Call.Factory)? = null,
) : BundleTransport {
    private val active = AtomicReference<Call?>()
    private val activeRequest = AtomicReference<Job?>()

    override suspend fun get(authorization: String, coreVersion: String): BundleHttpResponse = withTimeout(15_000) {
        val job = currentCoroutineContext()[Job]!!
        check(activeRequest.compareAndSet(null, job)) { "request_already_active" }
        try {
            val selected = selectCalls?.invoke() ?: calls
            currentCoroutineContext().ensureActive()
            get(selected, authorization, coreVersion)
        } finally {
            activeRequest.compareAndSet(job, null)
        }
    }

    private suspend fun get(calls: Call.Factory, authorization: String, coreVersion: String): BundleHttpResponse =
        suspendCancellableCoroutine { continuation ->
            val request = Request.Builder().url(ENDPOINT).get()
                .header("Authorization", authorization).header("Accept", "application/json")
                .header("Accept-Encoding", "identity").header("Cache-Control", "no-store")
                .header("X-ZolNit-Core-Version", coreVersion)
                .header("X-ZolNit-Platform", "android").header("X-ZolNit-Distribution", "direct")
                .build()
            val call = calls.newCall(request)
            check(active.compareAndSet(null, call)) { "request_already_active" }
            continuation.invokeOnCancellation {
                call.cancel()
                active.compareAndSet(call, null)
            }
            if (!continuation.isActive) return@suspendCancellableCoroutine
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    active.compareAndSet(call, null)
                    if (continuation.isActive) continuation.resumeWithException(IOException("bundle_transport_failed"))
                }

                override fun onResponse(call: Call, response: Response) {
                    val result = runCatching {
                        response.use {
                            check(continuation.isActive && !call.isCanceled())
                            if (it.code == 429) {
                                return@use BundleHttpResponse(it.code, "", retryAfter(it.header("Retry-After")))
                            }
                            val body = checkNotNull(it.body)
                            val maximumBytes = if (it.code == 401) AUTH_ERROR_MAX_BYTES else MAX_BYTES
                            require(body.contentLength() <= maximumBytes)
                            val bytes = ByteArrayOutputStream()
                            body.byteStream().use { stream ->
                                val buffer = ByteArray(8_192)
                                while (true) {
                                    check(continuation.isActive && !call.isCanceled())
                                    val count = stream.read(buffer)
                                    if (count < 0) break
                                    require(bytes.size() + count <= maximumBytes)
                                    bytes.write(buffer, 0, count)
                                }
                            }
                            val text = Charsets.UTF_8.newDecoder()
                                .onMalformedInput(CodingErrorAction.REPORT)
                                .onUnmappableCharacter(CodingErrorAction.REPORT)
                                .decode(ByteBuffer.wrap(bytes.toByteArray())).toString()
                            BundleHttpResponse(it.code, text, retryAfter(it.header("Retry-After")))
                        }
                    }
                    active.compareAndSet(call, null)
                    if (continuation.isActive) result.fold(
                        { continuation.resume(it) },
                        { continuation.resumeWithException(IOException("invalid_bundle_response")) },
                    )
                }
            })
        }

    override fun cancel() {
        activeRequest.get()?.cancel()
    }

    companion object {
        fun android(context: Context, ownVpnActive: suspend () -> Boolean): ClientBundleHttpTransport {
            val client = newClient().newBuilder().retryOnConnectionFailure(true).build()
            val bound = AndroidFirstPartyCalls(context, client, ownVpnActive)
            return ClientBundleHttpTransport(client, bound::select)
        }

        fun newClient(): OkHttpClient = OkHttpClient.Builder()
            .cookieJar(CookieJar.NO_COOKIES).cache(null).proxy(Proxy.NO_PROXY)
            .followRedirects(false).followSslRedirects(false).retryOnConnectionFailure(false)
            .callTimeout(15, TimeUnit.SECONDS).connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS).writeTimeout(15, TimeUnit.SECONDS).build()

        const val ENDPOINT = "https://link.zolmid.com/api/v1/zolnit/client/bundle"
        const val MAX_BYTES = 8 * 1_024 * 1_024
        const val AUTH_ERROR_MAX_BYTES = 8 * 1_024

        fun retryAfter(value: String?, now: Long = System.currentTimeMillis()): Long {
            val seconds = value?.trim()?.toLongOrNull()
            if (seconds != null && seconds >= 0) return seconds.coerceAtMost(Long.MAX_VALUE / 1_000) * 1_000
            return runCatching {
                val format = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("GMT")
                    isLenient = false
                }
                maxOf(0, checkNotNull(format.parse(checkNotNull(value))).time - now)
            }.getOrDefault(60_000)
        }
    }
}
