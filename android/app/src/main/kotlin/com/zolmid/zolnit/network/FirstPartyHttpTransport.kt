package com.zolmid.zolnit.network

import android.content.Context
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import okhttp3.Call
import okhttp3.Callback
import okhttp3.ConnectionPool
import okhttp3.CookieJar
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okio.BufferedSink
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.Proxy
import java.net.URI
import java.util.Locale
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class FirstPartyHttpTransport(
    private val selectCalls: suspend () -> Call.Factory,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default),
    private val timeoutMillis: Long = 15_000,
    private val dispose: () -> Unit = {},
) {
    private val requests = mutableMapOf<FirstPartyRequestId, Job>()
    private var closed = false

    fun submit(arguments: Map<*, *>, complete: (Result<Map<String, Any>>) -> Unit) {
        val request = runCatching { FirstPartyRequest.parse(arguments) }.getOrElse {
            complete(Result.failure(it))
            return
        }
        val completed = AtomicBoolean()
        fun finish(result: Result<Map<String, Any>>) {
            if (completed.compareAndSet(false, true)) complete(result)
        }
        val job: Job
        synchronized(requests) {
            if (closed || requests.size >= MAX_PENDING || requests.containsKey(request.id)) {
                complete(Result.failure(IOException("first_party_request_unavailable")))
                return
            }
            job = scope.launch(start = CoroutineStart.LAZY) {
                finish(runCatching {
                    withTimeout(timeoutMillis) {
                        val calls = selectCalls()
                        currentCoroutineContext().ensureActive()
                        exchange(calls, request)
                    }
                })
            }
            requests[request.id] = job
        }
        job.invokeOnCompletion { cause ->
            synchronized(requests) { requests.remove(request.id, job) }
            finish(Result.failure(cause ?: CancellationException("first_party_cancelled")))
        }
        job.start()
    }

    fun cancel(arguments: Map<*, *>) {
        val id = FirstPartyRequestId.parse(arguments)
        synchronized(requests) { requests[id] }?.cancel()
    }

    fun close() {
        val pending = synchronized(requests) {
            if (closed) return
            closed = true
            requests.values.toList()
        }
        pending.forEach { it.cancel() }
        scope.cancel()
        dispose()
    }

    private suspend fun exchange(calls: Call.Factory, request: FirstPartyRequest): Map<String, Any> =
        suspendCancellableCoroutine { continuation ->
            val call = calls.newCall(request.toHttpRequest())
            continuation.invokeOnCancellation { call.cancel() }
            if (!continuation.isActive) return@suspendCancellableCoroutine
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    continuation.resumeWithException(IOException("first_party_http_failed"))
                }

                override fun onResponse(call: Call, response: Response) {
                    val result = runCatching {
                        response.use {
                            check(continuation.isActive && !call.isCanceled())
                            require(it.headers.byteCount() <= MAX_HEADER_BYTES)
                            val body = requireNotNull(it.body)
                            require(body.contentLength() <= MAX_RESPONSE_BYTES)
                            val output = ByteArrayOutputStream()
                            body.byteStream().use { stream ->
                                val buffer = ByteArray(8_192)
                                while (true) {
                                    check(continuation.isActive && !call.isCanceled())
                                    val count = stream.read(buffer)
                                    if (count < 0) break
                                    require(output.size() + count <= MAX_RESPONSE_BYTES)
                                    output.write(buffer, 0, count)
                                }
                            }
                            mapOf(
                                "status" to it.code,
                                "headers" to it.headers.toMultimap().mapValues { (_, v) -> v.joinToString(", ") },
                                "body" to output.toByteArray(),
                            )
                        }
                    }
                    result.fold(
                        { continuation.resume(it) },
                        {
                            call.cancel()
                            continuation.resumeWithException(IOException("first_party_response_failed"))
                        },
                    )
                }
            })
        }

    companion object {
        const val MAX_PENDING = 32
        const val MAX_RESPONSE_BYTES = 8 * 1_024 * 1_024
        const val MAX_HEADER_BYTES = 16 * 1_024

        fun android(context: Context, ownVpnActive: suspend () -> Boolean): FirstPartyHttpTransport {
            val client = newClient()
            val calls = AndroidFirstPartyCalls(context, client, ownVpnActive)
            return FirstPartyHttpTransport(
                selectCalls = calls::select,
                dispose = {
                    client.dispatcher.cancelAll()
                    client.dispatcher.executorService.shutdownNow()
                    client.connectionPool.evictAll()
                },
            )
        }

        fun newClient(): OkHttpClient {
            val executor = ThreadPoolExecutor(8, 8, 30, TimeUnit.SECONDS, ArrayBlockingQueue(24)) {
                runnable -> Thread(runnable, "zolnit-control-plane").apply { isDaemon = true }
            }.apply { allowCoreThreadTimeOut(true) }
            // Bound the executor queue too: cancelled calls can still be waiting for DNS or a worker.
            val dispatcher = okhttp3.Dispatcher(executor).apply {
                maxRequests = Int.MAX_VALUE
                maxRequestsPerHost = Int.MAX_VALUE
            }
            return OkHttpClient.Builder().dispatcher(dispatcher)
                .connectionPool(ConnectionPool(0, 1, TimeUnit.SECONDS))
                .cookieJar(CookieJar.NO_COOKIES).cache(null).proxy(Proxy.NO_PROXY)
                .followRedirects(false).followSslRedirects(false)
                .retryOnConnectionFailure(true)
                .callTimeout(15, TimeUnit.SECONDS).connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS).writeTimeout(10, TimeUnit.SECONDS).build()
        }
    }
}

internal data class FirstPartyRequestId(val client: String, val request: String) {
    companion object {
        fun parse(arguments: Map<*, *>): FirstPartyRequestId {
            fun id(key: String) = (arguments[key] as? String).also {
                require(it != null && it.length <= 80 && it.matches(Regex("[A-Za-z0-9_-]+")))
            }!!
            return FirstPartyRequestId(id("clientId"), id("requestId"))
        }
    }
}

internal data class FirstPartyRequest(
    val id: FirstPartyRequestId,
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: ByteArray,
) {
    fun toHttpRequest(): Request {
        val builder = Request.Builder().url(url)
        headers.forEach(builder::header)
        builder.header("Accept-Encoding", "identity").header("Cache-Control", "no-store")
        if (method == "GET") return builder.get().build()
        return builder.post(object : RequestBody() {
            private val written = AtomicBoolean()
            override fun contentType() = null
            override fun contentLength() = body.size.toLong()
            override fun isOneShot() = true
            override fun writeTo(sink: BufferedSink) {
                check(written.compareAndSet(false, true))
                sink.write(body)
            }
        }).build()
    }

    companion object {
        private val path = Regex("^/api/v1/[A-Za-z0-9_/-]+$")
        private val requestHeaders = setOf(
            "accept", "authorization", "content-language", "content-type", "user-agent",
            "x-zolnit-core-version", "x-zolnit-distribution", "x-zolnit-platform",
        )

        fun parse(arguments: Map<*, *>): FirstPartyRequest {
            val id = FirstPartyRequestId.parse(arguments)
            val url = requireNotNull(arguments["url"] as? String)
            require(url.length <= 8_192 && url.all { it.code in 33..126 })
            val uri = URI(url)
            require(uri.scheme == "https" && uri.host == "link.zolmid.com")
            require(uri.port == -1 || uri.port == 443)
            require(uri.rawUserInfo == null && uri.rawFragment == null)
            require(path.matches(uri.rawPath) && !uri.rawPath.contains(".."))
            val method = requireNotNull(arguments["method"] as? String)
            require(method == "GET" || method == "POST")
            val rawHeaders = requireNotNull(arguments["headers"] as? Map<*, *>)
            require(rawHeaders.size <= requestHeaders.size)
            val headers = rawHeaders.entries.associate { (key, value) ->
                require(key is String && value is String)
                val name = key.lowercase(Locale.ROOT)
                require(name in requestHeaders && value.length <= 8_192)
                require(value.all { it.code in 32..126 })
                name to value
            }
            require(headers.size == rawHeaders.size)
            require(headers.entries.sumOf { it.key.length + it.value.length } <= FirstPartyHttpTransport.MAX_HEADER_BYTES)
            val body = requireNotNull(arguments["body"] as? ByteArray)
            require(body.size <= 1_024 * 1_024)
            require(method == "POST" || body.isEmpty())
            return FirstPartyRequest(id, url, method, headers, body)
        }
    }
}
