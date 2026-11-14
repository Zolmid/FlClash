package com.zolmid.zolnit

import android.app.Application
import android.content.Context
import android.os.Build
import android.webkit.WebView
import com.zolmid.zolnit.common.GlobalState

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        if (Build.VERSION.SDK_INT >= 28 && Application.getProcessName().endsWith(":websession")) {
            WebView.setDataDirectorySuffix("websession")
            return
        }
        GlobalState.init(this)
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT < 28 || !Application.getProcessName().endsWith(":websession")) {
            StatusWidgetProvider.observe(this)
        }
    }
}
