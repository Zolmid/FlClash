package com.zolmid.zolnit.network

import java.net.InetAddress

internal interface OwnedDnsSdkBackend {
    fun configure(port: Int, key: String, secret: String)
    fun lookup(host: String): List<String>
}

internal class OwnedDnsSdkBridge(
    private val diagnostic: Boolean,
    private val backend: OwnedDnsSdkBackend?,
) {
    @Volatile private var hosts = emptySet<String>()
    private val generation = java.util.concurrent.atomic.AtomicInteger()
    private val lookupSlot = java.util.concurrent.Semaphore(1)
    @Volatile private var expiresAt = 0L
    private val stateLock = Any()

    @Synchronized fun configure(arguments: Map<*, *>): Boolean {
        val observed = synchronized(stateLock) { hosts = emptySet(); generation.incrementAndGet() }
        if (!diagnostic || backend == null) return false
        val scope = (arguments["hosts"] as? List<*>)?.filterIsInstance<String>() ?: return false
        if (scope.isEmpty() || scope.size > 256 || scope.size != (arguments["hosts"] as List<*>).size || scope.any { !validHost(it) }) return false
        val port = (arguments["port"] as? Number)?.toInt() ?: return false
        val expiry = (arguments["expiresAt"] as? Number)?.toLong() ?: return false
        val remaining = expiry - System.currentTimeMillis()
        if (port !in 1..65535 || remaining !in 1..300_000) return false
        val deadline = System.nanoTime() / 1_000_000 + remaining
        val credentials = listOf("keyId", "secret").map {
            (arguments[it] as? String)?.takeIf { value -> value.matches(Regex("[a-f0-9]{64}")) } ?: return false
        }
        return try {
            backend.configure(port, credentials[0], credentials[1])
            synchronized(stateLock) {
                if (observed == generation.get()) { hosts = scope.toSet(); expiresAt = deadline; true } else false
            }
        } catch (_: Exception) { false }
    }

    fun lookup(host: String): List<String> {
        if (!diagnostic || host !in hosts || backend == null || System.nanoTime() / 1_000_000 >= expiresAt) return emptyList()
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
