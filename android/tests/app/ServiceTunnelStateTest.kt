package com.zolmid.zolnit.plugins

import com.zolmid.zolnit.RunState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ServiceTunnelStateTest {
    @Test
    fun `observes the native owner through permission pending start and stop`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val states = MutableStateFlow(RunState.STOPPED)
            val reports = mutableListOf<String>()
            val observer = backgroundScope.observeTunnelState(states, reports::add)
            runCurrent()
            for (state in listOf(RunState.STARTING, RunState.STARTED, RunState.STOPPING, RunState.STOPPED)) {
                states.value = state
                runCurrent()
            }
            assertEquals(listOf("disconnected", "pending", "connected", "pending", "disconnected"), reports)
            observer.cancel()
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun `engine scope cancellation stops reports and reattach publishes the current run`() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val states = MutableStateFlow(RunState.STOPPED)
            val reports = mutableListOf<String>()
            val engineScope = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
            val observer = engineScope.observeTunnelState(states, reports::add)
            runCurrent()
            engineScope.cancel()
            states.value = RunState.STARTED
            runCurrent()
            assertTrue(observer.isCancelled)
            assertEquals(listOf("disconnected"), reports)

            val nextObserver = backgroundScope.observeTunnelState(states, reports::add)
            runCurrent()
            assertEquals(listOf("disconnected", "connected"), reports)
            nextObserver.cancel()
        } finally {
            Dispatchers.resetMain()
        }
    }
}
