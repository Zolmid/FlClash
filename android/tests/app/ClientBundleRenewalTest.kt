package com.zolmid.zolnit.renewal

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

private class MemoryEpochStore(private val events: MutableList<String>) : BundleEpochStore {
    var session: BundleSession? = null
    val auth = mutableMapOf<Long, String>()
    override suspend fun current() = session
    override suspend fun configure(accountId: String, authorization: String, accountGeneration: Long): BundleSession {
        val epoch = (session?.epoch ?: 0) + 1
        return BundleSession(epoch, epoch, accountId, accountGeneration, true).also {
            session = it
            auth[epoch] = authorization
        }
    }
    override suspend fun invalidate(epoch: Long): Boolean {
        events += "invalidate:$epoch"
        if (session?.epoch != epoch) return false
        session!!.active = false
        return true
    }
    override suspend fun authorization(epoch: Long) = auth[epoch]
    override suspend fun deleteAuthorization(epoch: Long) { events += "delete:$epoch"; auth.remove(epoch) }
}

private class FixtureTransport(private val events: MutableList<String>) : BundleTransport {
    val responses = Channel<BundleHttpResponse>(Channel.UNLIMITED)
    var requests = 0
    var ignoreCancellation = false
    var failNext = false
    override suspend fun get(authorization: String, coreVersion: String): BundleHttpResponse {
        assertEquals("Bearer fixture", authorization)
        assertEquals("fixture-core-v1", coreVersion)
        requests++
        if (failNext) { failNext = false; error("fixture_network_failure") }
        return if (ignoreCancellation) withContext(NonCancellable) { responses.receive() } else responses.receive()
    }
    override fun cancel() { if (events.lastOrNull() != "cancel") events += "cancel" }
}

private class FixtureRpc(private val events: MutableList<String>) : BundleRpc {
    var claims = 0
    var ownerAvailable = true
    var failClaim = false
    var claimAck: CompletableDeferred<Unit>? = null
    var failInstall = false
    var configurationGeneration = 1L
    var activeSerial = 0L
    var installs = 0
    var failEnd = false
    var installAck: CompletableDeferred<Unit>? = null
    var endAck: CompletableDeferred<Unit>? = null
    val generations = mutableListOf<Long>()
    val bodies = mutableListOf<String>()
    val sequences = mutableListOf<Long>()
    val installOwners = mutableListOf<Long>()
    override suspend fun call(method: String, arguments: JSONObject?): Any? {
        assertFalse(arguments?.toString()?.contains("Bearer") ?: false)
        return when (method) {
            "getCoreVersion" -> "fixture-core-v1"
            "getClientBundleOwner" -> if (ownerAvailable) JSONObject().put("instanceId", "instance")
                .put("accountId", "account").put("accountGeneration", 1)
                .put("configurationGeneration", configurationGeneration).put("ownerSerial", activeSerial) else null
            "beginClientBundleOwner" -> {
                check(!failClaim) { "fixture_claim_failure" }
                claims++
                activeSerial = claims.toLong()
                claimAck?.await()
                generations += arguments!!.getLong("generation")
                JSONObject(arguments.toString()).put("serial", claims).also { it.remove("configurationGeneration") }
            }
            "installClientBundle" -> {
                installs++
                bodies += arguments!!.getString("body")
                sequences += arguments.getLong("sequence")
                installOwners += arguments.getJSONObject("owner").getLong("serial")
                installAck?.await()
                check(!failInstall) { "fixture_install_failure" }
                configurationGeneration++
                true
            }
            "endClientBundleOwner" -> {
                events += "end"
                endAck?.await()
                check(!failEnd) { "fixture_end_failure" }
                activeSerial = 0L
                events += "ack"
                true
            }
            else -> error("unexpected_rpc")
        }
    }
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ClientBundleRenewalTest {
    private class Fixture(private val scope: TestScope) {
        val events = mutableListOf<String>()
        val store = MemoryEpochStore(events)
        val rpc = FixtureRpc(events)
        val http = FixtureTransport(events)
        val owner = ClientBundleRenewal(scope.backgroundScope, store, rpc, http,
            { action -> events += "main"; action() },
            { 1_000_000 + scope.testScheduler.currentTime }, { scope.testScheduler.currentTime })
        suspend fun start() {
            owner.configure("account", "Bearer fixture", 1)
            owner.start()
            events.clear()
        }
        suspend fun response(status: Int = 200, ttl: Long = 300, body: String? = null, retry: Long = 60_000) {
            val issued = (1_000_000 + scope.testScheduler.currentTime) / 1_000
            http.responses.send(BundleHttpResponse(status, body ?: """{"data":{"issued_at":$issued,"expires_at":${issued + ttl}}}""", retry))
        }
    }

    @Test fun renewsAt60SecondsWithSameGuardAndIncreasingSequence() = runTest {
        val f = Fixture(this)
        f.response()
        f.start()
        runCurrent()
        assertEquals(1, f.rpc.installs)
        assertEquals("installed", f.owner.status()["state"])
        assertEquals(true, f.owner.status()["ready"])
        assertEquals(true, f.owner.status()["installed"])
        assertTrue(f.rpc.bodies.single().contains("expires_at"))
        advanceTimeBy(59_999)
        runCurrent()
        assertEquals(1, f.http.requests)
        advanceTimeBy(1)
        f.response()
        runCurrent()
        assertEquals(2, f.http.requests)
        assertEquals(2, f.rpc.installs)
        assertEquals(1, f.rpc.claims)
        assertEquals(listOf(1L, 2L), f.rpc.sequences)
        assertEquals(listOf(1L, 1L), f.rpc.installOwners)
        assertEquals(1_360_000L, f.owner.status()["deadline"])
        assertFalse(f.events.contains("end"))
        f.owner.stop()
    }

    @Test fun shortenedTTLRequestsAgainAtHalfRemainingAndReplacesExpiryOnSuccess() = runTest {
        val f = Fixture(this)
        f.response(ttl = 20)
        f.start()
        runCurrent()
        advanceTimeBy(9_999)
        runCurrent()
        assertEquals(1, f.http.requests)
        advanceTimeBy(1)
        f.response(ttl = 20)
        runCurrent()
        assertEquals(2, f.http.requests)
        assertEquals(2, f.rpc.installs)
        assertEquals(1, f.rpc.claims)
        assertEquals(1_030_000L, f.owner.status()["deadline"])
        advanceTimeBy(10_000)
        runCurrent()
        assertEquals(true, f.owner.status()["installed"])
        assertFalse(f.events.contains("end"))
        f.owner.stop()
    }

    @Test fun rejectsTTLAbove300AndDoesNotInstall() = runTest {
        val f = Fixture(this)
        f.response(ttl = 301)
        f.start()
        runCurrent()
        assertEquals(0, f.rpc.installs)
        assertEquals("retrying", f.owner.status()["state"])
        assertTrue(f.store.session!!.active)
        f.owner.stop()
    }

    @Test fun logoutInvalidatesOnMainThenCancelsDrainsAndDeletes() = runTest {
        val f = Fixture(this)
        f.response()
        f.start()
        runCurrent()
        f.rpc.endAck = CompletableDeferred()
        val logout = launch { f.owner.logout(1) }
        runCurrent()
        assertFalse(f.store.session!!.active)
        assertTrue(f.store.auth.containsKey(1))
        assertEquals(listOf("main", "invalidate:1", "cancel", "end"), f.events)
        f.rpc.endAck!!.complete(Unit)
        logout.join()
        assertEquals(listOf("main", "invalidate:1", "cancel", "end", "ack", "delete:1"), f.events)
        assertFalse(f.store.auth.containsKey(1))
    }

    @Test fun failedDrainRetainsOldAuthorizationAndCanBeRetried() = runTest {
        val f = Fixture(this)
        f.start()
        runCurrent()
        f.rpc.failEnd = true
        assertTrue(runCatching { f.owner.logout(1) }.isFailure)
        assertTrue(f.store.auth.containsKey(1))
        assertFalse(f.store.session!!.active)
        f.rpc.failEnd = false
        assertTrue(f.owner.logout(1))
        assertFalse(f.store.auth.containsKey(1))
    }

    @Test fun lateOldResponseAndLogoutCannotOverwriteNewSession() = runTest {
        val f = Fixture(this)
        f.http.ignoreCancellation = true
        f.start()
        runCurrent()
        f.owner.logout(1)
        f.owner.configure("account", "Bearer fixture", 1)
        runCurrent()
        f.response(status = 401)
        runCurrent()
        assertEquals(2L, f.store.session!!.epoch)
        assertTrue(f.store.session!!.active)
        assertTrue(f.owner.logout(1))
        assertTrue(f.store.auth.containsKey(2))
        assertEquals(0, f.rpc.installs)
        f.response(status = 403, body = "edge blocked")
        runCurrent()
        f.owner.stop()
    }

    @Test fun any401LogsOutEvenWithoutStructuredBody() = runTest {
        val f = Fixture(this)
        f.response(status = 401, body = "edge unauthorized")
        f.start()
        runCurrent()
        assertEquals("logged_out", f.owner.status()["state"])
        assertFalse(f.store.session!!.active)
        assertTrue(f.store.auth.isEmpty())
    }

    @Test fun onlyStructured403RevokesAndKeepsLogin() = runTest {
        for (body in listOf("edge denied", """{"error":{"code":"entitlement_unavailable"}}""")) {
            val f = Fixture(this)
            f.response(status = 403, body = body)
            f.start()
            runCurrent()
            assertTrue(f.store.session!!.active)
            assertTrue(f.store.auth.containsKey(1))
            assertEquals(if (body.startsWith("{")) "entitlement_unavailable" else "retrying", f.owner.status()["state"])
            assertEquals(body.startsWith("{"), f.events.contains("ack"))
            f.owner.stop()
        }
    }

    @Test fun retryAfterAndNetworkFailureKeepEpochAndDoNotInstall() = runTest {
        val f = Fixture(this)
        f.response(status = 429, retry = 180_000)
        f.start()
        runCurrent()
        advanceTimeBy(179_999)
        runCurrent()
        assertEquals(1, f.http.requests)
        advanceTimeBy(1)
        runCurrent()
        assertEquals(2, f.http.requests)
        assertTrue(f.store.session!!.active)
        assertEquals(0, f.rpc.installs)
        f.owner.stop()
    }

    @Test fun networkFailureKeepsLoginAndReusesClaimOnRetry() = runTest {
        val f = Fixture(this)
        f.http.failNext = true
        f.start()
        runCurrent()
        assertEquals("retrying", f.owner.status()["state"])
        assertTrue(f.store.session!!.active)
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(listOf(1L), f.rpc.generations)
        assertFalse(f.events.contains("end"))
        assertEquals(0, f.rpc.installs)
        f.owner.stop()
    }

    @Test fun logoutPersistsInvalidationWhileInstallACKIsStillPending() = runTest {
        val f = Fixture(this)
        f.rpc.installAck = CompletableDeferred()
        f.response()
        f.start()
        runCurrent()
        assertEquals(1, f.rpc.installs)
        val logout = launch { f.owner.logout(1) }
        runCurrent()
        assertFalse(f.store.session!!.active)
        assertTrue(f.store.auth.containsKey(1))
        assertFalse(logout.isCompleted)
        f.rpc.installAck!!.complete(Unit)
        runCurrent()
        logout.join()
        assertFalse(f.store.auth.containsKey(1))
        assertEquals("logged_out", f.owner.status()["state"])
    }

    @Test fun delayedInstallACKCannotExtendBundleTTL() = runTest {
        val f = Fixture(this)
        f.rpc.installAck = CompletableDeferred()
        f.response(ttl = 20)
        f.start()
        runCurrent()
        advanceTimeBy(21_000)
        f.rpc.installAck!!.complete(Unit)
        runCurrent()
        assertEquals("expired", f.owner.status()["state"])
        assertTrue(f.events.contains("ack"))
        assertFalse(f.owner.status()["ready"] as Boolean)
        f.owner.stop()
    }

    @Test fun edge403And429AndNetworkFailurePreserveInstalledLeaseAndDeadline() = runTest {
        for (failure in listOf("edge403", "unknown403", "429", "network")) {
            val f = Fixture(this)
            f.response()
            f.start()
            runCurrent()
            val deadline = f.owner.status()["deadline"]
            when (failure) {
                "edge403" -> f.response(status = 403, body = "edge denied")
                "unknown403" -> f.response(status = 403, body = """{"error":{"code":"edge_blocked"}}""")
                "429" -> f.response(status = 429, retry = 360_000)
                else -> f.http.failNext = true
            }
            advanceTimeBy(60_000)
            runCurrent()
            assertEquals(failure, 2, f.http.requests)
            assertEquals(failure, 1, f.rpc.claims)
            assertEquals(failure, 1, f.rpc.installs)
            assertFalse(failure, f.events.contains("end"))
            assertEquals(failure, deadline, f.owner.status()["deadline"])
            assertEquals(failure, true, f.owner.status()["installed"])
            assertEquals(failure, true, f.owner.status()["ready"])
            assertTrue(failure, f.store.session!!.active)
            f.owner.stop()
        }
    }

    @Test fun retryAfterDoesNotExtendOriginalLeasePastExpiry() = runTest {
        val f = Fixture(this)
        f.response()
        f.start()
        runCurrent()
        f.response(status = 429, retry = 360_000)
        advanceTimeBy(60_000)
        runCurrent()
        advanceTimeBy(240_000)
        runCurrent()
        assertEquals(2, f.http.requests)
        assertEquals("expired", f.owner.status()["state"])
        assertEquals(false, f.owner.status()["installed"])
        assertEquals(0L, f.owner.status()["deadline"])
        assertEquals(1, f.events.count { it == "end" })
        assertTrue(f.store.session!!.active)
        f.owner.stop()
    }

    @Test fun configureReadyRequiresAnAcknowledgedClaimAndDoesNotRequireInstallation() = runTest {
        val f = Fixture(this)
        f.owner.start()
        val result = f.owner.configure("account", "Bearer fixture", 1)
        assertEquals(false, result["ready"])
        assertEquals(true, result["ownsRenewal"])
        assertEquals(false, result["installed"])
        assertEquals(0L, result["deadline"])
        assertEquals(1, f.rpc.claims)
        assertEquals(0, f.rpc.installs)
        runCurrent()
        assertEquals(1, f.rpc.claims)
        assertEquals(1, f.http.requests)
        f.owner.stop()
    }

    @Test fun missingCoreOrFailedClaimReturnsNotReadyAndKeepsRetrying() = runTest {
        for (missingCore in listOf(true, false)) {
            val f = Fixture(this)
            f.rpc.ownerAvailable = !missingCore
            f.rpc.failClaim = !missingCore
            f.owner.start()
            val result = f.owner.configure("account", "Bearer fixture", 1)
            assertEquals(false, result["ready"])
            assertEquals(false, result["installed"])
            runCurrent()
            assertEquals(false, f.owner.status()["ready"])
            assertEquals(0, f.http.requests)
            f.rpc.ownerAvailable = true
            f.rpc.failClaim = false
            advanceTimeBy(60_000)
            runCurrent()
            assertEquals(true, f.owner.status()["ownsRenewal"])
            assertEquals(false, f.owner.status()["ready"])
            assertEquals(1, f.rpc.claims)
            assertEquals(1, f.http.requests)
            f.owner.stop()
        }
    }

    @Test fun readyStaysFalseUntilCoreClaimACKArrives() = runTest {
        val f = Fixture(this)
        f.rpc.claimAck = CompletableDeferred()
        f.owner.start()
        var result: Map<String, Any?>? = null
        val configuring = launch { result = f.owner.configure("account", "Bearer fixture", 1) }
        runCurrent()
        assertNull(result)
        assertEquals(false, f.owner.status()["ready"])
        assertEquals(0, f.http.requests)
        f.rpc.claimAck!!.complete(Unit)
        configuring.join()
        assertEquals(true, result!!["ownsRenewal"])
        assertEquals(false, result!!["ready"])
        assertEquals(false, result!!["installed"])
        f.owner.stop()
    }

    @Test fun failedInstallPreservesLeaseAndSuccessfulShorteningReplacesDeadline() = runTest {
        val f = Fixture(this)
        f.response()
        f.start()
        runCurrent()
        val originalDeadline = f.owner.status()["deadline"]
        f.rpc.failInstall = true
        advanceTimeBy(60_000)
        f.response()
        runCurrent()
        assertEquals(2, f.rpc.installs)
        assertEquals(originalDeadline, f.owner.status()["deadline"])
        assertEquals(true, f.owner.status()["installed"])
        assertFalse(f.events.contains("end"))
        f.rpc.failInstall = false
        advanceTimeBy(60_000)
        f.response(ttl = 100)
        runCurrent()
        assertEquals(1, f.rpc.claims)
        assertEquals(listOf(1L, 2L, 3L), f.rpc.sequences)
        assertEquals(listOf(1L, 1L, 1L), f.rpc.installOwners)
        assertEquals(1_220_000L, f.owner.status()["deadline"])
        assertFalse(f.events.contains("end"))
        f.owner.stop()
    }

    @Test fun refreshIntervalUsesRemainingTTLAfterInstallACK() = runTest {
        val f = Fixture(this)
        f.rpc.installAck = CompletableDeferred()
        f.response(ttl = 20)
        f.start()
        runCurrent()
        advanceTimeBy(10_000)
        f.rpc.installAck!!.complete(Unit)
        runCurrent()
        advanceTimeBy(4_999)
        runCurrent()
        assertEquals(1, f.http.requests)
        advanceTimeBy(1)
        runCurrent()
        assertEquals(2, f.http.requests)
        assertEquals(1, f.rpc.claims)
        assertFalse(f.events.contains("end"))
        f.owner.stop()
    }

    @Test fun configurationHandoffDrainsOldOwnerAndClaimsNewGeneration() = runTest {
        val f = Fixture(this)
        f.response()
        f.start()
        runCurrent()
        f.rpc.configurationGeneration++
        f.rpc.activeSerial = 0L
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(2, f.rpc.claims)
        assertEquals(listOf(1L, 2L), f.rpc.generations)
        assertEquals(1, f.events.count { it == "end" })
        assertEquals(false, f.owner.status()["installed"])
        assertEquals(true, f.owner.status()["ownsRenewal"])
        assertEquals(false, f.owner.status()["ready"])
        f.owner.stop()
    }

    @Test fun expiryDuringRequestDiscardsOldCallbackAndContinuesRetrying() = runTest {
        val f = Fixture(this)
        f.response(ttl = 20)
        f.start()
        runCurrent()
        advanceTimeBy(20_000)
        runCurrent()
        assertEquals(2, f.http.requests)
        assertEquals("expired", f.owner.status()["state"])
        f.response()
        runCurrent()
        assertEquals(1, f.rpc.installs)
        advanceTimeBy(60_000)
        runCurrent()
        assertEquals(3, f.http.requests)
        assertEquals(2, f.rpc.claims)
        f.owner.stop()
    }

    @Test fun explicitStopCancelsAndDrainsWithoutLoggingOut() = runTest {
        val f = Fixture(this)
        f.start()
        runCurrent()
        f.owner.stop()
        assertTrue(f.store.session!!.active)
        assertTrue(f.store.auth.containsKey(1))
        assertEquals("stopped", f.owner.status()["state"])
        advanceTimeBy(600_000)
        runCurrent()
        assertEquals(1, f.http.requests)
        f.owner.start()
        runCurrent()
        assertEquals(2, f.http.requests)
        f.owner.stop()
    }
}
