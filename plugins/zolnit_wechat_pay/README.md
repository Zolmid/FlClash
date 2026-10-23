# ZolNit Android Stripe WeChatPay bridge

Android-only Flutter plugin. Calls the Stripe Android SDK with its official WeChatPay authenticator module
and Tencent SDK; it does not open a generic wallet URL or treat a callback as verified payment.

The host must use FlutterFragmentActivity/AppCompat. `isBusy` spans a pending native flow; confirmation
requests are single-flight. A 180-second response timeout reports `confirmation_pending` to Dart while
retaining native ownership until its result or final detach, preventing overlapping SDK requests.
Activity-result callbacks only consume Stripe results, match the PaymentIntent and retain an operation
generation. Detach removes listeners and pending handlers. Native results never update Xboard entitlements.

Pinned SDK versions must match Flutter Stripe 14.2.0: Stripe Android/WeChatPay 23.22.0 and Tencent 6.7.0.
See https://github.com/stripe/stripe-android/blob/v23.22.0/wechatpay/README.md for integration requirements
and the limitation that Stripe test-mode WeChat parameters do not authorize a real wallet payment.

`flutter test` verifies the Dart channel contract. It does not compile the Kotlin implementation or prove
wallet launch, configuration-change handling or payment on a physical device; native build/device checks
remain separate.
