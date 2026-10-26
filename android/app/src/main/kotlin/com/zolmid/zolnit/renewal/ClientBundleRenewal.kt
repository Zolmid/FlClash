package com.zolmid.zolnit.renewal

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal class BundleSession(
    val epoch: Long,
    val ownerId: Long,
    val accountId: String,
    val accountGeneration: Long,
    var active: Boolean,
)

internal interface BundleEpochStore {
    suspend fun current(): BundleSession?
    suspend fun configure(accountId: String, authorization: String, accountGeneration: Long): BundleSession
    suspend fun invalidate(epoch: Long): Boolean
    suspend fun authorization(epoch: Long): String?
    suspend fun deleteAuthorization(epoch: Long)
}

internal fun interface BundleRpc {
    suspend fun call(method: String, arguments: JSONObject?): Any?
}

internal class BundleHttpResponse(val status: Int, val body: String, val retryAfterMillis: Long = 60_000)

internal interface BundleTransport {
    suspend fun get(authorization: String, coreVersion: String): BundleHttpResponse
    fun cancel()
}

internal class ClientBundleRenewal(
    private val scope: CoroutineScope,
    private val store: BundleEpochStore,
    private val rpc: BundleRpc,
    private val transport: BundleTransport,
    private val mainBarrier: suspend (suspend () -> Unit) -> Unit,
    private val wallMillis: () -> Long = System::currentTimeMillis,
    private val monotonicMillis: () -> Long = { System.nanoTime() / 1_000_000 },
) {
    private val lock = Mutex()
    private val commands = Mutex()
    private var running = false
    @Volatile private var job: Job? = null
    private var expiryJob: Job? = null
    private var guard: JSONObject? = null
    private var ownerBinding: JSONObject? = null
    private var generation = 0L
    private var sequence = 0L
    private var deadline = 0L
    private var deadlineWallMillis = 0L
    private var establishedEpoch: Long? = null
    private var installedBundleId: String? = null
    @Volatile private var snapshot: Map<String, Any?> = mapOf("ready" to false, "installed" to false, "deadline" to 0L, "state" to "stopped")

    fun status(): Map<String, Any?> = snapshot

    suspend fun authoritativeStatus(): Map<String, Any?> = lock.withLock {
        val owner = guard
        val current = runCatching { rpc.call("getRoutingLease", null) as? JSONObject }.getOrNull()
        val installed = owner != null && current != null && deadline > monotonicMillis() &&
            installedBundleId != null && current.optString("bundleId") == installedBundleId &&
            current.optString("instanceId") == owner.optString("instanceId") &&
            current.optString("accountId") == owner.optString("accountId") &&
            current.optLong("accountGeneration") == owner.optLong("accountGeneration") &&
            current.optLong("expiresAt") == deadlineWallMillis
        snapshot = snapshot + mapOf("ready" to installed, "installed" to installed)
        snapshot
    }

    suspend fun configure(accountId: String, authorization: String, accountGeneration: Long): Map<String, Any?> =
        withContext(NonCancellable) {
            require(accountId.isNotBlank() && accountId.length <= 256)
            require(accountGeneration > 0)
            require(authorization.startsWith("Bearer ") && authorization.length in 8..16_384 &&
                authorization.none { it == '\r' || it == '\n' })
            commands.withLock {
                val old = store.current()
                if (old != null) {
                    mainBarrier { check(store.invalidate(old.epoch)) }
                    job?.cancel()
                    transport.cancel()
                }
                lock.withLock {
                    cancelWork()
                    drain(invalidatingSession = old != null)
                    if (old != null) store.deleteAuthorization(old.epoch)
                    val session = store.configure(accountId, authorization, accountGeneration)
                    establishedEpoch = null
                    publish(session, "configured")
                    if (running) {
                        try {
                            claim(session)
                        } catch (_: Exception) {
                            publish(session, "retrying")
                        }
                        launchLoop(session)
                    }
                    snapshot
                }
            }
        }

    suspend fun logout(epoch: Long): Boolean = withContext(NonCancellable) {
        commands.withLock {
            val current = store.current()
            if (current == null || current.epoch != epoch) return@withLock true
            mainBarrier { check(store.invalidate(epoch)) }
            publish(current, "revoking")
            job?.cancel()
            transport.cancel()
            lock.withLock {
                cancelWork()
                drain(invalidatingSession = true)
                store.deleteAuthorization(epoch)
                publish(current, "logged_out")
                true
            }
        }
    }

    suspend fun start() = lock.withLock {
        running = true
        val session = try { store.current() } catch (_: Exception) {
            snapshot = mapOf("ready" to false, "installed" to false, "deadline" to 0L, "state" to "secure_store_unavailable")
            null
        }
        if (session?.active == true && job?.isActive != true) launchLoop(session)
    }

    suspend fun stop() = withContext(NonCancellable) {
        lock.withLock {
            running = false
            establishedEpoch = null
            cancelWork()
            drain()
            snapshot = mapOf("ready" to false, "installed" to false, "deadline" to 0L, "state" to "stopped")
        }
    }

    private fun cancelWork() {
        job?.cancel()
        job = null
        transport.cancel()
        expiryJob?.cancel()
        expiryJob = null
    }

    private suspend fun drain(invalidatingSession: Boolean = false) {
        val owner = guard ?: return
        ownerBinding = null
        check(rpc.call("endClientBundleOwner", JSONObject().put("owner", owner)
            .put("invalidateSession", invalidatingSession)) == true)
        guard = null
        installedBundleId = null
        deadline = 0
        deadlineWallMillis = 0
    }

    private fun launchLoop(session: BundleSession) {
        job = scope.launch {
            while (true) {
                val wait = try {
                    attempt(session)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    lock.withLock { if (isCurrent(session)) publish(session, "retrying") }
                    60_000L
                }
                if (wait == null) break
                delay(wait)
            }
        }
    }

    private suspend fun isCurrent(session: BundleSession): Boolean {
        val current = store.current()
        return running && current?.active == true && current.epoch == session.epoch
    }

    private suspend fun claim(session: BundleSession): JSONObject? {
        val base = rpc.call("getClientBundleOwner", null) as? JSONObject
        if (base == null || base.optString("accountId") != session.accountId ||
            base.optLong("accountGeneration") != session.accountGeneration) {
            drain()
            publish(session, "owner_unavailable")
            return null
        }
        check(base.getString("instanceId").isNotBlank())
        check(base.getLong("configurationGeneration") >= 0)
        val binding = ownerBinding
        if (guard != null && binding != null &&
            listOf("instanceId", "accountId").all { base.getString(it) == binding.getString(it) } &&
            base.getLong("accountGeneration") == binding.getLong("accountGeneration") &&
            base.optLong("ownerSerial") == guard?.optLong("serial")) return guard
        drain()
        generation = Math.addExact(generation, 1)
        val args = JSONObject(base.toString()).put("sessionEpoch", session.epoch)
            .put("ownerId", session.ownerId).put("generation", generation)
        val claimed = rpc.call("beginClientBundleOwner", args) as? JSONObject
            ?: error("owner_claim_failed")
        check(listOf("instanceId", "accountId").all { claimed.getString(it) == args.getString(it) } &&
            listOf("accountGeneration", "sessionEpoch", "ownerId", "generation").all {
                claimed.getLong(it) == args.getLong(it)
            } && claimed.getLong("serial") > 0)
        guard = claimed
        establishedEpoch = session.epoch
        ownerBinding = JSONObject(base.toString())
        publish(session, "claimed")
        return claimed
    }

    private suspend fun attempt(session: BundleSession): Long? {
        var authorization: String? = null
        var version: String? = null
        val owner = lock.withLock {
            if (!isCurrent(session)) return null
            // Keep a claim visible until its ACK, even if stop cancels this attempt.
            withContext(NonCancellable) {
                val claimed = claim(session) ?: return@withContext null
                authorization = store.authorization(session.epoch) ?: error("missing_authorization")
                version = (rpc.call("getCoreVersion", null) as? String)?.takeIf {
                    it.isNotBlank() && it.length <= 128 && it.none { c -> c.isISOControl() }
                } ?: error("missing_core_version")
                publish(session, "requesting")
                claimed
            }
        } ?: return 60_000
        val response = transport.get(checkNotNull(authorization), checkNotNull(version))
        return lock.withLock {
            if (!isCurrent(session)) return@withLock null
            if (guard !== owner) return@withLock 60_000L
            withContext(NonCancellable) {
                when (response.status) {
                    200 -> {
                        val data = JSONObject(response.body).getJSONObject("data")
                        val issued = data.getLong("issued_at")
                        val expires = data.getLong("expires_at")
                        val now = wallMillis() / 1_000
                        require(issued <= now && issued >= now - 300 && expires > now &&
                            expires > issued && expires - issued <= 300)
                        val remaining = expires * 1_000 - wallMillis()
                        require(remaining > 0)
                        val expiresAt = monotonicMillis() + remaining
                        sequence = Math.addExact(sequence, 1)
                        check(rpc.call("installClientBundle", JSONObject().put("owner", owner)
                            .put("sequence", sequence).put("body", response.body)) == true)
                        if (!isCurrent(session)) {
                            drain()
                            return@withContext null
                        }
                        deadline = expiresAt
                        deadlineWallMillis = expires * 1_000
                        installedBundleId = data.optString("bundle_id").takeIf { it.isNotBlank() }
                        if (deadline <= monotonicMillis()) {
                            drain()
                            publish(session, "expired")
                            return@withContext 60_000L
                        }
                        scheduleExpiry(session, owner, deadline)
                        publish(session, "installed")
                        minOf(60_000, maxOf(1_000, (deadline - monotonicMillis()) / 2))
                    }
                    401 -> {
                        mainBarrier { check(store.invalidate(session.epoch)) }
                        transport.cancel()
                        drain(invalidatingSession = true)
                        store.deleteAuthorization(session.epoch)
                        publish(session, "logged_out")
                        null
                    }
                    403 -> {
                        if (entitlementUnavailable(response.body)) {
                            drain()
                            publish(session, "entitlement_unavailable")
                        } else publish(session, "retrying")
                        60_000L
                    }
                    429 -> { publish(session, "rate_limited"); maxOf(60_000, response.retryAfterMillis) }
                    else -> { publish(session, "retrying"); 60_000L }
                }
            }
        }
    }

    private fun scheduleExpiry(session: BundleSession, owner: JSONObject, expires: Long) {
        expiryJob?.cancel()
        expiryJob = scope.launch {
            delay(maxOf(0, expires - monotonicMillis()))
            lock.withLock {
                if (guard === owner) withContext(NonCancellable) {
                    try {
                        drain()
                        publish(session, "expired")
                    } catch (_: Exception) {
                        publish(session, "drain_failed")
                    }
                }
            }
        }
    }

    private fun publish(session: BundleSession, state: String) {
        val owns = running && establishedEpoch == session.epoch &&
            state != "revoking" && state != "logged_out"
        val installed = owns && guard != null && deadline > monotonicMillis()
        snapshot = mapOf("sessionEpoch" to session.epoch, "ownerId" to session.ownerId,
            "ownsRenewal" to owns, "ready" to installed, "installed" to installed,
            "expiresAt" to deadlineWallMillis, "deadline" to deadlineWallMillis, "state" to state)
    }

    companion object {
        fun entitlementUnavailable(body: String): Boolean = runCatching {
            JSONObject(body).getJSONObject("error").getString("code") == "entitlement_unavailable"
        }.getOrDefault(false)
    }
}
