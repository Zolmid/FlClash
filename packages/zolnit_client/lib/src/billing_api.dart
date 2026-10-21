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
  const XboardCheckoutBackend(this.api, {this.confirmRecurring});

  final XboardClient api;
  final Future<bool> Function(Json intent)? confirmRecurring;

  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async {
    final generation = api.generation;
    void ensureCurrent() {
      if (api.generation != generation) {
        throw const ClientFailure('superseded');
      }
    }

    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(tradeNo)) {
      throw const ClientFailure('invalid_path');
    }
    final detail = await api.order(tradeNo);
    ensureCurrent();
    if (detail is! Json || detail['trade_no'] != tradeNo) {
      throw const ClientFailure('invalid_billing_response');
    }
    dynamic intent;
    try {
      intent = await api.request(
        '/api/v1/zolnit-stripe/recurring-orders/$tradeNo',
      );
      ensureCurrent();
    } on ClientFailure catch (error) {
      ensureCurrent();
      if (error.statusCode != 404) rethrow;
      final response = await api.checkout(tradeNo, methodId);
      ensureCurrent();
      return _checkout(response, tradeNo);
    }
    if (intent is! Json ||
        intent['recurring'] != true ||
        intent['trade_no'] != tradeNo ||
        intent['period'] != 'monthly' ||
        intent['status'] != 0 ||
        intent['charge_currency'] != 'SGD') {
      throw const ClientFailure('invalid_billing_response');
    }
    for (final key in ['payment_id', 'plan_id', 'quote_id']) {
      if (intent[key] is! int || (intent[key] as int) <= 0) {
        throw const ClientFailure('invalid_billing_response');
      }
    }
    for (final key in [
      'price_cents',
      'handling_amount_cents',
      'total_cents',
      'charge_amount_cents',
      'first_total_cents',
      'first_charge_amount_cents',
      'surplus_amount_cents',
      'surplus_credit_cents',
    ]) {
      if (intent[key] is! int || (intent[key] as int) < 0) {
        throw const ClientFailure('invalid_billing_response');
      }
    }
    final body = <String, dynamic>{
      'payment_id': intent['payment_id'],
      'plan_id': intent['plan_id'],
      'period': intent['period'],
      'quote_id': intent['quote_id'],
      'trade_no': tradeNo,
      'consent': true,
    };
    final confirm = confirmRecurring;
    if (confirm == null) {
      throw const ClientFailure('recurring_consent_required');
    }
    final consent = await confirm(Map<String, dynamic>.unmodifiable(intent));
    ensureCurrent();
    if (!consent) throw const ClientFailure('recurring_consent_required');
    ensureCurrent();
    final value = await api.request(
      '/api/v1/zolnit-stripe/subscribe',
      method: 'POST',
      body: body,
    );
    ensureCurrent();
    if (value is! Json) {
      throw const ClientFailure('invalid_billing_response');
    }
    _rejectEmbedded(value);
    if (value['checkout_mode'] != 'hosted' ||
        value['session_id'] is! String ||
        !RegExp(
          r'^cs_[A-Za-z0-9_]+$',
        ).hasMatch(value['session_id'] as String) ||
        value['contract_id'] is! int ||
        (value['contract_id'] as int) <= 0 ||
        (value.containsKey('trade_no') && value['trade_no'] != tradeNo)) {
      throw const ClientFailure('invalid_billing_response');
    }
    return _hosted(value);
  }

  void _rejectEmbedded(Json value) {
    if (value['checkout_mode'] == 'embedded' || value['kind'] == 'embedded') {
      throw const ClientFailure('unsupported_embedded_checkout');
    }
  }

  HostedCheckout _hosted(Json value) {
    final uri = Uri.tryParse(_string(value, 'checkout_url'));
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ClientFailure('invalid_billing_response');
    }
    return HostedCheckout(uri, fallbackQr: _qr(value));
  }

  CheckoutAction _checkout(Json response, String tradeNo) {
    if (response['type'] == -1 && response['data'] == true) {
      return const StatusOnlyCheckout();
    }
    if (response['type'] == 1 && response['data'] is String) {
      return HostedCheckout(Uri.parse(response['data'] as String));
    }
    final value = response['data'];
    if (value is Json) {
      _rejectEmbedded(value);
      if (value.containsKey('trade_no') && value['trade_no'] != tradeNo) {
        throw const ClientFailure('invalid_billing_response');
      }
      if (response['type'] == 1 &&
          {'hosted', 'legacy_hosted'}.contains(value['checkout_mode'])) {
        return _hosted(value);
      }
    }
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
