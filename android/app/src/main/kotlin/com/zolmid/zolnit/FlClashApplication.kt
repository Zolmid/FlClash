package com.zolmid.zolnit

import android.app.Application
import android.content.Context
import com.zolmid.zolnit.common.GlobalState

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }

    override fun onCreate() {
        super.onCreate()
        StatusWidgetProvider.observe(this)
    }
}
