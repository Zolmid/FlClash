package com.zolmid.zolnit.plugins

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InstallPermissionResultTest {
    @Test
    fun `install permission does not consume battery or other activity results`() {
        var installResults = 0
        for (requestCode in listOf(1001, 1002, 1003, 1004, 1005, 9999)) {
            assertFalse(consumeActivityResult(requestCode, INSTALL_PERMISSION_REQUEST_CODE) { installResults++ })
        }
        assertEquals(0, installResults)
        assertEquals(1005, BATTERY_OPTIMIZATION_REQUEST_CODE)
        assertEquals(1006, INSTALL_PERMISSION_REQUEST_CODE)
        assertTrue(consumeActivityResult(INSTALL_PERMISSION_REQUEST_CODE, INSTALL_PERMISSION_REQUEST_CODE) {
            installResults++
        })
        assertEquals(1, installResults)
    }

    @Test
    fun `battery and installer callbacks remain isolated in either listener order`() {
        for (appFirst in listOf(true, false)) {
            var batteryResults = 0
            var installResults = 0
            val appListener: (Int) -> Boolean = { requestCode ->
                consumeActivityResult(requestCode, INSTALL_PERMISSION_REQUEST_CODE) { installResults++ }
            }
            val batteryListener: (Int) -> Boolean = { requestCode ->
                consumeActivityResult(requestCode, BATTERY_OPTIMIZATION_REQUEST_CODE) { batteryResults++ }
            }
            val listeners = if (appFirst) {
                listOf(appListener, batteryListener)
            } else {
                listOf(batteryListener, appListener)
            }
            assertTrue(listeners.any { it(BATTERY_OPTIMIZATION_REQUEST_CODE) })
            assertEquals(1, batteryResults)
            assertEquals(0, installResults)
            assertTrue(listeners.any { it(INSTALL_PERMISSION_REQUEST_CODE) })
            assertEquals(1, batteryResults)
            assertEquals(1, installResults)
        }
    }
}
