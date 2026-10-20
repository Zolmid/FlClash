import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_wechat_pay/zolnit_wechat_pay.dart';

import 'api.dart';
import 'checkout.dart';

class NativeCheckoutPlatform implements CheckoutPlatform {
  NativeCheckoutPlatform({required this.merchantName});

  final String merchantName;
  static bool _confirming = false;

  @override
  Future<bool> open(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) throw const ClientFailure('superseded');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const ClientFailure('sdk_unavailable');
    }
    if (_confirming) throw const ClientFailure('purchase_in_progress');
    _confirming = true;
    try {
      if (await ZolnitWechatPay().isBusy()) {
        throw const ClientFailure('purchase_in_progress');
      }
      if (!isCurrent()) throw const ClientFailure('superseded');
      if (action.wallet == StripeWallet.wechatPay) {
        await ZolnitWechatPay().confirm(
          publishableKey: action.publishableKey,
          clientSecret: action.clientSecret,
          appId: action.wechatAppId!,
        );
        return;
      }
      Stripe.publishableKey = action.publishableKey;
      Stripe.urlScheme = action.returnUri.scheme;
      Stripe.setReturnUrlSchemeOnAndroid = true;
      await Stripe.instance.applySettings();
      if (!isCurrent()) throw const ClientFailure('superseded');
      if (action.wallet == StripeWallet.alipay) {
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: action.clientSecret,
          data: const PaymentMethodParams.alipay(
            paymentMethodData: PaymentMethodData(),
          ),
        );
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: merchantName,
            paymentIntentClientSecret: action.clientSecret,
            returnURL: action.returnUri.toString(),
          ),
        );
        if (!isCurrent()) throw const ClientFailure('superseded');
        await Stripe.instance.presentPaymentSheet();
      }
    } on MissingPluginException {
      throw const ClientFailure('sdk_unavailable');
    } on PlatformException catch (error) {
      const codes = {
        'wallet_unavailable',
        'sdk_unavailable',
        'user_cancelled',
        'confirmation_pending',
        'purchase_in_progress',
      };
      throw ClientFailure(
        codes.contains(error.code) ? error.code : 'sdk_error',
      );
    } on StripeException catch (error) {
      throw ClientFailure(
        error.error.code == FailureCode.Canceled
            ? 'user_cancelled'
            : 'sdk_error',
      );
    } finally {
      _confirming = false;
    }
  }
}
