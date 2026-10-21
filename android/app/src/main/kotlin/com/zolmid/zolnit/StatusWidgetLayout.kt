package com.zolmid.zolnit

internal enum class StatusWidgetLayout {
    COMPACT,
    ROW,
    SQUARE,
}

internal fun statusWidgetLayout(width: Int, height: Int): StatusWidgetLayout = when {
    width <= 0 || height <= 0 -> StatusWidgetLayout.SQUARE
    height < 160 && width < 190 -> StatusWidgetLayout.COMPACT
    height < 160 -> StatusWidgetLayout.ROW
    else -> StatusWidgetLayout.SQUARE
}
