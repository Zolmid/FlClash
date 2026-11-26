package com.zolmid.zolnit.plugins

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RestartReceiptStoreTest {
    @Test
    fun `an older restart cannot consume the newest receipt`() {
        val store = RestartReceiptStore<String>()
        val old = store.put("old")
        val newest = store.put("new")
        assertNull(store.take(old))
        assertEquals("new", store.take(newest))
        assertNull(store.take(newest))
    }
}
