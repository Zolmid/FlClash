package com.zolmid.zolnit.nativeui

import android.content.Context
import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

internal class NativeHomePlatformView(
    context: Context,
    private val onCommand: (String, JSONObject, (NativeUiReceipt?) -> Unit) -> Unit,
    private val onDispose: () -> Unit,
) : PlatformView {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var snapshot by mutableStateOf<NativeUiSnapshot?>(null)
    private var pendingAction by mutableStateOf<String?>(null)
    private var feedbackKey by mutableStateOf<String?>(null)
    private var renderedRevision = -1L
    private val composeView = ComposeView(context).apply {
        context.findOwner<LifecycleOwner>()?.let { setViewTreeLifecycleOwner(it) }
        context.findOwner<ViewModelStoreOwner>()?.let { setViewTreeViewModelStoreOwner(it) }
        context.findOwner<SavedStateRegistryOwner>()?.let { setViewTreeSavedStateRegistryOwner(it) }
        setContent { NativeHomeApp(snapshot, pendingAction, feedbackKey, ::issueCommand) }
    }

    fun render(next: NativeUiSnapshot) {
        runOnMain {
            if (next.revision > renderedRevision) {
                pendingAction = null
                feedbackKey = null
            }
            renderedRevision = next.revision
            snapshot = next
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        composeView.disposeComposition()
        composeView.setViewTreeLifecycleOwner(null)
        composeView.setViewTreeViewModelStoreOwner(null)
        composeView.setViewTreeSavedStateRegistryOwner(null)
        onDispose()
    }

    private fun issueCommand(action: String, payload: JSONObject) {
        pendingAction = action
        feedbackKey = null
        onCommand(action, payload) { receipt ->
            runOnMain {
                if (receipt?.accepted == true) return@runOnMain
                pendingAction = null
                feedbackKey = when (receipt?.errorCode) {
                    "unauthenticated", "stale_account" -> "signIn"
                    "unavailable" -> "offline"
                    "safe_mode" -> "safeMode"
                    else -> "retry"
                }
            }
        }
    }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }
}

private inline fun <reified T> Context.findOwner(): T? {
    var current: Context? = this
    while (current != null) {
        if (current is T) return current
        current = (current as? ContextWrapper)?.baseContext
    }
    return null
}

@Composable
private fun NativeHomeApp(
    snapshot: NativeUiSnapshot?,
    pendingAction: String?,
    feedbackKey: String?,
    onCommand: (String, JSONObject) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) {
        androidx.compose.material3.darkColorScheme(primary = androidx.compose.ui.graphics.Color(0xFFC8B6D8))
    } else {
        androidx.compose.material3.lightColorScheme(primary = androidx.compose.ui.graphics.Color(0xFF70567E))
    }
    MaterialTheme(colorScheme = scheme) {
        Surface(modifier = Modifier.fillMaxSize()) {
            if (snapshot == null) LoadingScreen()
            else CompositionLocalProvider(
                androidx.compose.ui.platform.LocalLayoutDirection provides
                    if (snapshot.textDirection == "rtl") LayoutDirection.Rtl else LayoutDirection.Ltr,
            ) {
                NativeHomeScaffold(snapshot, pendingAction, feedbackKey, onCommand)
            }
        }
    }
}

@Composable
private fun LoadingScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        androidx.compose.material3.CircularProgressIndicator()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NativeHomeScaffold(
    snapshot: NativeUiSnapshot,
    pendingAction: String?,
    feedbackKey: String?,
    onCommand: (String, JSONObject) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Image(
                        painter = painterResource(if (isSystemInDarkTheme()) R.drawable.zolnit_horizontal_dark else R.drawable.zolnit_horizontal_light),
                        contentDescription = null,
                        modifier = Modifier
                            .width(132.dp)
                            .height(32.dp),
                    )
                },
            )
        },
        bottomBar = {
            NavigationBar {
                Destination.values().forEach { item ->
                    NavigationBarItem(
                        selected = snapshot.destination == item.value,
                        onClick = { onCommand("navigate", JSONObject().put("destination", item.value)) },
                        icon = { Icon(item.icon, contentDescription = null) },
                        label = { Text(snapshot.label(item.labelKey)) },
                    )
                }
            }
        },
    ) { padding ->
        when (snapshot.destination) {
            "connect" -> ConnectScreen(snapshot, pendingAction, feedbackKey, onCommand, Modifier.padding(padding))
            else -> RedirectScreen(snapshot, onCommand, Modifier.padding(padding))
        }
    }
}

@Composable
private fun ConnectScreen(
    snapshot: NativeUiSnapshot,
    pendingAction: String?,
    feedbackKey: String?,
    onCommand: (String, JSONObject) -> Unit,
    modifier: Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Spacer(Modifier.height(8.dp))
        ConnectionCard(snapshot, pendingAction, feedbackKey, onCommand)
        if (pendingAction != null) Text(snapshot.label("loading"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        ModeSelector(snapshot, pendingAction == null && snapshot.canManageSubscription(), onCommand)
        key(snapshot.accountGeneration) {
            ServerPicker(snapshot, pendingAction == null && snapshot.canManageSubscription(), onCommand)
        }
        AccountSummary(snapshot)
        TrafficSummary(snapshot)
    }
}

@Composable
private fun ConnectionCard(
    snapshot: NativeUiSnapshot,
    pendingAction: String?,
    feedbackKey: String?,
    onCommand: (String, JSONObject) -> Unit,
) {
    val stateLabel = when (snapshot.connectionState) {
        "connecting" -> snapshot.label("connecting")
        "connected" -> snapshot.label("connected")
        "disconnecting" -> snapshot.label("disconnecting")
        "failed" -> snapshot.label("connectionFailed")
        else -> snapshot.label("disconnected")
    }
    val transitioning = snapshot.connectionState == "connecting" || snapshot.connectionState == "disconnecting"
    val canConnect = !snapshot.safeMode && snapshot.sessionStatus == "signedIn" &&
        (snapshot.connectionState == "disconnected" || snapshot.connectionState == "failed")
    val canDisconnect = !snapshot.safeMode && snapshot.connectionState == "connected"
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stateLabel, style = MaterialTheme.typography.headlineMedium)
        if (snapshot.safeMode) Text(snapshot.label("safeMode"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        SessionNotice(snapshot)
        feedbackKey?.let { Text(snapshot.label(it), color = MaterialTheme.colorScheme.error) }
        Button(
            onClick = {
                onCommand(if (canDisconnect) "disconnect" else "connect", JSONObject())
            },
            enabled = (canConnect || canDisconnect) && !transitioning && pendingAction == null,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .semantics { contentDescription = if (canDisconnect) snapshot.label("disconnect") else snapshot.label("connect") },
        ) {
            Text(if (canDisconnect) snapshot.label("disconnect") else snapshot.label("connect"))
        }
    }
}

@Composable
private fun SessionNotice(snapshot: NativeUiSnapshot) {
    val label = when (snapshot.sessionStatus) {
        "restoring" -> snapshot.label("restoringSession")
        "signedOut", "expired" -> snapshot.label("signIn")
        "offline" -> snapshot.label("offline")
        else -> ""
    }
    if (label.isNotEmpty()) Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun ModeSelector(
    snapshot: NativeUiSnapshot,
    enabled: Boolean,
    onCommand: (String, JSONObject) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            listOf("rule" to "smartMode", "global" to "globalMode").forEachIndexed { index, (mode, label) ->
                SegmentedButton(
                    selected = snapshot.mode == mode,
                    onClick = { onCommand("setMode", JSONObject().put("mode", mode)) },
                    enabled = enabled,
                    shape = SegmentedButtonDefaults.itemShape(index, 2),
                    label = { Text(snapshot.label(label)) },
                )
            }
        }
    }
}

@Composable
private fun ServerPicker(
    snapshot: NativeUiSnapshot,
    enabled: Boolean,
    onCommand: (String, JSONObject) -> Unit,
) {
    var expanded by remember(snapshot.accountGeneration) { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(snapshot.label("selectServer"), style = MaterialTheme.typography.titleMedium)
        if (snapshot.servers.isEmpty()) {
            Text(snapshot.label("noServers"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            val selected = snapshot.servers.firstOrNull { it.id == snapshot.selectedServerId }
            FilledTonalButton(
                onClick = { expanded = true },
                enabled = enabled,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(selected?.name.orEmpty())
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                snapshot.servers.forEach { server ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                if (server.latencyMs == null) server.name
                                else "${server.name} · ${formatLatency(server.latencyMs, snapshot.locale)}",
                            )
                        },
                        enabled = enabled && server.available,
                        onClick = {
                            expanded = false
                            onCommand("selectServer", JSONObject().put("serverId", server.id))
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun AccountSummary(snapshot: NativeUiSnapshot) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(snapshot.label("currentPlan"), style = MaterialTheme.typography.titleMedium)
        Text(snapshot.planName ?: snapshot.label("noPlan"), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TrafficSummary(snapshot: NativeUiSnapshot) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        HorizontalDivider()
        TrafficLine(snapshot.label("trafficUsed"), snapshot.usage.usedBytes, snapshot.usage.totalBytes, snapshot.locale)
        TrafficLine(snapshot.label("upload"), snapshot.traffic.uploadBps, null, snapshot.locale, perSecond = true)
        TrafficLine(snapshot.label("download"), snapshot.traffic.downloadBps, null, snapshot.locale, perSecond = true)
    }
}

@Composable
private fun TrafficLine(
    label: String,
    first: Long?,
    second: Long?,
    locale: String,
    perSecond: Boolean = false,
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        val display = if (first == null) "—" else if (second == null) formatBytes(first, locale, perSecond) else {
            "${formatBytes(first, locale)} / ${formatBytes(second, locale)}"
        }
        Text(display, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun RedirectScreen(snapshot: NativeUiSnapshot, onCommand: (String, JSONObject) -> Unit, modifier: Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(snapshot.label(Destination.fromValue(snapshot.destination).labelKey), style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))
        FilledTonalButton(onClick = { onCommand("navigate", JSONObject().put("destination", "connect")) }) {
            Text(snapshot.label("connect"))
        }
    }
}

private fun NativeUiSnapshot.label(key: String): String = labels[key].orEmpty()

private fun NativeUiSnapshot.canManageSubscription(): Boolean =
    !safeMode && sessionStatus == "signedIn" && connectionState !in setOf("connecting", "disconnecting")

private fun formatBytes(value: Long, localeCode: String, perSecond: Boolean = false): String {
    val (amount, unit) = when {
        value >= 1_073_741_824L -> value / 1_073_741_824.0 to "GB"
        value >= 1_048_576L -> value / 1_048_576.0 to "MB"
        value >= 1024L -> value / 1024.0 to "KB"
        else -> value.toDouble() to "B"
    }
    val formatter = NumberFormat.getNumberInstance(localeCode.toLocale()).apply { maximumFractionDigits = 1 }
    return formatter.format(amount) + " " + unit + if (perSecond) "/s" else ""
}

private fun formatLatency(value: Long, localeCode: String): String =
    NumberFormat.getIntegerInstance(localeCode.toLocale()).format(value) + " ms"

private fun String.toLocale(): Locale = Locale.forLanguageTag(replace('_', '-')).takeIf { it.language.isNotBlank() } ?: Locale.getDefault()

private enum class Destination(val value: String, val labelKey: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    CONNECT("connect", "connect", Icons.Filled.Home),
    SERVERS("servers", "servers", Icons.Filled.Dns),
    PLANS("plans", "plans", Icons.Filled.Payments),
    ACCOUNT("account", "account", Icons.Filled.AccountCircle),
    ;

    companion object {
        fun fromValue(value: String): Destination = entries.firstOrNull { it.value == value } ?: CONNECT
    }
}
