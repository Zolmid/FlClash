package com.zolmid.zolnit.renewal

import org.json.JSONObject

internal interface BundleSecurePreferences {
    suspend fun read(key: String): String?
    suspend fun write(key: String, value: String)
    suspend fun delete(key: String)
}

internal class ClientBundleEpochStore(private val preferences: BundleSecurePreferences) : BundleEpochStore {
    override suspend fun current(): BundleSession? {
        val json = preferences.read(MAIN)?.let(::JSONObject) ?: return null
        return BundleSession(json.getLong("epoch"), json.getLong("ownerId"),
            json.getString("accountId"), json.getLong("accountGeneration"), json.getBoolean("active"))
    }

    override suspend fun configure(accountId: String, authorization: String, accountGeneration: Long): BundleSession {
        val epoch = Math.addExact(current()?.epoch ?: 0L, 1L)
        val session = BundleSession(epoch, epoch, accountId, accountGeneration, true)
        preferences.write(authKey(epoch), authorization)
        preferences.write(MAIN, encode(session))
        return session
    }

    override suspend fun invalidate(epoch: Long): Boolean {
        val current = current() ?: return true
        if (current.epoch != epoch) return false
        current.active = false
        preferences.write(MAIN, encode(current))
        return true
    }

    override suspend fun authorization(epoch: Long): String? {
        val current = current() ?: return null
        if (!current.active || current.epoch != epoch) return null
        return preferences.read(authKey(epoch))
    }

    override suspend fun deleteAuthorization(epoch: Long) {
        preferences.delete(authKey(epoch))
    }

    private fun encode(session: BundleSession): String = JSONObject().put("epoch", session.epoch)
        .put("ownerId", session.ownerId).put("accountId", session.accountId)
        .put("accountGeneration", session.accountGeneration).put("active", session.active).toString()

    companion object {
        private const val MAIN = "zolnit.bundle.renewal.main.v1"
        private fun authKey(epoch: Long) = "zolnit.bundle.renewal.authorization.v1.$epoch"
    }
}
