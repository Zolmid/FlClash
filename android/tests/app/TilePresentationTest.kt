package com.follow.clash

import com.follow.clash.models.SharedState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TilePresentationTest {
    @Test
    fun `profile names appear only while the actual service is started`() {
        val state = SharedState(currentProfileName = "Work")
        assertEquals("Work", state.tileSubtitle(RunState.STARTED, "Connected", "Disconnected"))
        assertNull(state.tileSubtitle(RunState.STARTING, "Connected", "Disconnected"))
        assertNull(state.tileSubtitle(RunState.STOPPED, "Connected", "Disconnected"))
    }

    @Test
    fun `disabling profile names uses localized connection labels`() {
        val state = SharedState(currentProfileName = "Work", showQuickSettingsProfileName = false)
        assertEquals("已连接", state.tileSubtitle(RunState.STARTED, "已连接", "已断开"))
        assertEquals("已断开", state.tileSubtitle(RunState.STOPPED, "已连接", "已断开"))
    }
}
