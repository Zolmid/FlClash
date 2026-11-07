package com.zolmid.zolnit

import org.junit.Assert.*
import org.junit.Test

class ApkInstallAttemptTest {
    @Test
    fun unavailableInstallerRecoversUiWithoutReleasingSessionOwnership() {
        val results = mutableListOf<String>()
        val attempt = ApkInstallAttempt(8, 3, results::add)
        assertFalse(attempt.unobservable(1000))
        assertFalse(attempt.unobservable(30999))
        assertTrue(attempt.unobservable(31000))
        attempt.reportRecovery()
        attempt.reportRecovery()
        assertFalse(attempt.confirmationLaunched())
        assertEquals(listOf("failed"), results)
        assertTrue(attempt.finish("cancelled"))
        assertFalse(attempt.finish("installed"))
        assertEquals(listOf("failed"), results)
    }
    @Test
    fun confirmationReturnRequiresPauseAndDoesNotRelaunch() {
        val results = mutableListOf<String>()
        val attempt = ApkInstallAttempt(42, 2, results::add)
        attempt.paused()
        assertFalse(attempt.returned())
        assertTrue(attempt.confirmationLaunched())
        assertFalse(attempt.confirmationLaunched())
        assertFalse(attempt.returned())
        attempt.paused()
        assertTrue(attempt.returned())
        assertTrue(attempt.finish("cancelled"))
        assertFalse(attempt.returned())
        assertFalse(attempt.finish("installed"))
        assertEquals(listOf("cancelled"), results)
    }

    @Test
    fun successFailureAndLateCallbacksResolveOncePerAttempt() {
        for (status in listOf("installed", "failed", "cancelled")) {
            val results = mutableListOf<String>()
            val attempt = ApkInstallAttempt(7, 3, results::add)
            assertTrue(attempt.finish(status))
            assertFalse(attempt.confirmationLaunched())
            assertFalse(attempt.finish("installed"))
            assertEquals(listOf(status), results)
        }
    }
    @Test
    fun lostCallbackWaitsForActiveSessionThenAbandonsOrChecksInstalledVersion() {
        assertEquals(ApkReconciliation.WAIT, apkReconciliation(true, true, false, false))
        assertEquals(ApkReconciliation.ABANDON, apkReconciliation(true, true, false, true))
        assertEquals(ApkReconciliation.ABANDON, apkReconciliation(true, false, false, false))
        assertEquals(ApkReconciliation.CANCELLED, apkReconciliation(false, false, false, false))
        assertEquals(ApkReconciliation.INSTALLED, apkReconciliation(false, false, true, false))
    }

}
