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
        assertEquals(7L, snapshot.revision)
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
        assertEquals(3L, command.getLong("accountGeneration"))
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

    @Test
    fun optionalReturnRouteIsStrictAndPreservesNoSelection() {
        val route = JSONObject("""{"title":"RETURN ROUTE","enabled":true,"options":[{"id":"direct","label":"Direct"},{"id":"hk_lite","label":"Lite"},{"id":"hk_optimized","label":"Optimized"}]}""")
        fun parse(raw: Any) = requireNotNull(NativeUiProtocol.parseSnapshot(JSONObject(snapshotJson()).put("returnRoute", raw).toString()))
        assertNull(requireNotNull(NativeUiProtocol.parseSnapshot(snapshotJson())).returnRoute)
        assertNull(parse(route).returnRoute?.selectedId)
        assertEquals(3, parse(route).returnRoute?.options?.size)
        assertEquals("Lite", parse(route).returnRoute?.options?.get(1)?.label)
        for (selected in listOf("direct", "hk_lite", "hk_optimized")) {
            assertEquals(selected, parse(JSONObject(route.toString()).put("selectedId", selected)).returnRoute?.selectedId)
        }
        for (raw in listOf(
            JSONObject.NULL, false, JSONObject(),
            JSONObject(route.toString()).put("options", org.json.JSONArray()),
            JSONObject(route.toString()).put("enabled", "true"),
            JSONObject(route.toString()).put("title", 1),
            JSONObject(route.toString()).put("selectedId", "DIRECT"),
            JSONObject(route.toString()).put("selectedId", 1),
            JSONObject(route.toString()).put("options", org.json.JSONArray("""[{"id":"direct","label":"A"},{"id":"direct","label":"B"}]""")),
            JSONObject(route.toString()).put("options", org.json.JSONArray("""[{"id":"DIRECT","label":"Alias"}]""")),
        )) assertNull(parse(raw).returnRoute)
        val command = JSONObject(NativeUiProtocol.command("route", 3, "selectReturnRoute", JSONObject().put("optionId", "hk_lite")))
        assertEquals("selectReturnRoute", command.getString("action"))
        assertEquals("hk_lite", command.getJSONObject("payload").getString("optionId"))
    }

    @Test
    fun returnRouteDowngradeKeepsOnlySelectedLiteAndRejectsStaleSelection() {
        val route = JSONObject("""{"title":"RETURN ROUTE","enabled":true,"selectedId":"direct","options":[{"id":"direct","label":"Direct"},{"id":"hk_lite","label":"Lite"},{"id":"hk_optimized","label":"Optimized"}]}""")
        fun parse(value: JSONObject, revision: Int) = requireNotNull(NativeUiProtocol.parseSnapshot(
            JSONObject(snapshotJson()).put("revision", revision).put("returnRoute", value).toString(),
        ))
        val full = parse(route, 7)
        assertEquals(listOf("direct", "hk_lite", "hk_optimized"), full.returnRoute?.options?.map { it.id })
        val lite = JSONObject(route.toString())
            .put("options", org.json.JSONArray("""[{"id":"hk_lite","label":"Lite"}]"""))
            .put("selectedId", "hk_lite")
        val downgraded = parse(lite, 8)
        assertEquals(listOf("hk_lite"), downgraded.returnRoute?.options?.map { it.id })
        assertEquals("hk_lite", downgraded.returnRoute?.selectedId)
        for (removed in listOf("direct", "hk_optimized")) {
            assertNull(parse(JSONObject(lite.toString()).put("selectedId", removed), 9).returnRoute)
        }
        assertEquals(listOf("direct", "hk_lite", "hk_optimized"), full.returnRoute?.options?.map { it.id })
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

    @Test
    fun activationFieldsDefaultToFalseWhenAbsent() {
        val route = JSONObject()
            .put("title", "RETURN ROUTE")
            .put("enabled", true)
            .put("options", org.json.JSONArray("""[{"id":"direct","label":"Direct"},{"id":"hk_lite","label":"Lite"},{"id":"hk_optimized","label":"Optimized"}]"""))
        val snapshot = requireNotNull(NativeUiProtocol.parseSnapshot(JSONObject(snapshotJson()).put("returnRoute", route).toString()))
        assertEquals(false, snapshot.returnRoute?.activationAvailable)
        assertEquals(false, snapshot.returnRoute?.active)
        assertEquals("RETURN ROUTE", snapshot.returnRoute?.activationLabel)
    }

    @Test
    fun activationFieldsParsedWhenPresent() {
        val route = JSONObject()
            .put("title", "RETURN ROUTE")
            .put("activationAvailable", true)
            .put("active", true)
            .put("activationLabel", "Enable China Routing")
            .put("enabled", true)
            .put("options", org.json.JSONArray("""[{"id":"direct","label":"Direct"}]"""))
        val snapshot = requireNotNull(NativeUiProtocol.parseSnapshot(JSONObject(snapshotJson()).put("returnRoute", route).toString()))
        assertEquals(true, snapshot.returnRoute?.activationAvailable)
        assertEquals(true, snapshot.returnRoute?.active)
        assertEquals("Enable China Routing", snapshot.returnRoute?.activationLabel)
    }

    @Test
    fun malformedActivationFieldsFailClosed() {
        val base = JSONObject()
            .put("title", "RETURN ROUTE")
            .put("enabled", true)
            .put("options", org.json.JSONArray("""[{"id":"direct","label":"Direct"}]"""))
        for (raw in listOf(
            JSONObject(base.toString()).put("activationAvailable", "true"),
            JSONObject(base.toString()).put("active", 1),
            JSONObject(base.toString()).put("activationLabel", 42),
            JSONObject(base.toString()).put("activationLabel", ""),
        )) {
            assertNull(
                NativeUiProtocol.parseSnapshot(JSONObject(snapshotJson()).put("returnRoute", raw).toString())?.returnRoute,
            )
        }
    }
}
