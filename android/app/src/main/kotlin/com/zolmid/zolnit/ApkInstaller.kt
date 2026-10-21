package com.zolmid.zolnit

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.IntentCompat
import androidx.core.net.toUri
import com.zolmid.zolnit.common.GlobalState
import java.io.File

object ApkInstaller {
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

    fun install(context: Context, path: String) {
        val apk = validate(context, path)
        check(canRequestInstalls(context)) { "APK installation permission is not granted" }
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
        }
        val sessionId = installer.createSession(params)
        try {
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
            runCatching { installer.abandonSession(sessionId) }
            throw error
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
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_INTENT, Intent::class.java)
                    ?: return
                runCatching { context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                    .onFailure { GlobalState.log("Unable to confirm APK installation: $it") }
            }
            PackageInstaller.STATUS_SUCCESS -> Unit
            else -> {
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                GlobalState.log("APK install failed: $message")
                GlobalState.application.showToast(message)
            }
        }
    }
}
