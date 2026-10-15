package com.follow.clash

import org.junit.Assert.assertEquals
import org.junit.Test

class StatusWidgetLayoutTest {
    @Test
    fun `a narrow single row keeps the toggle accessible in the compact layout`() {
        assertEquals(StatusWidgetLayout.COMPACT, statusWidgetLayout(150, 100))
    }

    @Test
    fun `a wide single row shows the profile beside the toggle`() {
        assertEquals(StatusWidgetLayout.ROW, statusWidgetLayout(250, 100))
    }

    @Test
    fun `two rows and unspecified launcher sizes use the square layout`() {
        assertEquals(StatusWidgetLayout.SQUARE, statusWidgetLayout(180, 210))
        assertEquals(StatusWidgetLayout.SQUARE, statusWidgetLayout(0, 0))
    }
}
