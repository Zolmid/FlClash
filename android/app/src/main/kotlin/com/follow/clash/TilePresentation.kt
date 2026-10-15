package com.follow.clash

import com.follow.clash.models.SharedState

internal fun SharedState.tileSubtitle(
    runState: RunState,
    connected: String,
    disconnected: String,
): String? = if (showQuickSettingsProfileName) {
    currentProfileName.takeIf { runState == RunState.STARTED && it.isNotBlank() }
} else {
    if (runState == RunState.STARTED) connected else disconnected
}
