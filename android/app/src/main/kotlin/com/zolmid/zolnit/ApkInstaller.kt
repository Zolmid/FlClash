package com.zolmid.zolnit

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.IntentCompat
import androidx.core.net.toUri
import com.zolmid.zolnit.common.GlobalState
import java.io.File

object ApkInstaller {
    private val handler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var attempt: ApkInstallAttempt? = null
    private var epoch = 0
    fun epoch(): Int = synchronized(lock) { epoch }
    private var foreground = true
    private var reconciliationStarted = 0L
    private val watchdog = object : Runnable {
        override fun run() {
            val current = synchronized(lock) { attempt } ?: return
            if (foreground) reconcile(GlobalState.application, current, force = true)
            if (synchronized(lock) { attempt === current }) handler.postDelayed(this, 90000)
        }
    }

    private fun finish(current: ApkInstallAttempt, status: String) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { finish(current, status) }
            return
        }
        val matched = synchronized(lock) {
            if (attempt !== current) false else {
                attempt = null
                true
            }
        }
        if (matched) {
            handler.removeCallbacks(watchdog)
            current.finish(status)
        }
    }

    private fun reconcile(context: Context, current: ApkInstallAttempt, force: Boolean, allowBackground: Boolean = false) {
        if ((!foreground && !allowBackground) || synchronized(lock) { attempt !== current }) return
        val installer = context.packageManager.packageInstaller
        val info = try {
            installer.getSessionInfo(current.sessionId)
        } catch (_: Exception) {
            recoverUnobservable(context, current, force, allowBackground)
            return
        }
        if (info == null) {
            @Suppress("DEPRECATION")
            val installed = try {
                val info = context.packageManager.getPackageInfo(context.packageName, 0)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
            } catch (_: Exception) {
                recoverUnobservable(context, current, force, allowBackground)
                return
            }
            val outcome = apkReconciliation(false, false, installed >= current.versionCode, force)
            finish(current, if (outcome == ApkReconciliation.INSTALLED) "installed" else "cancelled")
            return
        }
        if (apkReconciliation(true, info.isActive, false, force) == ApkReconciliation.WAIT) {
            if (reconciliationStarted == 0L) reconciliationStarted = android.os.SystemClock.elapsedRealtime()
            val expired = android.os.SystemClock.elapsedRealtime() - reconciliationStarted >= 90000
            handler.postDelayed({ reconcile(context, current, expired, allowBackground) }, 1000)
            return
        }
        if (runCatching { installer.abandonSession(current.sessionId) }.isSuccess) {
            finish(current, "cancelled")
        } else {
            recoverUnobservable(context, current, true, allowBackground)
        }
    }

    private fun recoverUnobservable(context: Context, current: ApkInstallAttempt, force: Boolean, allowBackground: Boolean) {
        val expired = current.unobservable(android.os.SystemClock.elapsedRealtime())
        if (expired) current.reportRecovery()
        handler.postDelayed({ reconcile(context, current, force, allowBackground) }, if (expired) 30000 else 1000)
    }

    fun activityPaused() {
        foreground = false
        synchronized(lock) { attempt }?.paused()
    }

    fun activityResumed(context: Context) {
        foreground = true
        val current = synchronized(lock) { attempt } ?: return
        if (current.returned()) {
            reconciliationStarted = 0L
            handler.postDelayed({ reconcile(context, current, false) }, 1000)
        }
    }

    fun detach(context: Context) {
        val current = synchronized(lock) { epoch++; attempt } ?: return
        reconcile(context, current, force = true, allowBackground = true)
    }

    fun status(context: Context, sessionId: Int, status: Int, confirm: Intent?) {
        val current = synchronized(lock) { attempt?.takeIf { it.sessionId == sessionId } } ?: return
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                if (!current.confirmationLaunched()) return
                if (confirm == null || runCatching {
                        context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }.isFailure
                ) {
                    val installer = context.packageManager.packageInstaller
                    if (runCatching { installer.abandonSession(sessionId) }.isSuccess) {
                        finish(current, "failed")
                    } else {
                        handler.postDelayed({ reconcile(context, current, true) }, 1000)
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> finish(current, "installed")
            PackageInstaller.STATUS_FAILURE_ABORTED -> finish(current, "cancelled")
            else -> finish(current, "failed")
        }
    }
    fun canRequestInstalls(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()

    fun unknownSourcesSettings(context: Context): Intent = Intent(
        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
        "package:${context.packageName}".toUri(),
    )

    @Suppress("DEPRECATION")
    fun validate(context: Context, path: String): File {
        val apk = ApkInstallPolicy.stagedApk(context.cacheDir, path)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val manager = context.packageManager
        val installed = manager.getPackageInfo(context.packageName, flags).identity()
        val candidate = manager.getPackageArchiveInfo(apk.path, flags)?.identity()
            ?: error("APK identity is unavailable")
        require(ApkInstallPolicy.allowsUpdate(installed, candidate)) {
            "APK package, version or signing identity does not match this app"
        }
        return apk
    }

    @Suppress("DEPRECATION")
    private fun PackageInfo.identity(): ApkIdentity {
        val signers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            signingInfo?.apkContentsSigners.orEmpty()
        } else {
            signatures.orEmpty()
        }.map { it.toCharsString() }.toSet()
        val history = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            signingInfo?.hasMultipleSigners() == false
        ) {
            signingInfo?.signingCertificateHistory.orEmpty().map { it.toCharsString() }.toSet()
        } else {
            signers
        }
        return ApkIdentity(
            packageName,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) longVersionCode else versionCode.toLong(),
            signers,
            history,
        )
    }

    fun install(context: Context, path: String, expectedEpoch: Int, complete: (String) -> Unit) {
        val apk = validate(context, path)
        check(canRequestInstalls(context)) { "APK installation permission is not granted" }
        @Suppress("DEPRECATION")
        val candidateInfo = context.packageManager.getPackageArchiveInfo(apk.path, 0)
            ?: error("APK identity is unavailable")
        @Suppress("DEPRECATION")
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) candidateInfo.longVersionCode else candidateInfo.versionCode.toLong()
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
        }
        val sessionId = installer.createSession(params)
        try {
            val current = ApkInstallAttempt(sessionId, versionCode, complete)
            synchronized(lock) {
                check(expectedEpoch == epoch && attempt == null) { "APK installation is no longer available" }
                attempt = current
            }
            handler.postDelayed(watchdog, 90000)
            installer.openSession(sessionId).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("base.apk", 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                session.commit(statusIntent(context, sessionId).intentSender)
            }
        } catch (error: Exception) {
            val abandoned = runCatching { installer.abandonSession(sessionId) }.isSuccess
            val current = synchronized(lock) { attempt?.takeIf { it.sessionId == sessionId } }
            if (current == null) throw error
            if (abandoned) finish(current, "failed")
            else handler.post { reconcile(context, current, force = true, allowBackground = true) }
        }
    }

    private fun statusIntent(context: Context, sessionId: Int): PendingIntent {
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        // PackageInstaller supplies status extras, so this explicit receiver intent must be mutable.
        return PendingIntent.getBroadcast(
            context,
            sessionId,
            Intent(context, ApkInstallReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or mutable,
        )
    }
}

class ApkInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ApkInstaller.status(
            context,
            intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1),
            intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE),
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_INTENT, Intent::class.java),
        )
    }
}
