package com.zolmid.zolnit.renewal

import android.content.Context
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

internal class FlutterBundleSecurePreferences(context: Context) : BundleSecurePreferences {
    private val context = context.applicationContext
    private val storage = FlutterSecureStorage(this.context)
    private var initialized = false
    private val lock = Mutex()

    private suspend fun initialize() {
        if (initialized) return
        val config = FlutterSecureStorageConfig(mapOf<String, Any>(
            "migrateOnAlgorithmChange" to false, "migrateWithBackup" to false, "resetOnError" to false,
        ))
        check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).all.keys.any {
            it.startsWith(config.sharedPreferencesKeyPrefix + "_zolnit.")
        }) { "existing_vault_required" }
        await<Void> { callback -> storage.initialize(config, callback) }
        initialized = true
    }

    override suspend fun read(key: String): String? = withContext(Dispatchers.IO) {
        lock.withLock {
            if (!context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).all.keys.any {
                it.endsWith("_zolnit.session.authorization.v1") || it.endsWith("_zolnit.bundle.renewal.main.v1")
            }) return@withLock null
            initialize()
            await<String> { storage.read(storage.addPrefixToKey(key), it) }
        }
    }

    override suspend fun write(key: String, value: String) = withContext(Dispatchers.IO) {
        lock.withLock {
            initialize()
            val prefixed = storage.addPrefixToKey(key)
            await<Void> { storage.write(prefixed, value, it) }
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val ciphertext = checkNotNull(preferences.getString(prefixed, null))
            // The plugin uses apply(); commit the already encrypted value before crossing the barrier.
            check(preferences.edit().putString(prefixed, ciphertext).commit()) { "epoch_persistence_failed" }
        }
    }

    override suspend fun delete(key: String) = withContext(Dispatchers.IO) {
        lock.withLock {
            initialize()
            val prefixed = storage.addPrefixToKey(key)
            storage.delete(prefixed)
            check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().remove(prefixed).commit())
        }
    }

    private suspend fun <T> await(operation: (SecurePreferencesCallback<T>) -> Unit): T? =
        suspendCancellableCoroutine { continuation ->
            operation(object : SecurePreferencesCallback<T> {
                override fun onSuccess(result: T?) { if (continuation.isActive) continuation.resume(result) }
                override fun onError(e: Exception) {
                    if (continuation.isActive) continuation.resumeWithException(IllegalStateException("secure_store_failed"))
                }
            })
        }

    companion object {
        private const val PREFERENCES = "FlutterSecureStorage"
    }
}
