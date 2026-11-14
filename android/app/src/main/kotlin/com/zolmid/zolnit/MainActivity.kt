package com.zolmid.zolnit

import android.content.Intent
import android.os.Build
import com.zolmid.zolnit.plugins.AppPlugin
import com.zolmid.zolnit.plugins.BatteryPlugin
import com.zolmid.zolnit.plugins.ServicePlugin
import com.zolmid.zolnit.plugins.TilePlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(BatteryPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zolmid.zolnit/web_session")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val code = call.argument<String>("code")
                        val destination = call.argument<String>("destination")
                        if (Build.VERSION.SDK_INT < 28 || code == null || !Regex("^[A-Za-z0-9_-]{43}$").matches(code) || destination !in WebSessionActivity.destinations) {
                            result.success(false)
                        } else {
                            if (WebSessionService.activeId != null || WebSessionService.pending != null) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val id = UUID.randomUUID().toString()
                            WebSessionService.activeId = id
                            WebSessionService.pending = WebSessionService.Companion.Pending(id, code, destination!!, result)
                            try {
                                startActivity(Intent(this, WebSessionActivity::class.java).putExtra("id", id))
                            } catch (_: Exception) {
                                WebSessionService.pending = null
                                WebSessionService.activeId = null
                                result.success(false)
                            }
                        }
                    }
                    "close" -> WebSessionService.close(result)
                    else -> result.notImplemented()
                }
            }
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        WebSessionService.close()
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}
