package com.zolmid.zolnit

import android.app.Activity
import android.content.ComponentName
import android.content.ServiceConnection
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebResourceError
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import org.json.JSONArray

class WebSessionActivity : Activity() {
    private var web: WebView? = null
    private var pending = true
    private val handler = Handler(Looper.getMainLooper()) { message ->
        when (message.what) {
            WebSessionService.GRANT -> {
                val code = message.data.getString("code")
                val destination = message.data.getString("destination")
                if (code != null && destination != null && Regex("^[A-Za-z0-9_-]{43}$").matches(code) && destination in destinations) {
                    showWeb(code, destination)
                } else finish()
            }
            WebSessionService.CLOSE -> finish()
        }
        true
    }
    private val incoming = Messenger(handler)
    private var bound = false
    private var service: Messenger? = null
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            if (isFinishing || binder == null) return
            val ready = Message.obtain(null, WebSessionService.READY).apply {
                data = Bundle().apply { putString("id", intent.getStringExtra("id")) }
                replyTo = incoming
            }
            service = Messenger(binder)
            try { service?.send(ready) } catch (_: Exception) { finish() }
        }
        override fun onServiceDisconnected(name: ComponentName?) { finish() }
    }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        if (intent.getStringExtra("id") == null) return finish()
        bound = bindService(Intent(this, WebSessionService::class.java), connection, BIND_AUTO_CREATE)
        if (!bound) return finish()
        handler.postDelayed({ if (pending) { report(WebSessionService.FAILED); finish() } }, 15000)
    }

    private fun report(status: Int) {
        val message = Message.obtain(null, status).apply {
            data = Bundle().apply { putString("id", intent.getStringExtra("id")) }
        }
        try { service?.send(message) } catch (_: Exception) {}
    }

    private fun showWeb(code: String, destination: String) {
        CookieManager.getInstance().removeAllCookies {
            if (isFinishing || isDestroyed) return@removeAllCookies
            WebStorage.getInstance().deleteAllData()
            val view = WebView(this)
            web = view
            view.settings.javaScriptEnabled = true
            view.settings.domStorageEnabled = true
            view.settings.allowFileAccess = false
            view.settings.allowContentAccess = false
            view.settings.javaScriptCanOpenWindowsAutomatically = false
            view.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val url = request.url
                    if (pending && request.isForMainFrame && url.toString() != landing) {
                        pending = false
                        report(WebSessionService.FAILED)
                        finish()
                        return true
                    }
                    return url.scheme != "https" || url.host != "link.zolmid.com" || url.port !in listOf(-1, 443) || url.userInfo != null
                }
                override fun onPageFinished(view: WebView, url: String) {
                    if (!pending || url != landing || view.url != landing) return
                    val args = JSONArray().put(code).put(destination).toString()
                    view.evaluateJavascript("(function(){if(window.top===window && window.location.href===" + org.json.JSONObject.quote(landing) + " && window.ZolNitWebSession && typeof window.ZolNitWebSession.accept==='function'){window.ZolNitWebSession.accept(...$args);return true}return false})()") { value ->
                        if (!pending) return@evaluateJavascript
                        pending = false
                        report(if (value == "true") WebSessionService.DELIVERED else WebSessionService.FAILED)
                        if (value != "true") finish()
                    }
                }
                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (pending && request.isForMainFrame) { pending = false; report(WebSessionService.FAILED); finish() }
                }
            }
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.WHITE)
                addView(Button(context).apply { text = "×"; setOnClickListener { finish() } })
                addView(view, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
            }
            setContentView(layout)
            view.loadUrl(landing)
        }
    }

    override fun onDestroy() {
        if (pending) { pending = false; report(WebSessionService.FAILED) }
        handler.removeCallbacksAndMessages(null)
        web?.stopLoading()
        web?.destroy()
        WebStorage.getInstance().deleteAllData()
        CookieManager.getInstance().removeAllCookies {
            report(WebSessionService.CLOSED)
            if (bound) { unbindService(connection); bound = false }
        }
        super.onDestroy()
    }

    companion object {
        const val landing = "https://link.zolmid.com/theme/ZolNit/app-login.html"
        val destinations = setOf("/", "/#/dashboard", "/theme/ZolNit/downloads.html")
    }
}
