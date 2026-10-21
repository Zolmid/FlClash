package com.zolmid.zolnit

import java.io.File

internal data class ApkIdentity(
    val packageName: String,
    val versionCode: Long,
    val signers: Set<String>,
    val signingHistory: Set<String> = signers,
)

internal object ApkInstallPolicy {
    const val STAGING_DIRECTORY = "app-updates"

    fun stagedApk(cacheDirectory: File, path: String): File {
        val cache = cacheDirectory.canonicalFile
        val staging = File(cache, STAGING_DIRECTORY)
        require(staging.canonicalFile == staging.absoluteFile) { "Update staging cannot be a symlink" }
        val requested = File(path)
        require(requested.isAbsolute) { "APK path must be absolute" }
        val apk = requested.canonicalFile
        val release = apk.parentFile
        require(release?.parentFile == staging && isReleaseDirectory(release.name)) {
            "APK is outside a private release staging directory"
        }
        val requestedRelease = requested.parentFile
        val requestedStaging = requestedRelease.parentFile
        require(File(requestedStaging.parentFile.canonicalFile, requestedStaging.name) == staging) {
            "Update staging cannot be a symlink"
        }
        require(File(requestedRelease.parentFile.canonicalFile, requestedRelease.name) == release) {
            "Release staging cannot be a symlink"
        }
        require(File(requested.parentFile.canonicalFile, requested.name) == apk) {
            "APK cannot be a symlink"
        }
        require(apk.extension.equals("apk", ignoreCase = true) && apk.isFile && apk.canRead() && apk.length() > 0) {
            "Update must be a readable APK file"
        }
        return apk
    }

    private fun isReleaseDirectory(name: String): Boolean {
        if (name.length < 66 || name[name.length - 65] != '-') return false
        val tag = name.dropLast(65)
        val digest = name.takeLast(64)
        return tag.length <= 128 && Regex("^[vV]?\\d[0-9A-Za-z._+\\-]*$").matches(tag) &&
            Regex("^[0-9a-f]{64}$").matches(digest)
    }

    fun allowsUpdate(installed: ApkIdentity, candidate: ApkIdentity): Boolean {
        if (candidate.packageName != installed.packageName ||
            candidate.versionCode <= installed.versionCode ||
            installed.signers.isEmpty() || candidate.signers.isEmpty()
        ) {
            return false
        }
        if (candidate.signers == installed.signers) return true
        if (installed.signers.size != 1 || candidate.signers.size != 1) return false
        return candidate.signingHistory.containsAll(installed.signers) &&
            candidate.signingHistory.containsAll(candidate.signers)
    }
}
