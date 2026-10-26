package com.zolmid.zolnit.renewal

import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import okhttp3.Call
import okhttp3.Callback
import okhttp3.CookieJar
import okhttp3.MediaType
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import okio.BufferedSource
import okio.Timeout
import org.junit.Assert.*
import org.junit.Test
import java.net.Proxy

private class FixtureCall(private val request: Request, private val response: Response?) : Call {
    var cancelled = false
    private var executed = false
    override fun request() = request
    override fun execute(): Response = error("unexpected_sync_call")
    override fun enqueue(responseCallback: Callback) {
        executed = true
        response?.let { responseCallback.onResponse(this, it.newBuilder().request(request).build()) }
    }
    override fun cancel() { cancelled = true }
    override fun isExecuted() = executed
    override fun isCanceled() = cancelled
    override fun timeout() = Timeout()
    override fun clone(): Call = FixtureCall(request, response)
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ClientBundleHttpTransportTest {
    private fun response(code: Int, body: ResponseBody, retry: String? = null): Response = Response.Builder()
        .request(Request.Builder().url("https://fixture.invalid").build()).protocol(Protocol.HTTP_1_1)
        .code(code).message("fixture").body(body).apply { retry?.let { header("Retry-After", it) } }.build()

    @Test fun defaultClientDisablesCookiesCacheRedirectsAndUsesTotal15SecondDeadline() {
        val client = ClientBundleHttpTransport.newClient()
        assertSame(CookieJar.NO_COOKIES, client.cookieJar)
        assertNull(client.cache)
        assertEquals(Proxy.NO_PROXY, client.proxy)
        assertFalse(client.followRedirects)
        assertFalse(client.followSslRedirects)
        assertFalse(client.retryOnConnectionFailure)
        assertEquals(15_000, client.callTimeoutMillis)
    }

    @Test fun fixedGetCarriesExistingBearerAndActualVersionWithoutCookies() = runTest {
        var captured: Request? = null
        val transport = ClientBundleHttpTransport(Call.Factory { request ->
            captured = request
            FixtureCall(request, response(200, "{}".toResponseBody()))
        })
        val response = transport.get("Bearer fixture", "core-fixture-version")
        assertEquals(200, response.status)
        val request = captured!!
        assertEquals(ClientBundleHttpTransport.ENDPOINT, request.url.toString())
        assertEquals("GET", request.method)
        assertEquals("Bearer fixture", request.header("Authorization"))
        assertEquals("core-fixture-version", request.header("X-ZolNit-Core-Version"))
        assertEquals("android", request.header("X-ZolNit-Platform"))
        assertEquals("direct", request.header("X-ZolNit-Distribution"))
        assertEquals("no-store", request.header("Cache-Control"))
        assertNull(request.header("Cookie"))
    }

    @Test fun rejectsOversizeKnownAndUnknownLengthAndMalformedUtf8() = runTest {
        val oversize = ByteArray(ClientBundleHttpTransport.MAX_BYTES + 1)
        val unknown = object : ResponseBody() {
            override fun contentType(): MediaType? = null
            override fun contentLength() = -1L
            override fun source(): BufferedSource = Buffer().write(oversize)
        }
        for (body in listOf(oversize.toResponseBody(), unknown, byteArrayOf(0xc3.toByte(), 0x28).toResponseBody())) {
            val transport = ClientBundleHttpTransport(Call.Factory { request -> FixtureCall(request, response(200, body)) })
            assertTrue(runCatching { transport.get("Bearer fixture", "v") }.isFailure)
        }
    }

    @Test fun cancellationCancelsPhysicalCall() = runTest {
        lateinit var call: FixtureCall
        val transport = ClientBundleHttpTransport(Call.Factory { request -> FixtureCall(request, null).also { call = it } })
        val job = launch { transport.get("Bearer fixture", "v") }
        runCurrent()
        job.cancel()
        runCurrent()
        assertTrue(call.cancelled)
    }

    @Test fun explicitCancelCancelsPhysicalCallAnd429PreservesRetryAfter() = runTest {
        lateinit var call: FixtureCall
        val transport = ClientBundleHttpTransport(Call.Factory { request -> FixtureCall(request, null).also { call = it } })
        val job = launch { transport.get("Bearer fixture", "v") }
        runCurrent()
        transport.cancel()
        assertTrue(call.cancelled)
        job.cancel()
        val throttled = ClientBundleHttpTransport(Call.Factory { request ->
            FixtureCall(request, response(429, "".toResponseBody(), "180"))
        }).get("Bearer fixture", "v")
        assertEquals(180_000L, throttled.retryAfterMillis)
        assertEquals(180_000L, ClientBundleHttpTransport.retryAfter("Thu, 01 Jan 1970 00:03:00 GMT", 0))
    }
}
