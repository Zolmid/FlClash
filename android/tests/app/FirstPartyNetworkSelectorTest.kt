package com.zolmid.zolnit.network

import android.net.NetworkCapabilities
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

private class FixtureNetworks : FirstPartyNetworks<String> {
    override var apiLevel = 36
    override val myUid = 100
    var default = FirstPartyNetwork("our-vpn", true, true, false, 100)
    var candidates = emptyList<FirstPartyNetwork<String>>()
    var waited = 0
    override fun active() = default
    override fun all() = candidates
    override suspend fun awaitDefault() = default
    override suspend fun awaitUnderlying(): FirstPartyNetwork<String> {
        waited++
        return FirstPartyNetwork("new-wifi", true, false, false)
    }
}

class FirstPartyNetworkSelectorTest {
    @Test fun waitingRequestContainsOnlyImmutableInternetAndNotVpnCapabilities() {
        assertEquals(
            setOf(NetworkCapabilities.NET_CAPABILITY_INTERNET, NetworkCapabilities.NET_CAPABILITY_NOT_VPN),
            firstPartyNetworkRequestCapabilities().toSet(),
        )
        assertFalse(firstPartyNetworkRequestCapabilities().contains(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
    }

    @Test fun prefersValidatedThenInternetAndReselectsAfterTransition() = runTest {
        val networks = FixtureNetworks()
        val selector = FirstPartyNetworkSelector(networks) { false }
        networks.candidates = listOf(
            FirstPartyNetwork("our-vpn", true, true, true, 100),
            FirstPartyNetwork("wifi", true, false, false),
            FirstPartyNetwork("cell", true, false, true),
            FirstPartyNetwork("no-internet", false, false, true),
        )
        assertEquals("cell", selector.select())
        networks.candidates = listOf(FirstPartyNetwork("wifi", true, false, false))
        assertEquals("wifi", selector.select())
        networks.candidates = emptyList()
        assertEquals("new-wifi", selector.select())
        assertEquals(1, networks.waited)
    }

    @Test fun thirdPartyOrUnknownVpnOwnerRetainsDefaultEvenIfOwnStateIsStale() = runTest {
        val networks = FixtureNetworks()
        val selector = FirstPartyNetworkSelector(networks) { error("modern API must not consult stale service state") }
        for (owner in listOf(200, -1, null)) {
            networks.default = FirstPartyNetwork("third-party", true, true, false, owner)
            assertEquals("third-party", selector.select())
        }
        assertEquals(0, networks.waited)
    }

    @Test fun legacyOwnershipRequiresBothActiveVpnAndOwnService() = runTest {
        val networks = FixtureNetworks().apply { apiLevel = 24 }
        assertEquals("our-vpn", FirstPartyNetworkSelector(networks) { false }.select())
        assertEquals("new-wifi", FirstPartyNetworkSelector(networks) { true }.select())
        networks.default = FirstPartyNetwork("plain-wifi", true, false, true)
        assertEquals("plain-wifi", FirstPartyNetworkSelector(networks) { true }.select())
    }

    @Test fun callbackRegistrationUnregistersOnceAcrossCancellationRaces() {
        for (cancelBeforeRegistration in listOf(false, true)) {
            var unregisters = 0
            val registration = FirstPartyCallbackRegistration { unregisters++ }
            if (cancelBeforeRegistration) registration.close()
            registration.registered()
            registration.close()
            registration.close()
            assertEquals(1, unregisters)
        }
    }
}
