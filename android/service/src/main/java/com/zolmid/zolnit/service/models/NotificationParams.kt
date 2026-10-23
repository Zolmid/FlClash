package com.zolmid.zolnit.service.models

data class NotificationParams(
    val title: String = "ZolNit",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
    val networkSpeedNotification: Boolean = false,
)
