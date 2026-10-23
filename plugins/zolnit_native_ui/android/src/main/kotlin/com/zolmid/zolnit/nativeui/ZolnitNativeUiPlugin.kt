package com.zolmid.zolnit.nativeui

import android.content.Context
import androidx.annotation.VisibleForTesting
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.UUID

class ZolnitNativeUiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private val views = mutableSetOf<NativeHomePlatformView>()
    private val snapshots = NativeUiSnapshotGate()
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, NativeHomeViewFactory())
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "publishSnapshot" -> {
                val accepted = (call.arguments as? String)?.let(NativeUiProtocol::parseSnapshot)?.let(::acceptSnapshot) ?: false
                if (accepted) result.success(null) else result.error("invalid_snapshot", "Unsupported native UI snapshot", null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        views.toList().forEach(NativeHomePlatformView::dispose)
        views.clear()
        snapshots.clear()
    }

    @VisibleForTesting
    internal fun acceptSnapshot(next: NativeUiSnapshot): Boolean {
        if (!snapshots.accept(next)) return false
        views.toList().forEach { it.render(next) }
        return true
    }

    private fun createView(context: Context): NativeHomePlatformView {
        lateinit var view: NativeHomePlatformView
        view = NativeHomePlatformView(context, ::dispatchCommand) { views.remove(view) }
        views += view
        snapshots.current?.let(view::render) ?: requestSnapshot(view)
        return view
    }

    private fun requestSnapshot(view: NativeHomePlatformView) {
        channel?.invokeMethod("getSnapshot", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                (result as? String)?.let(NativeUiProtocol::parseSnapshot)?.let(::acceptSnapshot)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
            override fun notImplemented() = Unit
        })
    }

    private fun dispatchCommand(
        action: String,
        payload: org.json.JSONObject,
        onReceipt: (NativeUiReceipt?) -> Unit,
    ) {
        val current = snapshots.current ?: run {
            onReceipt(null)
            return
        }
        val id = UUID.randomUUID().toString()
        val command = NativeUiProtocol.command(id, current.accountGeneration, action, payload)
        val methodChannel = channel ?: run {
            onReceipt(null)
            return
        }
        methodChannel.invokeMethod("performCommand", command, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val receipt = (result as? String)?.let(NativeUiProtocol::parseReceipt)?.takeIf { it.id == id }
                onReceipt(receipt)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = onReceipt(null)
            override fun notImplemented() = onReceipt(null)
        })
    }

    private inner class NativeHomeViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView = createView(context)
    }

    companion object {
        const val CHANNEL_NAME = "com.zolmid.zolnit/native-ui"
        const val VIEW_TYPE = "com.zolmid.zolnit/native-home"
    }
}
