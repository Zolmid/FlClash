package com.zolmid.zolnit.network

import android.content.Context
import com.alibaba.pdns.DNSResolver

internal fun officialCloudDnsSdkBackend(context: Context): OwnedDnsSdkBackend = AlibabaCloudDnsSdk(context.applicationContext)

private class AlibabaCloudDnsSdk(private val context: Context) : OwnedDnsSdkBackend {
    companion object { private val claimed = java.util.concurrent.atomic.AtomicBoolean() }
    private var configured = false
    @Synchronized override fun configure(account: String, key: String, secret: String) {
        throw UnsupportedOperationException("FusionDNS short-lived provisioning is not accepted")
    }
    private fun strictFlags() {
        DNSResolver.setEnableLocalDns(false)
        DNSResolver.setEnableLogger(false)
        DNSResolver.setSchemaType(DNSResolver.HTTPS)
        DNSResolver.setEnableCache(false)
        DNSResolver.setImmutableCacheEnable(false)
        DNSResolver.setEnableSpeedTest(false)
        DNSResolver.setKeepAliveDomains(emptyArray())
        DNSResolver.setTimeout(2)
    }
    @Synchronized override fun lookup(host: String): List<String> {
        check(configured)
        strictFlags()
        check(!DNSResolver.getEnableLocalDns() && DNSResolver.getSchemaType() == DNSResolver.HTTPS)
        return DNSResolver.getInstance().getIpsByHost(host)?.toList() ?: emptyList()
    }
}
