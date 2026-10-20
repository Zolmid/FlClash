package com.follow.clash.models

import com.follow.clash.service.models.VpnOptions
import com.google.gson.annotations.SerializedName

data class SharedState(
    val startTip: String = "Starting VPN...",
    val stopTip: String = "Stopping VPN...",
    val localNetworkTip: String =
        "Local network permission denied: using the gvisor stack, LAN is unreachable.",
    val currentProfileName: String = "FlClash",
    val stopText: String = "Stop",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
    val networkSpeedNotification: Boolean = false,
    val collapseQuickSettingsPanel: Boolean = true,
    val showQuickSettingsProfileName: Boolean = true,
    val vpnOptions: VpnOptions? = null,
    val setupParams: SetupParams? = null,
    val widgetTheme: WidgetTheme? = null,
)

data class WidgetTheme(
    val themeMode: String = "system",
    val light: WidgetColors,
    val dark: WidgetColors,
)

data class WidgetColors(
    val background: Long,
    val onBackground: Long,
    val onBackgroundVariant: Long,
    val primary: Long,
    val onPrimary: Long,
    val trackOff: Long,
    val thumbOff: Long,
)

data class SetupParams(
    @SerializedName("test-url")
    val testUrl: String,
    @SerializedName("selected-map")
    val selectedMap: Map<String, String>,
    @SerializedName("skip-cert-verify")
    val skipCertVerify: Boolean = false,
)
