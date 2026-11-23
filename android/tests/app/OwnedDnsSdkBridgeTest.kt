package com.zolmid.zolnit.network

import org.junit.Assert.*
import org.junit.Test

private class SyntheticCloudDns : OwnedDnsSdkBackend {
    var configured = 0
    var lookups = 0
    var values = listOf("192.0.2.1", "2001:db8::1")
    var failed = false
    var onLookup: (() -> Unit)? = null
    override fun configure(port: Int, key: String, secret: String) { configured++ }
    override fun lookup(host: String): List<String> { lookups++; onLookup?.invoke(); if (failed) error("synthetic"); return values }
}

class OwnedDnsSdkBridgeTest {
    private fun arguments() = mapOf("hosts" to listOf("link.zolmid.com", "node.nodes.zolmid.com"),
        "port" to 34567, "keyId" to "a".repeat(64), "secret" to "b".repeat(64),
        "expiresAt" to System.currentTimeMillis() + 60_000)


    @Test fun disabledAndMissingCredentialsNeverInitializeVendor() {
        val sdk = SyntheticCloudDns()
        assertFalse(OwnedDnsSdkBridge(false, sdk).configure(arguments()))
        val bridge = OwnedDnsSdkBridge(true, sdk)
        assertFalse(bridge.configure(arguments() - "secret"))
        assertEquals(emptyList<String>(), bridge.lookup("link.zolmid.com"))
        assertEquals(0, sdk.configured)
        assertEquals(0, sdk.lookups)
        assertFalse(OwnedDnsSdkBridge(true, null).configure(arguments()))
    }
    @Test fun scopeIsExactAndFailureReturnsEmpty() {
        val sdk = SyntheticCloudDns()
        val bridge = OwnedDnsSdkBridge(true, sdk)
        assertTrue(bridge.configure(arguments()))
        assertEquals(sdk.values, bridge.lookup("node.nodes.zolmid.com"))
        assertEquals(emptyList<String>(), bridge.lookup("other.nodes.zolmid.com"))
        assertEquals(emptyList<String>(), bridge.lookup("example.com"))
        assertEquals(1, sdk.lookups)
        sdk.values = listOf("127.0.0.1", "example.com")
        assertEquals(emptyList<String>(), bridge.lookup("link.zolmid.com"))
        sdk.failed = true
        assertEquals(emptyList<String>(), bridge.lookup("link.zolmid.com"))
        bridge.disable()
        assertEquals(emptyList<String>(), bridge.lookup("link.zolmid.com"))
        assertTrue(bridge.configure(arguments()))
        assertEquals(2, sdk.configured)
    }
    @Test fun disablingDoesNotWaitForVendorAndFencesLateAnswer() {
        val sdk = SyntheticCloudDns()
        val bridge = OwnedDnsSdkBridge(true, sdk)
        assertTrue(bridge.configure(arguments()))
        val entered = java.util.concurrent.CountDownLatch(1)
        val release = java.util.concurrent.CountDownLatch(1)
        val answer = java.util.concurrent.atomic.AtomicReference<List<String>>()
        sdk.onLookup = { entered.countDown(); release.await(2, java.util.concurrent.TimeUnit.SECONDS) }
        val worker = Thread { answer.set(bridge.lookup("link.zolmid.com")) }
        worker.start()
        assertTrue(entered.await(2, java.util.concurrent.TimeUnit.SECONDS))
        bridge.disable()
        release.countDown()
        worker.join(2_000)
        assertEquals(emptyList<String>(), answer.get())
    }
    @Test fun rejectsWildcardAndInvalidLiteralsWithoutDns() {
        val sdk = SyntheticCloudDns()
        assertFalse(OwnedDnsSdkBridge(true, sdk).configure(arguments() + ("hosts" to listOf("*.nodes.zolmid.com"))))
        for (value in listOf("localhost", "1.2", "0.0.0.0", "::1", "fe80::1%en0", "ff02::1")) {
            assertFalse(value, OwnedDnsSdkBridge.validAddress(value))
        }
        assertEquals(0, sdk.configured)
    }
}
