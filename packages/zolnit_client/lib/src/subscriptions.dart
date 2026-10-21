import 'api.dart';

class ZolnitBillingClient {
  const ZolnitBillingClient(this.api);

  final XboardClient api;

  static const _base = '/api/v1/zolnit-stripe';

  Future<Json> _requestJson(
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    try {
      final value = await api.request(
        path,
        method: method,
        query: query,
        authenticated: authenticated,
      );
      if (value is! Json) throw const ClientFailure('invalid_billing_response');
      return value;
    } on ClientFailure catch (error) {
      if (error.code == 'invalid_response') {
        throw const ClientFailure('invalid_billing_response');
      }
      rethrow;
    }
  }

  Future<Json> config() => _requestJson('$_base/config', authenticated: false);

  Future<Json> entitlement() => _requestJson('$_base/entitlement');

  Future<Json> subscriptions() async {
    final value = await _requestJson('$_base/subscriptions');
    final entries = value['subscriptions'];
    if (entries is! List ||
        !entries.every((entry) => entry is Json) ||
        value['entitlement'] is! Json) {
      throw const ClientFailure('invalid_billing_response');
    }
    return value;
  }

  Future<Json> plans({int? paymentId, int? planId, String? period}) async {
    if ((paymentId != null && paymentId <= 0) ||
        (planId != null && planId <= 0)) {
      throw const ClientFailure('invalid_billing_id');
    }
    return _requestJson(
      '$_base/plans',
      query: {
        if (paymentId != null) 'payment_id': '$paymentId',
        if (planId != null) 'plan_id': '$planId',
        'period': ?period,
      },
    );
  }

  Future<Json> cancelSubscription(int id) => _changeSubscription(id, 'cancel');

  Future<Json> resumeSubscription(int id) => _changeSubscription(id, 'resume');

  Future<Json> _changeSubscription(int id, String action) async {
    if (id <= 0) throw const ClientFailure('invalid_billing_id');
    return _requestJson('$_base/subscriptions/$id/$action', method: 'POST');
  }
}
