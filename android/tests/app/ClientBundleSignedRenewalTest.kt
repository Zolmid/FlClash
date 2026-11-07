package com.zolmid.zolnit.renewal

import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

private const val INSTALLATION = "aW5zdGFsbGF0aW9uLXNlY3JldC1maXh0dXJlLTMyYnk"
private val DEVICE = SignedDevice("0123456789abcdef0123456789abcdef", INSTALLATION)

private class SignedEpochStore : BundleEpochStore {
    var session: BundleSession? = null
    val devices = mutableMapOf<Long, SignedDevice>()
    var invalidations = 0
    override suspend fun current() = session
    override suspend fun configure(accountId: String, authorization: String, accountGeneration: Long,
        device: SignedDevice?): BundleSession {
        val epoch = (session?.epoch ?: 0) + 1
        device?.let { devices[epoch] = it }
        return BundleSession(epoch, epoch, accountId, accountGeneration, true).also { session = it }
    }
    override suspend fun device(epoch: Long) = devices[epoch]
    override suspend fun invalidate(epoch: Long): Boolean { invalidations++; session!!.active = false; return true }
    override suspend fun authorization(epoch: Long) = "Bearer fixture"
    override suspend fun deleteAuthorization(epoch: Long) { devices.remove(epoch) }
}

private class SignedTransport : BundleTransport {
    val requests = mutableListOf<String>()
    var next: (Boolean) -> BundleHttpResponse = { error("offline") }
    override suspend fun get(authorization: String, coreVersion: String) = error("legacy endpoint used in signed mode")
    override suspend fun signed(authorization: String, coreVersion: String, device: SignedDevice, state: Boolean): BundleHttpResponse {
        assertSame(DEVICE.deviceId, device.deviceId)
        requests += if (state) "state" else "bundle"
        return next(state)
    }
    override fun cancel() {}
}

/** Stands in for the Core's signed store and owner methods. */
private class SignedCore(private val wall: () -> Long) : BundleRpc {
    var packageInstalled = false
    var applied = mutableListOf<String>()
    var applyResult: JSONObject = JSONObject().put("installed", true)
    var installs = 0
    var ends = 0
    var refusal: String? = null
    var ownerSerial = 0
    override suspend fun call(method: String, arguments: JSONObject?): Any? {
        assertFalse("installation secret crossed the Core boundary",
            arguments?.toString()?.contains(INSTALLATION) ?: false)
        return when (method) {
            "getCoreVersion" -> "fixture-core-v1"
            "getClientBundleOwner" -> JSONObject().put("instanceId", "instance").put("accountId", "account")
                .put("accountGeneration", 1).put("configurationGeneration", 1).put("ownerSerial", ownerSerial)
            "beginClientBundleOwner" -> JSONObject(arguments.toString()).put("serial", ++ownerSerial)
                .also { it.remove("configurationGeneration") }
            "applySignedSubscription" -> {
                applied += JSONObject(arguments!!.getString("envelope")).getString("kind")
                applyResult.also { packageInstalled = it.optBoolean("installed") }
            }
            "installSignedClientBundle" -> {
                installs++
                val code = refusal ?: if (packageInstalled) null else "signed_subscription_required"
                if (code != null) JSONObject().put("installed", false).put("code", code)
                else JSONObject().put("installed", true).put("bundleId", "lease-$installs")
                    .put("expiresAt", wall() + 300_000)
            }
            "endClientBundleOwner" -> { ends++; ownerSerial = 0; true }
            else -> error("unexpected_rpc:$method")
        }
    }
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ClientBundleSignedRenewalTest {
    private class Fixture(scope: TestScope) {
        val store = SignedEpochStore()
        val http = SignedTransport()
        val core = SignedCore { 1_000_000 + scope.testScheduler.currentTime }
        val owner = ClientBundleRenewal(scope.backgroundScope, store, core, http, { it() },
            { 1_000_000 + scope.testScheduler.currentTime }, { scope.testScheduler.currentTime })
        suspend fun start() {
            owner.configure("account", "Bearer fixture", 1, DEVICE)
            owner.start()
        }
    }

    private fun envelope(kind: String) =
        BundleHttpResponse(200, JSONObject().put("data", JSONObject().put("kind", kind)).toString())

    @Test fun retainedPackageRenewsOfflineFromTheCore() = runTest {
        val f = Fixture(this)
        f.core.packageInstalled = true
        f.start()
        runCurrent()
        assertEquals(listOf("bundle"), f.http.requests)
        assertEquals("installed", f.owner.status()["state"])
        assertEquals(1, f.core.installs)
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(2, f.core.installs)
        assertEquals(0, f.store.invalidations)
    }

    @Test fun downloadsOnceThenRenewsLocallyAndChecksSignedState() = runTest {
        val f = Fixture(this)
        f.http.next = { state -> envelope(if (state) "state" else "bundle") }
        f.start()
        runCurrent()
        assertEquals(listOf("bundle"), f.http.requests)
        assertEquals(listOf("bundle"), f.core.applied)
        assertEquals("installed", f.owner.status()["state"])
        repeat(4) {
            advanceTimeBy(60_000)
            runCurrent()
        }
        assertEquals("lease renewal must not download", listOf("bundle"), f.http.requests)
        assertEquals(5, f.core.installs)
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(listOf("bundle", "state"), f.http.requests)
        f.core.applyResult = JSONObject().put("installed", true).put("needsRefresh", true)
        repeat(5) {
            advanceTimeBy(60_000)
            runCurrent()
        }
        advanceTimeBy(1_000)
        runCurrent()
        assertEquals(listOf("bundle", "state", "state", "bundle"), f.http.requests)
    }

    @Test fun unsignedFailuresKeepTheSignedPackage() = runTest {
        val f = Fixture(this)
        f.http.next = { envelope("bundle") }
        f.start()
        runCurrent()
        f.http.next = { BundleHttpResponse(401, """{"error":{"code":"unauthenticated"}}""") }
        advanceTimeBy(300_000)
        runCurrent()
        assertEquals("installed", f.owner.status()["state"])
        assertEquals(0, f.store.invalidations)
        assertEquals(0, f.core.ends)
        f.http.next = { BundleHttpResponse(200, "not json") }
        advanceTimeBy(300_000)
        runCurrent()
        assertEquals("installed", f.owner.status()["state"])
    }

    @Test fun signedRevocationDrainsAndStopsInstalling() = runTest {
        val f = Fixture(this)
        f.http.next = { envelope("bundle") }
        f.start()
        runCurrent()
        f.core.applyResult = JSONObject().put("installed", false).put("revoked", true)
        f.http.next = { envelope("revoked") }
        advanceTimeBy(300_000)
        runCurrent()
        assertEquals("entitlement_unavailable", f.owner.status()["state"])
        assertEquals(1, f.core.ends)
        val installs = f.core.installs
        f.core.refusal = "subscription_tombstone"
        advanceTimeBy(600_000)
        runCurrent()
        assertEquals("revoked package was reinstalled", installs, f.core.installs)
        assertNotEquals("installed", f.owner.status()["state"])
    }

    @Test fun installationSecretIsRedacted() {
        assertFalse(DEVICE.toString().contains(INSTALLATION))
    }
}
