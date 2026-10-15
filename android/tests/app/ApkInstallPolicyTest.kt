package com.follow.clash

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ApkInstallPolicyTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    private val cache: File
        get() = File(temporaryFolder.root, "cache").apply { mkdirs() }

    private val releaseName = "v0.8.91-${"a".repeat(64)}"

    private fun staged(name: String = "update.apk"): File =
        File(cache, "${ApkInstallPolicy.STAGING_DIRECTORY}/$releaseName").apply { mkdirs() }
            .resolve(name).apply { writeBytes(byteArrayOf(1)) }

    @Test
    fun `a nonempty real apk in a tag and digest release directory is accepted`() {
        val apk = staged()
        assertEquals(apk.canonicalFile, ApkInstallPolicy.stagedApk(cache, apk.path))
        val upperCase = staged("update.APK")
        assertEquals(upperCase.canonicalFile, ApkInstallPolicy.stagedApk(cache, upperCase.path))
    }

    @Test
    fun `relative paths uris outside files and nested files are rejected`() {
        val outside = temporaryFolder.newFile("outside.apk").apply { writeBytes(byteArrayOf(1)) }
        val nested = staged("parent.apk").apply { delete(); mkdir() }
            .resolve("nested.apk").apply { writeBytes(byteArrayOf(1)) }
        for (path in listOf("update.apk", "content://downloads/update.apk", outside.path, nested.path)) {
            assertThrows(IllegalArgumentException::class.java) {
                ApkInstallPolicy.stagedApk(cache, path)
            }
        }
    }

    @Test
    fun `release staging requires a tag and full digest rather than an arbitrary subdirectory`() {
        val staging = File(cache, ApkInstallPolicy.STAGING_DIRECTORY).apply { mkdirs() }
        val paths = listOf(
            File(staging, "direct.apk"),
            File(staging, "arbitrary/update.apk"),
            File(staging, "v0.8.91-short/update.apk"),
            File(staging, "v0.8.91-${"A".repeat(64)}/update.apk"),
        )
        for (file in paths) {
            file.parentFile.mkdirs()
            file.writeBytes(byteArrayOf(1))
            assertThrows(IllegalArgumentException::class.java) {
                ApkInstallPolicy.stagedApk(cache, file.path)
            }
        }
    }

    @Test
    fun `directories empty files and other extensions are rejected`() {
        val directory = staged("directory.apk").apply { delete(); mkdir() }
        val empty = staged("empty.apk").apply { writeBytes(byteArrayOf()) }
        val other = staged("update.zip")
        for (file in listOf(directory, empty, other)) {
            assertThrows(IllegalArgumentException::class.java) {
                ApkInstallPolicy.stagedApk(cache, file.path)
            }
        }
    }

    @Test
    fun `an apk symlink is rejected even when its target is in staging`() {
        val real = staged()
        val link = File(real.parentFile, "link.apk")
        Files.createSymbolicLink(link.toPath(), real.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            ApkInstallPolicy.stagedApk(cache, link.path)
        }
    }

    @Test
    fun `a staging symlink cannot redirect installation outside private cache`() {
        val outside = temporaryFolder.newFolder("external-stage")
        val apk = File(outside, "$releaseName/update.apk").apply {
            parentFile.mkdirs()
            writeBytes(byteArrayOf(1))
        }
        val link = File(cache, ApkInstallPolicy.STAGING_DIRECTORY)
        Files.createSymbolicLink(link.toPath(), outside.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            ApkInstallPolicy.stagedApk(cache, File(link, "$releaseName/${apk.name}").path)
        }
    }

    @Test
    fun `a release directory symlink is rejected even within staging`() {
        val apk = staged()
        val link = File(apk.parentFile.parentFile, "v0.8.92-${"b".repeat(64)}")
        Files.createSymbolicLink(link.toPath(), apk.parentFile.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            ApkInstallPolicy.stagedApk(cache, File(link, apk.name).path)
        }
    }

    @Test
    fun `an alternate staging symlink cannot alias a valid release`() {
        val apk = staged()
        val link = File(cache, "stage-alias")
        Files.createSymbolicLink(link.toPath(), apk.parentFile.parentFile.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            ApkInstallPolicy.stagedApk(cache, File(link, "$releaseName/${apk.name}").path)
        }
    }

    @Test
    fun `a release directory symlink cannot escape staging`() {
        val outside = temporaryFolder.newFolder("external-release")
        File(outside, "update.apk").writeBytes(byteArrayOf(1))
        val staging = File(cache, ApkInstallPolicy.STAGING_DIRECTORY).apply { mkdirs() }
        val link = File(staging, releaseName)
        Files.createSymbolicLink(link.toPath(), outside.toPath())
        assertThrows(IllegalArgumentException::class.java) {
            ApkInstallPolicy.stagedApk(cache, File(link, "update.apk").path)
        }
    }

    private val installed = ApkIdentity("com.follow.clash", 10, setOf("current"))

    @Test
    fun `an upgrade signed by the current certificate is accepted`() {
        assertTrue(ApkInstallPolicy.allowsUpdate(installed, installed.copy(versionCode = 11)))
    }

    @Test
    fun `other package equal version downgrade and unsigned identity are rejected`() {
        val upgrade = installed.copy(versionCode = 11)
        for (candidate in listOf(
            upgrade.copy(packageName = "com.other.app"),
            installed,
            installed.copy(versionCode = 9),
            upgrade.copy(signers = emptySet()),
        )) {
            assertFalse(ApkInstallPolicy.allowsUpdate(installed, candidate))
        }
        assertFalse(ApkInstallPolicy.allowsUpdate(installed.copy(signers = emptySet()), upgrade))
    }

    @Test
    fun `single signer rotation requires both certificates in the verified lineage`() {
        val rotated = ApkIdentity("com.follow.clash", 11, setOf("rotated"), setOf("current", "rotated"))
        assertTrue(ApkInstallPolicy.allowsUpdate(installed, rotated))
        assertFalse(ApkInstallPolicy.allowsUpdate(installed, rotated.copy(signingHistory = setOf("rotated"))))
        assertFalse(ApkInstallPolicy.allowsUpdate(installed, rotated.copy(signingHistory = setOf("current"))))
    }

    @Test
    fun `multiple signers must match exactly rather than using a union of history`() {
        val multiple = installed.copy(signers = setOf("first", "second"))
        assertTrue(ApkInstallPolicy.allowsUpdate(multiple, multiple.copy(versionCode = 11)))
        assertFalse(ApkInstallPolicy.allowsUpdate(multiple, ApkIdentity(
            "com.follow.clash", 11, setOf("third"), setOf("first", "second", "third"),
        )))
    }
}
