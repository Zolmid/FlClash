package com.zolmid.zolnit.renewal

import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

private class EncryptedPreferencesFixture : BundleSecurePreferences {
    val values = mutableMapOf("zolnit.session.authorization.v1" to "Bearer fixture")
    val writes = mutableListOf<String>()
    var failWrites = false
    override suspend fun read(key: String) = values[key]
    override suspend fun write(key: String, value: String) {
        check(!failWrites) { "fixture_disk_failure" }
        writes += key
        values[key] = value
    }
    override suspend fun delete(key: String) { values.remove(key) }
}

class ClientBundleEpochStoreTest {
    @Test fun persistsEpochAuthorizationWithoutOverwritingSharedVault() = runTest {
        val preferences = EncryptedPreferencesFixture()
        val store = ClientBundleEpochStore(preferences)
        assertNull(store.current())
        val session = store.configure("account", "Bearer epoch-fixture", 1)
        assertEquals("Bearer fixture", preferences.values["zolnit.session.authorization.v1"])
        assertEquals(1L, session.epoch)
        assertEquals(listOf("zolnit.bundle.renewal.authorization.v1.1", "zolnit.bundle.renewal.main.v1"), preferences.writes)
        val restored = ClientBundleEpochStore(preferences)
        assertEquals(1L, restored.current()!!.epoch)
        assertEquals("Bearer epoch-fixture", restored.authorization(1))
        restored.invalidate(1)
        assertNull(ClientBundleEpochStore(preferences).authorization(1))
    }

    @Test fun deletingOldEpochCannotEraseNewOrSharedAuthorization() = runTest {
        val preferences = EncryptedPreferencesFixture()
        val store = ClientBundleEpochStore(preferences)
        store.configure("account", "Bearer fixture", 1)
        store.invalidate(1)
        val newSession = store.configure("account", "Bearer fixture", 2)
        store.deleteAuthorization(1)
        assertFalse(store.invalidate(1))
        assertEquals(2L, newSession.epoch)
        assertEquals("Bearer fixture", store.authorization(2))
        assertEquals("Bearer fixture", preferences.values["zolnit.session.authorization.v1"])
    }

    @Test fun diskFailureCannotReportSuccessfulBarrier() = runTest {
        val preferences = EncryptedPreferencesFixture()
        val store = ClientBundleEpochStore(preferences)
        store.configure("account", "Bearer fixture", 1)
        preferences.failWrites = true
        assertTrue(runCatching { store.invalidate(1) }.isFailure)
        assertTrue(store.current()!!.active)
        assertEquals("Bearer fixture", store.authorization(1))
    }
}
