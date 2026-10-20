import 'api.dart';
import 'apple.dart';
import 'checkout.dart';

String _string(Json json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const ClientFailure('invalid_billing_response');
  }
  return value;
}

PaymentQr? _qr(Json json) {
  final value = json['qr'];
  if (value == null) return null;
  if (value is! Json) throw const ClientFailure('invalid_billing_response');
  final expires = value['expires_at'];
  if (expires is! int || expires < 1) {
    throw const ClientFailure('invalid_billing_response');
  }
  return PaymentQr(
    payload: _string(value, 'payload'),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true),
  );
}

class XboardCheckoutBackend implements CheckoutBackend {
  const XboardCheckoutBackend(this.api);

  final XboardClient api;

  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async {
    final response = await api.checkout(tradeNo, methodId);
    if (response['type'] == -1 && response['data'] == true) {
      return const StatusOnlyCheckout();
    }
    if (response['type'] == 1 && response['data'] is String) {
      return HostedCheckout(Uri.parse(response['data'] as String));
    }
    final value = response['data'];
    if (value is! Json || value['trade_no'] != tradeNo) {
      throw const ClientFailure('invalid_billing_response');
    }
    final qr = _qr(value);
    switch (value['kind']) {
      case 'hosted':
        return HostedCheckout(Uri.parse(_string(value, 'url')), fallbackQr: qr);
      case 'qr':
        if (qr == null) throw const ClientFailure('invalid_billing_response');
        return QrCheckout(qr);
      case 'stripe_android':
        final wallet = switch (value['wallet']) {
          'card' => StripeWallet.card,
          'alipay' => StripeWallet.alipay,
          'wechat_pay' => StripeWallet.wechatPay,
          _ => throw const ClientFailure('invalid_billing_response'),
        };
        return StripeCheckout(
          publishableKey: _string(value, 'publishable_key'),
          clientSecret: _string(value, 'client_secret'),
          wallet: wallet,
          returnUri: Uri.parse(_string(value, 'return_url')),
          wechatAppId: value['wechat_app_id'] as String?,
          fallbackQr: qr,
        );
      default:
        throw const ClientFailure('unsupported_checkout_action');
    }
  }

  @override
  Future<int> status(String tradeNo) => api.orderStatus(tradeNo);
}

class AppleBillingPaths {
  const AppleBillingPaths({required this.prepare, required this.verify});

  final String prepare;
  final String verify;
}

class XboardAppleBillingBackend implements AppleBillingBackend {
  const XboardAppleBillingBackend(this.api, this.paths);

  final XboardClient api;
  final AppleBillingPaths paths;

  @override
  Future<ApplePurchaseContext> prepare(String productId) async {
    final value = await api.request(
      paths.prepare,
      method: 'POST',
      body: {'product_id': productId},
    );
    if (value is! Json) throw const ClientFailure('invalid_billing_response');
    return ApplePurchaseContext(
      accountId: _string(value, 'account_id'),
      productId: _string(value, 'product_id'),
      appAccountToken: _string(value, 'app_account_token'),
    );
  }

  @override
  Future<AppleVerification> verify(ApplePurchaseProof proof) async {
    final value = await api.request(
      paths.verify,
      method: 'POST',
      body: {
        'product_id': proof.productId,
        'transaction_id': proof.transactionId,
        'verification_data': proof.verificationData,
        'source': proof.source,
      },
    );
    if (value is! Json || value['applied'] is! bool) {
      throw const ClientFailure('invalid_billing_response');
    }
    return AppleVerification(
      accountId: _string(value, 'account_id'),
      productId: _string(value, 'product_id'),
      transactionId: _string(value, 'transaction_id'),
      applied: value['applied'] as bool,
    );
  }
}
