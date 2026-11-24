package com.zolmid.zolnit.service

import org.junit.Assert.assertEquals
import org.junit.Test

class UidPackageIdentityTest {
    @Test
    fun `only a single nonempty package identifies an owner`() {
        assertEquals("com.example.app", arrayOf("com.example.app").unambiguousPackageName())
        assertEquals("", null.unambiguousPackageName())
        assertEquals("", emptyArray<String>().unambiguousPackageName())
        assertEquals("", arrayOf("").unambiguousPackageName())
        assertEquals("", arrayOf("com.example.app", "com.example.other").unambiguousPackageName())
    }
}
