package com.zolmid.zolnit

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import io.flutter.plugin.common.MethodChannel

class WebSessionService : Service() {
    private val incoming = Messenger(Handler(Looper.getMainLooper()) { message ->
        if (message.what == READY) {
            val request = pending
            val id = message.data.getString("id")
            if (request != null && request.id == id && message.replyTo != null) {
                receiver = message.replyTo
                activeId = id
                val grant = Message.obtain(null, GRANT).apply {
                    data = Bundle().apply {
                        putString("code", request.code)
                        putString("destination", request.destination)
                    }
                }
                try { receiver?.send(grant) }
                catch (_: Exception) { receiver = null; pending = null; request.result.success(false) }
            } else {
                if (closing && id == activeId) receiver = message.replyTo
                try { message.replyTo?.send(Message.obtain(null, CLOSE)) } catch (_: Exception) {}
            }
        } else if (message.what == CLOSED && message.data.getString("id") == activeId) {
            receiver = null
            activeId = null
            closing = false
            val waiting = closers.toList()
            closers.clear()
            waiting.forEach { it.success(true) }
        } else if (message.what == DELIVERED || message.what == FAILED) {
            val request = pending
            if (request != null && request.id == message.data.getString("id")) {
                pending = null
                request.result.success(message.what == DELIVERED)
            }
        }
        true
    })

    override fun onBind(intent: Intent?): IBinder = incoming.binder

    companion object {
        const val READY = 1
        const val GRANT = 2
        const val CLOSE = 3
        const val DELIVERED = 4
        const val FAILED = 5
        const val CLOSED = 6
        data class Pending(val id: String, val code: String, val destination: String, val result: MethodChannel.Result)
        var pending: Pending? = null
        var receiver: Messenger? = null
        var activeId: String? = null
        var closing = false
        val closers = mutableListOf<MethodChannel.Result>()
        fun close(result: MethodChannel.Result? = null) {
            pending?.result?.success(false)
            pending = null
            if (activeId == null) { result?.success(true); return }
            if (result != null) closers.add(result)
            if (closing) return
            closing = true
            try { receiver?.send(Message.obtain(null, CLOSE)) } catch (_: Exception) {
                receiver = null
                activeId = null
                closing = false
                val waiting = closers.toList()
                closers.clear()
                waiting.forEach { it.success(false) }
            }
        }
    }
}
