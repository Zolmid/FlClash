package com.zolmid.zolnit.network

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import okhttp3.Call
import okhttp3.Callback
import okhttp3.CookieJar
import okhttp3.EventListener
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import okio.Timeout
import org.junit.Assert.*
import org.junit.Test
import java.io.IOException
import java.net.InetAddress
import java.net.Proxy
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

private fun arguments(client: String = "client-a", id: String = "1", extra: Map<String, Any> = emptyMap()) =
    mapOf(
        "clientId" to client, "requestId" to id,
        "url" to "https://link.zolmid.com/api/v1/guest/comm/config",
        "method" to "GET", "headers" to emptyMap<String, String>(), "body" to ByteArray(0),
    ) + extra

private class PendingHttpCall(private val request: Request) : Call {
    var cancelled = false
    var enqueued = false
    lateinit var callback: Callback
    override fun request() = request
    override fun execute(): Response = error("unexpected synchronous request")
    override fun enqueue(responseCallback: Callback) { enqueued = true; callback = responseCallback }
    override fun cancel() { cancelled = true }
    override fun isExecuted() = enqueued
    override fun isCanceled() = cancelled
    override fun timeout() = Timeout()
    override fun clone(): Call = PendingHttpCall(request)
    fun respond() = callback.onResponse(this, Response.Builder()
        .request(request).protocol(Protocol.HTTP_1_1).code(200).message("fixture")
        .body("{}".toResponseBody()).build())
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class FirstPartyHttpTransportTest {
    @Test fun signedSubscriptionHeadersReachNativeRequest() = runTest {
        val headers = mapOf(
            "X-ZolNit-Device-Id" to "fixture-device",
            "X-ZolNit-Installation" to "fixture-installation",
            "X-ZolNit-Subscription-Format" to "signed-v2",
            "Idempotency-Key" to "fixture-idempotency-key",
        )
        var call: PendingHttpCall? = null
        val transport = FirstPartyHttpTransport(
            selectCalls = { Call.Factory { PendingHttpCall(it).also { pending -> call = pending } } },
            scope = backgroundScope,
        )
        var result: Result<Map<String, Any>>? = null
        transport.submit(arguments(extra = mapOf("headers" to headers, "method" to "POST"))) { result = it }
        runCurrent()
        val pending = requireNotNull(call)
        assertEquals("POST", pending.request().method)
        headers.forEach { (name, value) -> assertEquals(value, pending.request().header(name)) }
        pending.respond()
        runCurrent()
        assertTrue(result!!.isSuccess)
        assertThrows(IllegalArgumentException::class.java) {
            FirstPartyRequest.parse(arguments(extra = mapOf("headers" to (headers + ("X-Not-Allowed" to "fixture")))))
        }
    }

    @Test fun acceptsFixedOriginQueryAndOneShotPost() {
        val request = FirstPartyRequest.parse(arguments(extra = mapOf(
            "url" to "https://link.zolmid.com/api/v1/guest/comm/config?locale=en-US",
            "method" to "POST",
            "headers" to mapOf("Authorization" to "Bearer fixture"),
            "body" to byteArrayOf(1, 2, 3),
        )))
        val native = request.toHttpRequest()
        assertEquals("POST", native.method)
        assertTrue(native.body!!.isOneShot())
        val output = Buffer()
        native.body!!.writeTo(output)
        assertArrayEquals(byteArrayOf(1, 2, 3), output.readByteArray())
        assertThrows(IllegalStateException::class.java) { native.body!!.writeTo(Buffer()) }
    }

    @Test fun rejectsForeignOriginPortCredentialsFragmentsAndPaths() {
        for (url in listOf(
            "http://link.zolmid.com/api/v1/user/info",
            "https://example.com/api/v1/user/info",
            "https://link.zolmid.com.evil/api/v1/user/info",
            "https://link.zolmid.com:444/api/v1/user/info",
            "https://user@link.zolmid.com/api/v1/user/info",
            "https://link.zolmid.com/api/v1/user/info#fragment",
            "https://link.zolmid.com/other",
            "https://link.zolmid.com/api/v1/user/../info",
            "https://link.zolmid.com/api/v1/user/%2e%2e/info",
            "https://link.zolmid.com/api/v1/user/info?q=" + "a".repeat(8_192),
        )) {
            assertThrows(IllegalArgumentException::class.java) {
                FirstPartyRequest.parse(arguments(extra = mapOf("url" to url)))
            }
        }
    }

    @Test fun rejectsUnexpectedMethodsHeadersBodiesAndSizes() {
        for (extra in listOf(
            mapOf("method" to "PUT"),
            mapOf("headers" to mapOf("Cookie" to "secret")),
            mapOf("headers" to mapOf("Host" to "foreign.example")),
            mapOf("headers" to mapOf("Authorization" to "Bearer fixture\r\nCookie: secret")),
            mapOf("headers" to mapOf("User-Agent" to "a".repeat(8_193))),
            mapOf("headers" to mapOf("Accept" to "a".repeat(8_000), "Authorization" to "b".repeat(8_000), "User-Agent" to "c".repeat(8_000))),
            mapOf("headers" to mapOf("Accept" to "a", "ACCEPT" to "b")),
            mapOf("body" to byteArrayOf(1)),
            mapOf("method" to "POST", "body" to ByteArray(1_024 * 1_024 + 1)),
            mapOf("clientId" to ""),
        )) {
            assertThrows(IllegalArgumentException::class.java) { FirstPartyRequest.parse(arguments(extra = extra)) }
        }
    }

    @Test fun clientAndRequestCancellationAreIsolatedAndCompleteOnce() = runTest {
        val calls = mutableListOf<PendingHttpCall>()
        val results = mutableListOf<Pair<String, Result<Map<String, Any>>>>()
        val transport = FirstPartyHttpTransport(
            selectCalls = { Call.Factory { PendingHttpCall(it).also(calls::add) } },
            scope = backgroundScope,
        )
        transport.submit(arguments()) { results.add("a" to it) }
        transport.submit(arguments(client = "client-b")) { results.add("b" to it) }
        runCurrent()
        assertEquals(2, calls.size)
        transport.cancel(arguments(client = "wrong-client"))
        assertFalse(calls[0].cancelled)
        transport.cancel(arguments())
        runCurrent()
        assertTrue(calls[0].cancelled)
        assertFalse(calls[1].cancelled)
        calls[0].respond()
        calls[1].respond()
        runCurrent()
        assertEquals(2, results.size)
        assertTrue(results.single { it.first == "a" }.second.isFailure)
        assertTrue(results.single { it.first == "b" }.second.isSuccess)
        transport.close()
    }

    @Test fun cancellationBeforeDispatchNeverStartsNetworkOrPost() = runTest {
        var selected = 0
        val results = mutableListOf<Result<Map<String, Any>>>()
        val transport = FirstPartyHttpTransport(
            selectCalls = { selected++; error("must not dispatch") }, scope = backgroundScope,
        )
        transport.submit(arguments(extra = mapOf("method" to "POST"))) { results.add(it) }
        transport.cancel(arguments())
        runCurrent()
        assertEquals(0, selected)
        assertEquals(1, results.size)
        assertTrue(results.single().isFailure)
        transport.close()
    }

    @Test fun networkWaitingIsCancelledAndDeadlineStartsBeforeHttpDispatch() = runTest {
        var cleanups = 0
        val results = mutableListOf<Result<Map<String, Any>>>()
        val transport = FirstPartyHttpTransport(
            selectCalls = { try { awaitCancellation() } finally { cleanups++ } },
            scope = backgroundScope, timeoutMillis = 100,
        )
        transport.submit(arguments()) { results.add(it) }
        runCurrent()
        advanceTimeBy(101)
        runCurrent()
        assertEquals(1, cleanups)
        assertEquals(1, results.size)
        assertTrue(results.single().isFailure)
        transport.close()
    }

    @Test fun deadlineCancelsQueuedHttpCallAndLateCallbackCannotCompleteTwice() = runTest {
        lateinit var call: PendingHttpCall
        val results = mutableListOf<Result<Map<String, Any>>>()
        val transport = FirstPartyHttpTransport(
            selectCalls = { Call.Factory { PendingHttpCall(it).also { call = it } } },
            scope = backgroundScope, timeoutMillis = 100,
        )
        transport.submit(arguments(extra = mapOf("method" to "POST"))) { results.add(it) }
        runCurrent()
        advanceTimeBy(101)
        runCurrent()
        assertTrue(call.cancelled)
        assertEquals(1, results.size)
        call.respond()
        runCurrent()
        assertEquals(1, results.size)
        transport.close()
    }

    @Test fun engineDetachCancelsAllWaitingRequestsAndAdmissionIsBounded() = runTest {
        val results = mutableListOf<Result<Map<String, Any>>>()
        val transport = FirstPartyHttpTransport(selectCalls = { awaitCancellation() }, scope = backgroundScope)
        repeat(FirstPartyHttpTransport.MAX_PENDING + 1) { index ->
            transport.submit(arguments(id = index.toString())) { results.add(it) }
        }
        assertEquals(1, results.size)
        transport.close()
        runCurrent()
        assertEquals(FirstPartyHttpTransport.MAX_PENDING + 1, results.size)
        assertTrue(results.all { it.isFailure })
    }

    @Test fun realSlowDripPostIsCancelledByTotalDeadlineWithoutReplay() {
        ServerSocket(0, 8, InetAddress.getByName("127.0.0.1")).use { server ->
            val headersSeen = AtomicInteger()
            val bytesSent = AtomicInteger()
            val finished = CountDownLatch(1)
            val receivedHeaders = mutableListOf<String>()
            val connection = CompletableDeferred<Socket>()
            val writer = thread(isDaemon = true) {
                runCatching {
                    server.accept().use { socket ->
                        connection.complete(socket)
                        socket.soTimeout = 2_000
                        val reader = socket.getInputStream().bufferedReader()
                        while (true) {
                            val line = reader.readLine() ?: break
                            if (line.isEmpty()) break
                            synchronized(receivedHeaders) { receivedHeaders.add(line) }
                        }
                        socket.getOutputStream().apply {
                            write("HTTP/1.1 200 OK\r\nContent-Length: 100000\r\n\r\n".toByteArray())
                            while (true) {
                                write(65)
                                flush()
                                bytesSent.incrementAndGet()
                                Thread.sleep(20)
                            }
                        }
                    }
                }
            }
            val client = FirstPartyHttpTransport.newClient().newBuilder()
                .eventListener(object : EventListener() {
                    override fun requestHeadersStart(call: Call) { headersSeen.incrementAndGet() }
                }).build()
            lateinit var call: Call
            val transport = FirstPartyHttpTransport(
                selectCalls = { Call.Factory {
                    client.newCall(it.newBuilder().url("http://127.0.0.1:${server.localPort}/").build())
                        .also { real -> call = real }
                } },
                timeoutMillis = 750,
            )
            val results = mutableListOf<Result<Map<String, Any>>>()
            val started = System.nanoTime()
            try {
                transport.submit(arguments(extra = mapOf(
                    "method" to "POST",
                    "headers" to mapOf("Idempotency-Key" to "fixture-idempotency-key"),
                ))) {
                    synchronized(results) { results.add(it) }
                    finished.countDown()
                }
                assertTrue(finished.await(3, TimeUnit.SECONDS))
                assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 2_500)
                assertTrue(bytesSent.get() > 1)
                assertTrue(call.isCanceled())
                assertTrue(results.single().isFailure)
                writer.join(2_000)
                assertFalse("socket must close even while response keeps arriving", writer.isAlive)
                assertEquals(1, headersSeen.get())
                assertTrue(synchronized(receivedHeaders) {
                    receivedHeaders.any { it.equals("Idempotency-Key: fixture-idempotency-key", ignoreCase = true) }
                })
                assertEquals(1, results.size)
            } finally {
                transport.close()
                client.dispatcher.executorService.shutdownNow()
                client.connectionPool.evictAll()
                if (connection.isCompleted) kotlinx.coroutines.runBlocking { connection.await().close() }
                server.close()
                writer.join(2_000)
            }
        }
    }

    @Test fun connectionFailureFallsBackBeforeSendingOneShotPost() {
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { server ->
            val received = AtomicInteger()
            val worker = thread(isDaemon = true) {
                server.accept().use { socket ->
                    val reader = socket.getInputStream().bufferedReader()
                    while (!reader.readLine().isNullOrEmpty()) {}
                    received.incrementAndGet()
                    socket.getOutputStream().write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}".toByteArray())
                }
            }
            val client = FirstPartyHttpTransport.newClient().newBuilder()
                .dns(object : okhttp3.Dns {
                    override fun lookup(hostname: String) =
                        listOf(InetAddress.getByName("127.0.0.2"), InetAddress.getByName("127.0.0.1"))
                }).build()
            try {
                val post = FirstPartyRequest.parse(arguments(extra = mapOf("method" to "POST")))
                    .toHttpRequest().newBuilder().url("http://fallback.invalid:${server.localPort}/").build()
                client.newCall(post).execute().use { assertEquals(200, it.code) }
                assertEquals(1, received.get())
            } finally {
                client.dispatcher.executorService.shutdownNow()
                client.connectionPool.evictAll()
                server.close()
                worker.join(2_000)
            }
        }
    }

    @Test fun clientUsesStrictDefaultsAndBoundedWorkers() {
        val client = FirstPartyHttpTransport.newClient()
        try {
            assertSame(CookieJar.NO_COOKIES, client.cookieJar)
            assertEquals(Proxy.NO_PROXY, client.proxy)
            assertNull(client.cache)
            assertFalse(client.followRedirects)
            assertFalse(client.followSslRedirects)
            assertEquals(15_000, client.callTimeoutMillis)
            val executor = client.dispatcher.executorService as java.util.concurrent.ThreadPoolExecutor
            assertEquals(8, executor.maximumPoolSize)
            assertEquals(24, executor.queue.remainingCapacity())
        } finally {
            client.dispatcher.executorService.shutdownNow()
        }
    }
}
