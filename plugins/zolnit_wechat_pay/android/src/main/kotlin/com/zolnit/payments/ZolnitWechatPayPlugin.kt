package com.zolnit.payments

import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import com.stripe.android.ApiResultCallback
import com.stripe.android.PaymentIntentResult
import com.stripe.android.Stripe
import com.stripe.android.StripeIntentResult
import com.stripe.android.model.ConfirmPaymentIntentParams
import com.stripe.android.model.PaymentMethodCreateParams
import com.stripe.android.model.PaymentMethodOptionsParams
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class ZolnitWechatPayPlugin : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var stripe: Stripe? = null
    private var pending: MethodChannel.Result? = null
    private val handler = Handler(Looper.getMainLooper())
    private var generation = 0L
    private var timeout: Runnable? = null
    private var expectedIntentId: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "zolnit/stripe_wechat_pay")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "isBusy") {
            result.success(stripe != null || pending != null)
            return
        }
        if (call.method != "confirm") {
            result.notImplemented()
            return
        }
        if (stripe != null || pending != null) {
            result.error("purchase_in_progress", null, null)
            return
        }
        val activity = binding?.activity as? ComponentActivity
        if (activity == null) {
            result.error("sdk_unavailable", null, null)
            return
        }
        val key = call.argument<String>("publishableKey").orEmpty()
        val secret = call.argument<String>("clientSecret").orEmpty()
        val appId = call.argument<String>("appId").orEmpty()
        if (!Regex("^pk_(test|live)_[A-Za-z0-9]+$").matches(key) ||
            !Regex("^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$").matches(secret) ||
            !Regex("^wx[A-Za-z0-9]+$").matches(appId)
        ) {
            result.error("invalid_stripe_action", null, null)
            return
        }
        if (activity.packageManager.getLaunchIntentForPackage("com.tencent.mm") == null) {
            result.error("wallet_unavailable", null, null)
            return
        }
        pending = result
        val owner = ++generation
        expectedIntentId = secret.substringBefore("_secret_")
        timeout = Runnable {
            if (owner == generation) {
                pending?.error("confirmation_pending", null, null)
                pending = null
            }
        }.also { handler.postDelayed(it, 180_000) }
        try {
            val sdk = Stripe(activity.applicationContext, key)
            stripe = sdk
            sdk.confirmPayment(
                activity,
                ConfirmPaymentIntentParams.createWithPaymentMethodCreateParams(
                    PaymentMethodCreateParams.createWeChatPay(),
                    secret,
                    paymentMethodOptions = PaymentMethodOptionsParams.WeChatPay(appId),
                ),
            )
        } catch (_: Exception) {
            finish("sdk_error", owner)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val sdk = stripe ?: return false
        if (!sdk.isPaymentResult(requestCode, data)) return false
        val owner = generation
        val expected = expectedIntentId
        sdk.onPaymentResult(requestCode, data, object : ApiResultCallback<PaymentIntentResult> {
            override fun onSuccess(result: PaymentIntentResult) {
                if (result.intent.id != expected) return
                when (result.outcome) {
                    StripeIntentResult.Outcome.CANCELED -> finish("user_cancelled", owner)
                    StripeIntentResult.Outcome.FAILED -> finish("sdk_error", owner)
                    else -> finish(null, owner)
                }
            }
            override fun onError(e: Exception) { finish("sdk_error", owner) }
        })
        return true
    }

    private fun finish(error: String?, owner: Long = generation) {
        if (owner != generation) return
        generation++
        val result = pending
        pending = null
        stripe = null
        expectedIntentId = null
        timeout?.let(handler::removeCallbacks)
        timeout = null
        if (error == null) result?.success(null) else result?.error(error, null, null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    private fun detach() {
        binding?.removeActivityResultListener(this)
        binding = null
    }
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onDetachedFromActivity() {
        finish("confirmation_pending")
        detach()
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        finish("confirmation_pending")
        detach()
        channel.setMethodCallHandler(null)
    }
}
