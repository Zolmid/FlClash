package com.zolmid.zolnit.nativeui

import android.content.Context
import android.content.ContextWrapper
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
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
    private var commandSerial = 0L
    private var commandInFlight = false
    private val composeView = ComposeView(context).apply {
        context.findOwner<LifecycleOwner>()?.let { setViewTreeLifecycleOwner(it) }
        context.findOwner<ViewModelStoreOwner>()?.let { setViewTreeViewModelStoreOwner(it) }
        context.findOwner<SavedStateRegistryOwner>()?.let { setViewTreeSavedStateRegistryOwner(it) }
        setContent { NativeHomeApp(snapshot, pendingAction, feedbackKey, ::issueCommand) }
    }

    fun render(next: NativeUiSnapshot) {
        runOnMain {
            if (snapshot?.accountGeneration != next.accountGeneration) {
                commandSerial++
                commandInFlight = false
                pendingAction = null
            }
            if (next.revision > renderedRevision) {
                if (!commandInFlight) pendingAction = null
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
        if (pendingAction != null) return
        if (action == "selectReturnRoute") {
            val route = snapshot?.returnRoute ?: return
            if (!route.enabled || route.options.none { it.id == payload.opt("optionId") }) return
        }
        val generation = snapshot?.accountGeneration ?: return
        val serial = ++commandSerial
        commandInFlight = true
        pendingAction = action
        feedbackKey = null
        onCommand(action, payload) { receipt ->
            runOnMain {
                if (serial != commandSerial || snapshot?.accountGeneration != generation) return@runOnMain
                commandInFlight = false
                if (receipt?.accepted == true) {
                    if (action == "selectReturnRoute") pendingAction = null
                    return@runOnMain
                }
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
        androidx.compose.material3.darkColorScheme(
            primary = Color(0xFFABC7D6), onPrimary = Color(0xFF202C33),
            primaryContainer = Color(0xFF344954), onPrimaryContainer = Color(0xFFE9EFEC),
            background = Color(0xFF151E24), surface = Color(0xFF202C33),
            onSurface = Color(0xFFE9EFEC), onSurfaceVariant = Color(0xFFA8B7BD),
            surfaceVariant = Color(0xFF2B3940),
        )
    } else {
        androidx.compose.material3.lightColorScheme(
            primary = Color(0xFF506A7A), onPrimary = Color(0xFFFFFDF9),
            primaryContainer = Color(0xFFDCE7ED), onPrimaryContainer = Color(0xFF344D5C),
            background = Color(0xFFF3F4EF), surface = Color(0xFFFFFDF9),
            onSurface = Color(0xFF28363E), onSurfaceVariant = Color(0xFF697A83),
            surfaceVariant = Color(0xFFE8EDEB),
        )
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
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
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
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val expanded = maxWidth >= 720.dp
        Column(
            modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = if (expanded) 28.dp else 16.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (expanded) {
                Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    Box(Modifier.weight(1.35f)) { ConnectionCard(snapshot, pendingAction, feedbackKey, onCommand) }
                    Box(Modifier.weight(1f)) { AccountSummary(snapshot) }
                }
            } else {
                ConnectionCard(snapshot, pendingAction, feedbackKey, onCommand)
                AccountSummary(snapshot)
            }
            TrafficSummary(snapshot)
            Surface(shape = panelShape, color = MaterialTheme.colorScheme.surface) {
                Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    ReturnRoutePicker(snapshot, pendingAction == null, onCommand)
                    ModeSelector(snapshot, pendingAction == null && snapshot.canManageSubscription(), onCommand)
                    key(snapshot.accountGeneration) {
                        ServerPicker(snapshot, pendingAction == null && snapshot.canManageSubscription(), onCommand)
                    }
                }
            }
        }
    }
}

private val panelShape = ContinuousShape(28.dp)
private val powerShape = ContinuousShape(38.dp)

private class ContinuousShape(private val corner: Dp) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val radius = minOf(with(density) { corner.toPx() }, size.minDimension / 2)
        return Outline.Generic(Path().apply {
            moveTo(radius, 0f)
            lineTo(size.width - radius, 0f)
            cubicTo(size.width, 0f, size.width, 0f, size.width, radius)
            lineTo(size.width, size.height - radius)
            cubicTo(size.width, size.height, size.width, size.height, size.width - radius, size.height)
            lineTo(radius, size.height)
            cubicTo(0f, size.height, 0f, size.height, 0f, size.height - radius)
            lineTo(0f, radius)
            cubicTo(0f, 0f, 0f, 0f, radius, 0f)
            close()
        })
    }
}

@Composable
private fun MapMotif(modifier: Modifier) {
    val color = MaterialTheme.colorScheme.primary.copy(alpha = 0.09f)
    Canvas(modifier) {
        val mapHeight = minOf(size.height, size.width * 0.5f)
        val mapTop = (size.height - mapHeight) / 2
        val outlines = listOf(
            listOf(.05f to .23f, .14f to .08f, .29f to .12f, .34f to .26f, .23f to .40f, .20f to .54f, .11f to .40f),
            listOf(.24f to .48f, .37f to .54f, .39f to .68f, .31f to .92f, .27f to .73f),
            listOf(.43f to .19f, .55f to .10f, .63f to .18f, .76f to .10f, .95f to .25f, .85f to .42f, .71f to .40f, .65f to .54f, .55f to .39f),
            listOf(.47f to .39f, .60f to .43f, .64f to .61f, .54f to .80f, .48f to .61f),
            listOf(.77f to .68f, .90f to .67f, .95f to .81f, .83f to .87f),
        )
        outlines.forEach { points ->
            val outline = Path().apply {
                points.forEachIndexed { index, point ->
                    if (index == 0) moveTo(point.first * size.width, mapTop + point.second * mapHeight)
                    else lineTo(point.first * size.width, mapTop + point.second * mapHeight)
                }
                close()
            }
            drawPath(outline, color)
        }
        drawOval(color, topLeft = Offset(0f, mapTop), size = Size(size.width, mapHeight),
            style = Stroke(width = 1.dp.toPx()))
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
    Surface(shape = panelShape, color = MaterialTheme.colorScheme.surface) {
        Box(modifier = Modifier.fillMaxWidth().heightIn(min = 390.dp)) {
            MapMotif(Modifier.matchParentSize().padding(16.dp))
            Column(
                modifier = Modifier.fillMaxWidth().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(snapshot.label("connect"), style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(10.dp))
                Button(
                    onClick = { onCommand(if (canDisconnect) "disconnect" else "connect", JSONObject()) },
                    enabled = (canConnect || canDisconnect) && !transitioning && pendingAction == null,
                    shape = if (snapshot.connectionState == "connected") CircleShape else powerShape,
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = if (snapshot.connectionState == "connected") MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.primaryContainer,
                        contentColor = if (snapshot.connectionState == "connected") MaterialTheme.colorScheme.onPrimary
                            else MaterialTheme.colorScheme.onPrimaryContainer,
                    ),
                    modifier = Modifier.size(120.dp)
                        .semantics { contentDescription = if (canDisconnect) snapshot.label("disconnect") else snapshot.label("connect") },
                ) {
                    Icon(Icons.Filled.PowerSettingsNew, contentDescription = null, modifier = Modifier.size(44.dp))
                }
                Text(stateLabel, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Medium)
                Text(if (canDisconnect) snapshot.label("disconnect") else snapshot.label("connect"),
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val selected = snapshot.servers.firstOrNull { it.id == snapshot.selectedServerId }
                Text(selected?.let { server ->
                    "${server.name} · ${server.latencyMs?.let { formatLatency(it, snapshot.locale) } ?: "—"}"
                } ?: "—", style = MaterialTheme.typography.bodyMedium)
                if (snapshot.safeMode) Text(snapshot.label("safeMode"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                SessionNotice(snapshot)
                if (pendingAction != null) Text(snapshot.label("loading"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                feedbackKey?.let { Text(snapshot.label(it), color = MaterialTheme.colorScheme.error) }
            }
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
private fun ReturnRoutePicker(
    snapshot: NativeUiSnapshot,
    idle: Boolean,
    onCommand: (String, JSONObject) -> Unit,
) {
    val route = snapshot.returnRoute ?: return
    val enabled = idle && route.enabled
    var expanded by remember(snapshot.accountGeneration, route) { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(route.title, style = MaterialTheme.typography.titleMedium)
        FilledTonalButton(onClick = { expanded = true }, enabled = enabled, modifier = Modifier.fillMaxWidth()) {
            Text(route.options.firstOrNull { it.id == route.selectedId }?.label ?: "—")
        }
        DropdownMenu(expanded = expanded && enabled, onDismissRequest = { expanded = false }) {
            route.options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label) },
                    enabled = enabled,
                    onClick = {
                        expanded = false
                        onCommand("selectReturnRoute", JSONObject().put("optionId", option.id))
                    },
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
                Text(selected?.name ?: "—")
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
    val used = snapshot.usage.usedBytes
    val total = snapshot.usage.totalBytes
    val remaining = if (used != null && total != null) (total - used).coerceAtLeast(0) else null
    Surface(shape = panelShape, color = Color(0xFF202C33), contentColor = Color(0xFFE9EFEC)) {
        Column(Modifier.fillMaxWidth().heightIn(min = 246.dp).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(snapshot.label("currentPlan"), style = MaterialTheme.typography.labelLarge, color = Color(0xFFA8B7BD))
            Text(snapshot.planName ?: snapshot.label("noPlan"), style = MaterialTheme.typography.headlineSmall)
            Text(snapshot.label("trafficRemaining"), style = MaterialTheme.typography.bodyMedium, color = Color(0xFFA8B7BD))
            Text(remaining?.let { formatBytes(it, snapshot.locale) } ?: "—", style = MaterialTheme.typography.headlineMedium)
            if (used != null && total != null && total > 0) {
                LinearProgressIndicator(progress = { (used.toDouble() / total).coerceIn(0.0, 1.0).toFloat() },
                    modifier = Modifier.fillMaxWidth(), color = Color(0xFFABC7D6), trackColor = Color(0xFF42525B))
            }
            Text("${snapshot.label("trafficUsed")} · ${used?.let { formatBytes(it, snapshot.locale) } ?: "—"} / ${total?.let { formatBytes(it, snapshot.locale) } ?: "—"}",
                style = MaterialTheme.typography.bodyMedium, color = Color(0xFFA8B7BD))
        }
    }
}

@Composable
private fun TrafficSummary(snapshot: NativeUiSnapshot) {
    Surface(shape = panelShape, color = MaterialTheme.colorScheme.surface) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TrafficLine(snapshot.label("upload"), snapshot.traffic.uploadBps, null, snapshot.locale, perSecond = true)
            TrafficLine(snapshot.label("download"), snapshot.traffic.downloadBps, null, snapshot.locale, perSecond = true)
        }
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
        value >= 1_073_741_824L -> value / 1_073_741_824.0 to "GiB"
        value >= 1_048_576L -> value / 1_048_576.0 to "MiB"
        value >= 1024L -> value / 1024.0 to "KiB"
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
