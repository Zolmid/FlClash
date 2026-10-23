package com.zolmid.zolnit.nativeui

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeUiProtocolTest {
    @Test
    fun parsesContractSnapshot() {
        val snapshot = NativeUiProtocol.parseSnapshot(snapshotJson())

        requireNotNull(snapshot)
        assertEquals(7, snapshot.revision)
        assertEquals("connected", snapshot.connectionState)
        assertEquals("node-1", snapshot.selectedServerId)
        assertEquals(1, snapshot.servers.size)
        assertEquals(1_024L, snapshot.usage.usedBytes)
    }

    @Test
    fun rejectsMissingLabelsAndUnknownState() {
        val missingLabels = JSONObject(snapshotJson()).put("labels", JSONObject())
        val invalidState = JSONObject(snapshotJson()).put("connectionState", "starting")
        val invalidDirection = JSONObject(snapshotJson()).put("textDirection", "vertical")

        assertNull(NativeUiProtocol.parseSnapshot(missingLabels.toString()))
        assertNull(NativeUiProtocol.parseSnapshot(invalidState.toString()))
        assertNull(NativeUiProtocol.parseSnapshot(invalidDirection.toString()))
    }

    @Test
    fun distinguishesUnknownMetricsFromMeasuredZero() {
        val json = JSONObject(snapshotJson())
            .put("usage", JSONObject().put("usedBytes", JSONObject.NULL).put("totalBytes", JSONObject.NULL))
            .put("traffic", JSONObject().put("uploadBps", JSONObject.NULL).put("downloadBps", 0))
        val snapshot = requireNotNull(NativeUiProtocol.parseSnapshot(json.toString()))
        assertNull(snapshot.usage.usedBytes)
        assertNull(snapshot.traffic.uploadBps)
        assertEquals(0L, snapshot.traffic.downloadBps)
    }

    @Test
    fun emitsContractCommand() {
        val command = JSONObject(NativeUiProtocol.command("command-1", 3, "setMode", JSONObject().put("mode", "global")))

        assertEquals(1, command.getInt("schemaVersion"))
        assertEquals("command-1", command.getString("id"))
        assertEquals(3, command.getLong("accountGeneration"))
        assertEquals("global", command.getJSONObject("payload").getString("mode"))
    }

    @Test
    fun parsesReceiptWithoutTreatingItAsConnectionState() {
        val receipt = NativeUiProtocol.parseReceipt(
            JSONObject()
                .put("schemaVersion", 1)
                .put("id", "command-1")
                .put("accepted", true)
                .put("errorCode", JSONObject.NULL)
                .toString(),
        )

        requireNotNull(receipt)
        assertTrue(receipt.accepted)
        assertNull(receipt.errorCode)
    }

    @Test
    fun ignoresOldRevisionButReplacesGenerationAtNewRevision() {
        val gate = NativeUiSnapshotGate()
        val initial = requireNotNull(NativeUiProtocol.parseSnapshot(snapshotJson()))
        val old = requireNotNull(NativeUiProtocol.parseSnapshot(JSONObject(snapshotJson()).put("revision", 6).toString()))
        val replacement = requireNotNull(
            NativeUiProtocol.parseSnapshot(
                JSONObject(snapshotJson()).put("revision", 8).put("accountGeneration", 4).toString(),
            ),
        )

        assertTrue(gate.accept(initial))
        assertEquals(false, gate.accept(old))
        assertTrue(gate.accept(replacement))
        assertEquals(4L, gate.current?.accountGeneration)
    }

    @Test
    fun snapshotContractKeepsNullables() {
        val snapshot = NativeUiProtocol.parseSnapshot(
            JSONObject(snapshotJson())
                .put("selectedServerId", JSONObject.NULL)
                .put("planName", JSONObject.NULL)
                .toString(),
        )

        requireNotNull(snapshot)
        assertNull(snapshot.selectedServerId)
        assertNull(snapshot.planName)
        assertTrue(snapshot.servers.single().available)
    }

    private fun snapshotJson(): String = JSONObject()
        .put("schemaVersion", 1)
        .put("revision", 7)
        .put("accountGeneration", 3)
        .put("locale", "en")
        .put("textDirection", "ltr")
        .put("safeMode", false)
        .put("sessionStatus", "signedIn")
        .put("connectionState", "connected")
        .put("destination", "connect")
        .put("mode", "rule")
        .put("selectedServerId", "node-1")
        .put("servers", org.json.JSONArray().put(JSONObject().put("id", "node-1").put("name", "Singapore").put("available", true).put("latencyMs", 42)))
        .put("planName", "Standard")
        .put("planExpiresAt", JSONObject.NULL)
        .put("usage", JSONObject().put("usedBytes", 1_024).put("totalBytes", 2_048))
        .put("traffic", JSONObject().put("uploadBps", 32).put("downloadBps", 64))
        .put("labels", JSONObject().apply {
            listOf(
                "connect", "disconnect", "disconnected", "connecting", "connected", "disconnecting",
                "connectionFailed", "smartMode", "globalMode", "servers", "plans", "account", "refresh",
                "preferences", "help", "trafficRemaining", "trafficUsed", "upload", "download", "noPlan",
                "noServers", "signIn", "restoringSession", "offline", "retry", "safeMode", "selectServer",
                "currentPlan", "loading",
            ).forEach { put(it, it) }
        })
        .toString()
}
