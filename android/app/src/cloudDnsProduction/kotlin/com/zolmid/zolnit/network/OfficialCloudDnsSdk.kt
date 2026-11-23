package com.zolmid.zolnit.network

import android.content.Context
import com.alibaba.pdns.DNSResolver
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

internal fun officialCloudDnsSdkBackend(context: Context): OwnedDnsSdkBackend = AlibabaCloudDnsSdk(context.applicationContext)

private class AlibabaCloudDnsSdk(private val context: Context) : OwnedDnsSdkBackend {
    private val workers = Executors.newFixedThreadPool(2) { task -> Thread(task, "zolnit-sdk-query").apply { isDaemon = true } }
    @Volatile private var configured = false
    @Synchronized override fun configure(port: Int, key: String, secret: String) {
        configured = false
        strictFlags()
        DNSResolver.InitFusionDNS(context, arrayOf("127.0.0.1"), null, null, port.toString(), "link.zolmid.com", key, secret)
        strictFlags()
        DNSResolver.getInstance().clear()
        configured = true
    }
    private fun strictFlags() {
        DNSResolver.setEnableLocalDns(false)
        DNSResolver.setEnableLogger(false)
        DNSResolver.setSchemaType(DNSResolver.HTTP)
        DNSResolver.setEnableCache(true)
        DNSResolver.setMinTtlCache(0)
        DNSResolver.setMaxTtlCache(1)
        DNSResolver.setImmutableCacheEnable(false)
        DNSResolver.setEnableSpeedTest(false)
        DNSResolver.setIspEnable(false)
        DNSResolver.setIgnoreNetworkChanges(true)
        DNSResolver.setKeepAliveDomains(emptyArray())
        DNSResolver.setTimeout(2)
    }
    override fun lookup(host: String): List<String> {
        check(configured && !DNSResolver.getEnableLocalDns() && DNSResolver.getSchemaType() == DNSResolver.HTTP)
        val tasks = listOf(
            Callable { DNSResolver.getInstance().getIPsV4ByHost(host)?.toList() ?: emptyList() },
            Callable { DNSResolver.getInstance().getIPsV6ByHost(host)?.toList() ?: emptyList() },
        )
        return workers.invokeAll(tasks, 2500, TimeUnit.MILLISECONDS).flatMap { future ->
            if (future.isCancelled) emptyList() else runCatching { future.get() }.getOrDefault(emptyList())
        }.distinct()
    }
}
