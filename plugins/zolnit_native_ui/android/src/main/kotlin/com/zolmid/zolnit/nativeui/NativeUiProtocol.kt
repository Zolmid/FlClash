package com.zolmid.zolnit.nativeui

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

internal const val protocolSchemaVersion = 1

internal data class NativeUiSnapshot(
    val revision: Long,
    val accountGeneration: Long,
    val locale: String,
    val textDirection: String,
    val safeMode: Boolean,
    val sessionStatus: String,
    val connectionState: String,
    val destination: String,
    val mode: String,
    val selectedServerId: String?,
    val servers: List<NativeUiServer>,
    val planName: String?,
    val planExpiresAt: Long?,
    val usage: NativeUiUsage,
    val traffic: NativeUiTraffic,
    val labels: Map<String, String>,
    val returnRoute: NativeUiReturnRoute? = null,
)

internal data class NativeUiReturnRoute(
    val title: String,
    val selectedId: String?,
    val enabled: Boolean,
    val options: List<NativeUiReturnRouteOption>,
)

internal data class NativeUiReturnRouteOption(val id: String, val label: String)

internal data class NativeUiServer(
    val id: String,
    val name: String,
    val available: Boolean,
    val latencyMs: Long?,
)

internal data class NativeUiUsage(val usedBytes: Long?, val totalBytes: Long?)

internal data class NativeUiTraffic(val uploadBps: Long?, val downloadBps: Long?)

internal data class NativeUiReceipt(val id: String, val accepted: Boolean, val errorCode: String?)

internal class NativeUiSnapshotGate {
    var current: NativeUiSnapshot? = null
        private set

    fun accept(next: NativeUiSnapshot): Boolean {
        if (current?.revision?.let { next.revision <= it } == true) return false
        current = next
        return true
    }

    fun clear() {
        current = null
    }
}

internal object NativeUiProtocol {
    private val sessionStatuses = setOf("restoring", "signedOut", "signedIn", "offline", "expired")
    private val connectionStates = setOf("disconnected", "connecting", "connected", "disconnecting", "failed")
    private val destinations = setOf("connect", "servers", "plans", "account")
    private val modes = setOf("rule", "global")
    private val textDirections = setOf("ltr", "rtl")

    fun parseSnapshot(raw: String): NativeUiSnapshot? = try {
        val json = JSONObject(raw)
        if (json.requiredInt("schemaVersion") != protocolSchemaVersion) return null
        val revision = json.requiredLong("revision")
        val accountGeneration = json.requiredLong("accountGeneration")
        val locale = json.requiredString("locale")
        if (locale.isBlank()) return null
        val textDirection = json.requiredString("textDirection").takeIf(textDirections::contains) ?: return null
        val sessionStatus = json.requiredString("sessionStatus").takeIf(sessionStatuses::contains) ?: return null
        val connectionState = json.requiredString("connectionState").takeIf(connectionStates::contains) ?: return null
        val destination = json.requiredString("destination").takeIf(destinations::contains) ?: return null
        val mode = json.requiredString("mode").takeIf(modes::contains) ?: return null
        val labelsJson = json.requiredObject("labels")
        val labels = buildMap {
            labelsJson.keys().forEach { key ->
                val value = labelsJson.opt(key)
                if (value is String) put(key, value)
            }
        }
        if (!requiredLabels.all(labels::containsKey)) return null
        NativeUiSnapshot(
            revision = revision,
            accountGeneration = accountGeneration,
            locale = locale,
            textDirection = textDirection,
            safeMode = json.requiredBoolean("safeMode"),
            sessionStatus = sessionStatus,
            connectionState = connectionState,
            destination = destination,
            mode = mode,
            selectedServerId = json.optionalString("selectedServerId"),
            servers = json.requiredArray("servers").parseServers(),
            planName = json.optionalString("planName"),
            planExpiresAt = if (json.isNull("planExpiresAt")) null else json.requiredLong("planExpiresAt"),
            usage = json.requiredObject("usage").parseUsage(),
            traffic = json.requiredObject("traffic").parseTraffic(),
            labels = labels,
            returnRoute = parseReturnRoute(json.opt("returnRoute")),
        )
    } catch (_: JSONException) {
        null
    } catch (_: IllegalArgumentException) {
        null
    }

    private fun parseReturnRoute(raw: Any?): NativeUiReturnRoute? {
        val value = raw as? JSONObject ?: return null
        if (value.keys().asSequence().any { it !in setOf("title", "selectedId", "enabled", "options") }) return null
        val title = value.opt("title") as? String ?: return null
        val enabled = value.opt("enabled") as? Boolean ?: return null
        val options = value.opt("options") as? JSONArray ?: return null
        if (title.isEmpty() || title.length > 4096 || options.length() > 3) return null
        val parsed = mutableListOf<NativeUiReturnRouteOption>()
        for (index in 0 until options.length()) {
            val option = options.opt(index) as? JSONObject ?: return null
            if (option.keys().asSequence().any { it !in setOf("id", "label") }) return null
            val id = option.opt("id") as? String ?: return null
            val label = option.opt("label") as? String ?: return null
            if (id !in setOf("direct", "hk_lite", "hk_optimized") || parsed.any { it.id == id } || label.isEmpty() || label.length > 4096) return null
            parsed.add(NativeUiReturnRouteOption(id, label))
        }
        val selected = if (!value.has("selectedId") || value.isNull("selectedId")) null
            else value.opt("selectedId") as? String ?: return null
        if (selected != null && parsed.none { it.id == selected }) return null
        return NativeUiReturnRoute(title, selected, enabled, parsed)
    }

    fun command(
        id: String,
        accountGeneration: Long,
        action: String,
        payload: JSONObject = JSONObject(),
    ): String = JSONObject()
        .put("schemaVersion", protocolSchemaVersion)
        .put("id", id)
        .put("accountGeneration", accountGeneration)
        .put("action", action)
        .put("payload", payload)
        .toString()

    fun parseReceipt(raw: String): NativeUiReceipt? = try {
        val json = JSONObject(raw)
        if (json.requiredInt("schemaVersion") != protocolSchemaVersion) return null
        val id = json.requiredString("id")
        val accepted = json.requiredBoolean("accepted")
        val errorCode = json.optionalString("errorCode")
        if (accepted && errorCode != null) return null
        NativeUiReceipt(id, accepted, errorCode)
    } catch (_: JSONException) {
        null
    } catch (_: IllegalArgumentException) {
        null
    }

    private fun JSONArray.parseServers(): List<NativeUiServer> = buildList {
        for (index in 0 until length()) {
            val server = getJSONObject(index)
            val id = server.requiredString("id")
            val name = server.requiredString("name")
            val latency = if (server.isNull("latencyMs")) null else server.requiredLong("latencyMs")
            add(NativeUiServer(id, name, server.requiredBoolean("available"), latency))
        }
    }

    private fun JSONObject.parseUsage() = NativeUiUsage(
        usedBytes = if (isNull("usedBytes")) null else requiredLong("usedBytes"),
        totalBytes = if (isNull("totalBytes")) null else requiredLong("totalBytes"),
    )

    private fun JSONObject.parseTraffic() = NativeUiTraffic(
        uploadBps = if (isNull("uploadBps")) null else requiredLong("uploadBps"),
        downloadBps = if (isNull("downloadBps")) null else requiredLong("downloadBps"),
    )

    private fun JSONObject.requiredObject(name: String): JSONObject = getJSONObject(name)
    private fun JSONObject.requiredArray(name: String): JSONArray = getJSONArray(name)
    private fun JSONObject.requiredString(name: String): String = getString(name)
    private fun JSONObject.requiredBoolean(name: String): Boolean = getBoolean(name)
    private fun JSONObject.requiredInt(name: String): Int = getInt(name).also { require(it >= 0) }
    private fun JSONObject.requiredLong(name: String): Long = getLong(name).also { require(it >= 0) }
    private fun JSONObject.optionalString(name: String): String? = if (isNull(name)) null else getString(name)

    private val requiredLabels = setOf(
        "connect", "disconnect", "disconnected", "connecting", "connected", "disconnecting",
        "connectionFailed", "smartMode", "globalMode", "servers", "plans", "account", "refresh",
        "preferences", "help", "trafficRemaining", "trafficUsed", "upload", "download", "noPlan",
        "noServers", "signIn", "restoringSession", "offline", "retry", "safeMode", "selectServer",
        "currentPlan", "loading",
    )
}
