package com.zolmid.zolnit

import android.app.Application
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentCallbacks
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.zolmid.zolnit.models.WidgetColors
import com.zolmid.zolnit.models.WidgetTheme
import com.zolmid.zolnit.common.Components
import com.zolmid.zolnit.common.GlobalState
import com.zolmid.zolnit.common.QuickAction
import com.zolmid.zolnit.common.intent
import com.zolmid.zolnit.common.quickIntent
import com.zolmid.zolnit.common.toPendingIntent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class StatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context.applicationContext as Application, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context.applicationContext as Application, appWidgetManager, intArrayOf(appWidgetId))
    }

    companion object {
        // SharedPreferences only keeps listeners weakly.
        private var preferenceListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

        fun observe(application: Application) {
            val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
                if (key == "flutter.sharedState") {
                    update(application)
                }
            }
            preferenceListener = listener
            application.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .registerOnSharedPreferenceChangeListener(listener)
            GlobalState.launch(Dispatchers.Main.immediate) {
                ServiceState.runState.collect { update(application) }
            }
            // Before Android 12 the colors for a system theme are picked here, not by the launcher.
            application.registerComponentCallbacks(object : ComponentCallbacks {
                override fun onConfigurationChanged(newConfig: Configuration) = update(application)

                @Deprecated("Deprecated in Java")
                override fun onLowMemory() = Unit
            })
        }

        private fun update(application: Application) {
            val manager = AppWidgetManager.getInstance(application) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(application, StatusWidgetProvider::class.java),
            )
            if (ids.isNotEmpty()) {
                render(application, manager, ids)
            }
        }

        private fun render(
            application: Application,
            manager: AppWidgetManager,
            ids: IntArray,
        ) {
            val runState = ServiceState.runState.value
            val sharedState = application.sharedState
            val profileName = sharedState.currentProfileName.ifBlank { "ZolNit" }
            val palette = palette(application, sharedState.widgetTheme)
            for (id in ids) {
                val layout = layoutFor(manager.getAppWidgetOptions(id))
                manager.updateAppWidget(
                    id,
                    buildViews(application, layout, runState, profileName, palette),
                )
            }
        }

        private fun palette(application: Application, theme: WidgetTheme?): Palette {
            val light = theme?.light ?: resourceColors(application, night = false)
            val dark = theme?.dark ?: resourceColors(application, night = true)
            val night = application.resources.configuration.isNight
            return when (theme?.themeMode) {
                "light" -> Palette(light, light, night)
                "dark" -> Palette(dark, dark, night)
                else -> Palette(light, dark, night)
            }
        }

        private fun resourceColors(application: Application, night: Boolean): WidgetColors {
            val configuration = Configuration(application.resources.configuration).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            }
            val context = application.createConfigurationContext(configuration)
            fun color(id: Int) = context.getColor(id).toLong()
            return WidgetColors(
                background = color(R.color.widget_background),
                onBackground = color(R.color.widget_text_primary),
                onBackgroundVariant = color(R.color.widget_text_secondary),
                primary = color(R.color.shortcut_background),
                onPrimary = color(android.R.color.white),
                trackOff = color(R.color.widget_toggle_track_off),
                thumbOff = color(R.color.widget_toggle_thumb_off),
            )
        }

        private fun layoutFor(options: Bundle): Int {
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
            return when (statusWidgetLayout(width, height)) {
                StatusWidgetLayout.COMPACT -> R.layout.status_widget_compact
                StatusWidgetLayout.ROW -> R.layout.status_widget
                StatusWidgetLayout.SQUARE -> R.layout.status_widget_square
            }
        }

        private fun buildViews(
            application: Application,
            layout: Int,
            runState: RunState,
            profileName: String,
            palette: Palette,
        ): RemoteViews =
            RemoteViews(application.packageName, layout).apply {
                val isOn = runState == RunState.STARTED || runState == RunState.STARTING
                setColor(R.id.background, COLOR_FILTER, palette) { background }
                setColor(R.id.profile_name, TEXT_COLOR, palette) { onBackground }
                setColor(R.id.status, TEXT_COLOR, palette) { onBackgroundVariant }
                setColor(R.id.toggle_border, COLOR_FILTER, palette) {
                    if (isOn) primary else thumbOff
                }
                setColor(R.id.toggle_track, COLOR_FILTER, palette) {
                    if (isOn) primary else trackOff
                }
                setColor(R.id.toggle_thumb_on, COLOR_FILTER, palette) { onPrimary }
                setColor(R.id.toggle_thumb_off, COLOR_FILTER, palette) { thumbOff }
                setViewVisibility(R.id.toggle_thumb_on, if (isOn) View.VISIBLE else View.GONE)
                setViewVisibility(R.id.toggle_thumb_off, if (isOn) View.GONE else View.VISIBLE)
                setTextViewText(R.id.profile_name, profileName)
                setTextViewText(
                    R.id.status,
                    application.getString(
                        when (runState) {
                            RunState.STARTED -> R.string.connected
                            RunState.STARTING -> R.string.start_vpn
                            RunState.STOPPING -> R.string.stop_vpn
                            RunState.STOPPED -> R.string.disconnected
                        },
                    ),
                )
                setOnClickPendingIntent(
                    R.id.root,
                    Components.mainActivity.intent
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        .toPendingIntent,
                )
                setOnClickPendingIntent(R.id.toggle, QuickAction.TOGGLE.quickIntent.toPendingIntent)
            }

        private const val COLOR_FILTER = "setColorFilter"
        private const val TEXT_COLOR = "setTextColor"
    }
}

private class Palette(val light: WidgetColors, val dark: WidgetColors, val night: Boolean)

private val Configuration.isNight: Boolean
    get() = uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

private fun RemoteViews.setColor(
    viewId: Int,
    method: String,
    palette: Palette,
    color: WidgetColors.() -> Long,
) {
    val light = palette.light.color().toInt()
    val dark = palette.dark.color().toInt()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        setColorInt(viewId, method, light, dark)
    } else {
        setInt(viewId, method, if (palette.night) dark else light)
    }
}
