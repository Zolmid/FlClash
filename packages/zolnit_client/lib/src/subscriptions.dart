import 'api.dart';

class RecurringQuote {
  RecurringQuote._({
    required this.paymentId,
    required this.planId,
    required this.generation,
    required this.terms,
  });

  final int paymentId;
  final int planId;
  final int generation;
  final Json terms;

  int get id => terms['quote_id'] as int;
  bool validAt(DateTime now) =>
      (terms['quote_expires_at'] as int) > now.millisecondsSinceEpoch ~/ 1000;
}

class ZolnitBillingClient {
  const ZolnitBillingClient(this.api);

  final XboardClient api;

  static const _base = '/api/v1/zolnit-stripe';

  Future<Json> _requestJson(
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Json? body,
    bool authenticated = true,
  }) async {
    try {
      final value = await api.request(
        path,
        method: method,
        query: query,
        body: body,
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

  Future<Json> config({bool authenticated = false}) =>
      _requestJson('$_base/config', authenticated: authenticated);

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

  Future<RecurringQuote> monthlyQuote({
    required int paymentId,
    required int planId,
  }) async {
    final generation = api.generation;
    final value = await plans(
      paymentId: paymentId,
      planId: planId,
      period: 'monthly',
    );
    final entries = value['plans'];
    if (entries is! List ||
        entries.length != 1 ||
        entries.single is! Json ||
        (entries.single as Json)['id'] != planId) {
      throw const ClientFailure('invalid_billing_response');
    }
    final periods = (entries.single as Json)['periods'];
    if (periods is! List || periods.length != 1 || periods.single is! Json) {
      throw const ClientFailure('invalid_billing_response');
    }
    final offer = periods.single as Json;
    if (offer['period'] != 'monthly') {
      throw const ClientFailure('invalid_billing_response');
    }
    if (offer['available'] == false) {
      throw const ClientFailure('recurring_unavailable');
    }
    if (offer['available'] != true ||
        offer['months'] != 1 ||
        offer['currency'] != 'CNY' ||
        offer['charge_currency'] != 'SGD' ||
        offer['gift_replacement'] is! bool ||
        offer['switch_immediately'] is! bool) {
      throw const ClientFailure('invalid_billing_response');
    }
    for (final key in [
      'price_cents',
      'recurring_price_cents',
      'handling_amount_cents',
      'recurring_total_cents',
      'charge_amount_cents',
      'first_total_cents',
      'first_charge_amount_cents',
      'surplus_amount_cents',
      'surplus_credit_cents',
    ]) {
      if (offer[key] is! int || (offer[key] as int) < 0) {
        throw const ClientFailure('invalid_billing_response');
      }
    }
    if (offer['quote_id'] is! int ||
        (offer['quote_id'] as int) <= 0 ||
        offer['quote_expires_at'] is! int ||
        (offer['quote_expires_at'] as int) <= 0 ||
        (offer['next_charge_at'] != null &&
            (offer['next_charge_at'] is! int ||
                (offer['next_charge_at'] as int) <= 0))) {
      throw const ClientFailure('invalid_billing_response');
    }
    final quote = RecurringQuote._(
      paymentId: paymentId,
      planId: planId,
      generation: generation,
      terms: Map<String, dynamic>.unmodifiable({
        ...offer,
        'total_cents': offer['recurring_total_cents'],
      }),
    );
    if (!quote.validAt(DateTime.now())) {
      throw const ClientFailure('recurring_quote_expired');
    }
    return quote;
  }

  Future<String> createRecurringOrder(
    RecurringQuote quote, {
    required bool consent,
  }) async {
    if (!consent) throw const ClientFailure('recurring_consent_required');
    if (quote.generation != api.generation) {
      throw const ClientFailure('superseded');
    }
    if (!quote.validAt(DateTime.now())) {
      throw const ClientFailure('recurring_quote_expired');
    }
    final value = await _requestJson(
      '$_base/recurring-orders',
      method: 'POST',
      body: {
        'payment_id': quote.paymentId,
        'plan_id': quote.planId,
        'quote_id': quote.id,
        'consent': true,
      },
    );
    final trade = value['trade_no'];
    if (trade is! String || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trade)) {
      throw const ClientFailure('invalid_billing_response');
    }
    return trade;
  }

  Future<Json> cancelSubscription(int id) => _changeSubscription(id, 'cancel');

  Future<Json> resumeSubscription(int id) => _changeSubscription(id, 'resume');

  Future<Json> _changeSubscription(int id, String action) async {
    if (id <= 0) throw const ClientFailure('invalid_billing_id');
    return _requestJson('$_base/subscriptions/$id/$action', method: 'POST');
  }
}
