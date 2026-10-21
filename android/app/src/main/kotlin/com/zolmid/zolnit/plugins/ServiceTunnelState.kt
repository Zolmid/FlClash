package com.zolmid.zolnit.plugins

import com.zolmid.zolnit.RunState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

internal fun CoroutineScope.observeTunnelState(
    runState: StateFlow<RunState>,
    report: (String) -> Unit,
): Job = launch(Dispatchers.Main) {
    runState.collect { state ->
        report(
            when (state) {
                RunState.STARTED -> "connected"
                RunState.STARTING, RunState.STOPPING -> "pending"
                RunState.STOPPED -> "disconnected"
            },
        )
    }
}
