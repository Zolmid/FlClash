package com.zolmid.zolnit.network

import java.net.InetAddress

internal interface OwnedDnsSdkBackend {
    fun configure(account: String, key: String, secret: String)
    fun lookup(host: String): List<String>
}

internal class OwnedDnsSdkBridge(
    private val diagnostic: Boolean,
    private val backend: OwnedDnsSdkBackend?,
) {
    @Volatile private var hosts = emptySet<String>()
    private val generation = java.util.concurrent.atomic.AtomicInteger()
    private val lookupSlot = java.util.concurrent.Semaphore(1)
    private var initialized = false
    private val stateLock = Any()

    @Synchronized fun configure(arguments: Map<*, *>): Boolean {
        val observed = synchronized(stateLock) { hosts = emptySet(); generation.incrementAndGet() }
        if (!diagnostic || backend == null || initialized) return false
        val scope = (arguments["hosts"] as? List<*>)?.filterIsInstance<String>() ?: return false
        if (scope.isEmpty() || scope.size > 256 || scope.size != (arguments["hosts"] as List<*>).size || scope.any { !validHost(it) }) return false
        val credentials = listOf("accountId", "accessKeyId", "accessKeySecret").map {
            (arguments[it] as? String)?.takeIf { value -> value.isNotEmpty() && value.length <= 512 && value.all { char -> char.code in 33..126 } } ?: return false
        }
        return try {
            initialized = true
            backend.configure(credentials[0], credentials[1], credentials[2])
            synchronized(stateLock) {
                if (observed == generation.get()) { hosts = scope.toSet(); true } else false
            }
        } catch (_: Exception) { false }
    }

    fun lookup(host: String): List<String> {
        if (!diagnostic || host !in hosts || backend == null) return emptyList()
        if (!lookupSlot.tryAcquire()) return emptyList()
        val observed = generation.get()
        return try {
            val values = backend.lookup(host)
            if (observed != generation.get() || host !in hosts || values.isEmpty() || values.size > 32 || values.any { !validAddress(it) }) emptyList() else values.distinct()
        } catch (_: Exception) { emptyList() } finally { lookupSlot.release() }
    }

    fun disable() { synchronized(stateLock) { hosts = emptySet(); generation.incrementAndGet() } }

    companion object {
        fun validHost(host: String): Boolean = host.length <= 253 &&
            host.matches(Regex("[a-z0-9]+[a-z0-9.-]*[a-z0-9]|[a-z0-9]")) &&
            host.split('.').all { it.isNotEmpty() && it.length <= 63 && !it.startsWith('-') && !it.endsWith('-') } &&
            (host == "link.zolmid.com" || host.endsWith(".nodes.zolmid.com"))

        fun validAddress(value: String): Boolean {
            val v4 = value.split('.').let { parts -> parts.size == 4 && parts.all { part ->
                part.isNotEmpty() && part.all { it in '0'..'9' } && part.toIntOrNull()?.let { it in 0..255 } == true
            } }
            if (!v4 && !(value.contains(':') && value.length <= 45 && value.matches(Regex("[0-9a-fA-F:.]+")))) return false
            return runCatching { InetAddress.getByName(value).let { !it.isLoopbackAddress && !it.isAnyLocalAddress && !it.isMulticastAddress } }.getOrDefault(false)
        }
    }
}
