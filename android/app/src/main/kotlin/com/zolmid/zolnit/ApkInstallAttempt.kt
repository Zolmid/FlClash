package com.zolmid.zolnit

internal class ApkInstallAttempt(
    val sessionId: Int,
    val versionCode: Long,
    private val complete: (String) -> Unit,
) {
    private var finished = false
    private var reported = false
    private var unobservableSince: Long? = null
    private var confirmation = false
    private var paused = false

    @Synchronized
    fun confirmationLaunched(): Boolean {
        if (finished || reported || confirmation) return false
        confirmation = true
        return true
    }

    @Synchronized
    fun paused() {
        if (confirmation && !finished) paused = true
    }

    @Synchronized
    fun returned(): Boolean = !finished && confirmation && paused

    @Synchronized
    fun unobservable(now: Long): Boolean {
        val since = unobservableSince ?: now.also { unobservableSince = it }
        return now - since >= 30000
    }

    @Synchronized
    fun reportRecovery() {
        if (finished || reported) return
        reported = true
        complete("failed")
    }

    @Synchronized
    fun finish(status: String): Boolean {
        if (finished) return false
        finished = true
        if (!reported) {
            reported = true
            complete(status)
        }
        return true
    }
}

internal enum class ApkReconciliation { WAIT, ABANDON, INSTALLED, CANCELLED }

internal fun apkReconciliation(
    sessionExists: Boolean,
    active: Boolean,
    installed: Boolean,
    expired: Boolean,
): ApkReconciliation = when {
    !sessionExists && installed -> ApkReconciliation.INSTALLED
    !sessionExists -> ApkReconciliation.CANCELLED
    active && !expired -> ApkReconciliation.WAIT
    else -> ApkReconciliation.ABANDON
}
