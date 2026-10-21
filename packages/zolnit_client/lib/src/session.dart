import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'checkout.dart';
import 'subscriptions.dart';

class _SessionWork {
  _SessionWork(this.epoch, this.generation, this.sequence);

  final int epoch;
  int generation;
  final int sequence;
}

class ZolnitSessionController extends ChangeNotifier {
  ZolnitSessionController({
    required this.api,
    required ZolnitBillingClient billing,
    required this.checkout,
    this.confirmRecurring,
  }) : _billing = billing {
    checkout.addListener(_checkoutChanged);
  }

  final XboardClient api;
  final ZolnitBillingClient _billing;
  final CheckoutController checkout;
  final Future<bool> Function(Json terms)? confirmRecurring;
  final Map<String, Future<dynamic>> _flights = {};
  final Map<String, String?> _intents = {};
  bool _disposed = false;
  bool _invalidating = false;
  int _readSequence = 0;
  int _coreRead = 0;
  int _ordersRead = 0;
  int _billingRead = 0;
  bool _authenticated = false;
  int _epoch = 0;
  int _sequence = 0;
  int _coreSequence = 0;
  int _billingSequence = 0;
  String? _failure;
  String? _billingFailure;
  String? _failureMessage;
  String? _billingFailureMessage;
  Json? _account;
  Json? _subscription;
  List<Json> _nodes = const [];
  List<Json> _plans = const [];
  List<Json> _orders = const [];
  List<Json> _paymentMethods = const [];
  Json? _billingOverview;
  Json? _recurringConfig;
  final Map<String, Json> _recurringTerms = {};
  String? _completedTrade;

  bool get authenticated => _authenticated;
  bool get busy => _flights.isNotEmpty;
  String? get failure => _failure;
  String? get billingFailure => _billingFailure;
  String? get failureMessage => _failureMessage;
  String? get billingFailureMessage => _billingFailureMessage;
  Json? get account => _account;
  Json? get subscription => _subscription;
  List<Json> get nodes => _nodes;
  List<Json> get plans => _plans;
  List<Json> get orders => _orders;
  List<Json> get paymentMethods => _paymentMethods;
  Json? get billingOverview => _billingOverview;
  List<Json> get recurringMethods {
    final config = _recurringConfig;
    final channels = config?['channels'];
    if (config?['enabled'] != true ||
        config?['configured'] != true ||
        channels is! List) {
      return const [];
    }
    return channels
        .whereType<Json>()
        .where(
          (channel) =>
              channel['id'] is int &&
              (channel['id'] as int) > 0 &&
              channel['enabled'] == true &&
              channel['configured'] == true,
        )
        .toList(growable: false);
  }

  bool _current(_SessionWork work) =>
      !_disposed && work.epoch == _epoch && work.generation == api.generation;

  void _checkoutChanged() {
    if (!_disposed && !_invalidating) notifyListeners();
  }

  static String _code(Object error) =>
      error is ClientFailure &&
          RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(error.code)
      ? error.code
      : 'client_error';

  static String? _message(Object error) =>
      error is ClientFailure ? error.serverMessage : null;

  Future<T> _run<T>(
    String key,
    T fallback,
    Future<T> Function(_SessionWork work) action, {
    bool billing = false,
    bool login = false,
    String? intent,
  }) {
    if (_disposed) return Future.value(fallback);
    final active = _flights[key];
    if (active != null) {
      if (intent != null && _intents[key] != intent) {
        return _run<T>(
          'conflict:$key',
          fallback,
          (_) async => throw const ClientFailure('operation_in_progress'),
          billing: billing,
        );
      }
      return active as Future<T>;
    }
    final work = _SessionWork(_epoch, api.generation, ++_sequence);
    late final Future<T> operation;
    operation = Future<T>.microtask(() async {
      try {
        if (!_current(work)) return fallback;
        if (billing) {
          _billingSequence = work.sequence;
          _billingFailure = null;
          _billingFailureMessage = null;
        } else {
          _coreSequence = work.sequence;
          _failure = null;
          _failureMessage = null;
        }
        notifyListeners();
        if (!_current(work)) return fallback;
        if (!login && !_authenticated) {
          throw const ClientFailure('unauthenticated');
        }
        return await action(work);
      } catch (error) {
        if (_current(work)) {
          if (billing && work.sequence == _billingSequence) {
            _billingFailure = _code(error);
            _billingFailureMessage = _message(error);
          } else if (!billing && work.sequence == _coreSequence) {
            _failure = _code(error);
            _failureMessage = _message(error);
          }
        }
        return fallback;
      } finally {
        if (identical(_flights[key], operation)) {
          unawaited(_flights.remove(key));
          _intents.remove(key);
          if (!_disposed) notifyListeners();
        }
      }
    });
    _flights[key] = operation;
    _intents[key] = intent;
    return operation;
  }

  Future<void> login(String email, String password) {
    if (_disposed) return Future.value();
    final active = _flights['login'];
    if (active != null) return active as Future<void>;
    _invalidate();
    return _run<void>('login', null, (work) async {
      try {
        final result = await api.login(email, password);
        if (!_current(work)) return;
        final authorization = result['auth_data'];
        if (authorization is! String || authorization.isEmpty) {
          throw const ClientFailure('invalid_authorization');
        }
        api.setAuthorization(authorization);
        work.generation = api.generation;
        await _loadCore(work);
        if (_current(work)) _authenticated = true;
      } catch (_) {
        if (_current(work)) {
          api.setAuthorization(null);
          work.generation = api.generation;
          _clearSnapshots();
        }
        rethrow;
      }
    }, login: true);
  }

  void _clearSnapshots() {
    _authenticated = false;
    _account = null;
    _subscription = null;
    _nodes = const [];
    _plans = const [];
    _orders = const [];
    _paymentMethods = const [];
    _billingOverview = null;
    _recurringConfig = null;
    _recurringTerms.clear();
    _completedTrade = null;
  }

  void _invalidate() {
    _epoch++;
    _flights.clear();
    _intents.clear();
    api.setAuthorization(null);
    _clearSnapshots();
    _failure = null;
    _billingFailure = null;
    _failureMessage = null;
    _billingFailureMessage = null;
    _invalidating = true;
    try {
      checkout.reset();
    } finally {
      _invalidating = false;
    }
  }

  void logout() {
    if (_disposed) return;
    _invalidate();
    notifyListeners();
  }

  static Json _object(dynamic value) {
    if (value is! Json) throw const ClientFailure('invalid_response');
    return Map<String, dynamic>.unmodifiable(value);
  }

  static List<Json> _list(dynamic value) {
    if (value is! List || !value.every((entry) => entry is Json)) {
      throw const ClientFailure('invalid_response');
    }
    return List<Json>.unmodifiable(value.map(_object));
  }

  Future<void> _loadCore(_SessionWork work) async {
    final read = ++_readSequence;
    _coreRead = read;
    _ordersRead = read;
    final values = await Future.wait<dynamic>([
      api.account(),
      api.subscription(),
      api.nodes(),
      api.plans(),
      api.orders(),
      api.paymentMethods(),
    ]);
    if (!_current(work)) return;
    final account = _object(values[0]);
    final subscription = _object(values[1]);
    final nodes = _list(values[2]);
    final plans = _list(values[3]);
    final orders = _list(values[4]);
    final methods = _list(values[5]);
    if (read == _coreRead) {
      _account = account;
      _subscription = subscription;
      _nodes = nodes;
      _plans = plans;
      _paymentMethods = methods;
    }
    if (read == _ordersRead) _orders = orders;
  }

  Future<void> refresh() => _run<void>('refresh', null, _loadCore);

  Future<void> _loadBilling(_SessionWork work) async {
    final read = ++_readSequence;
    _billingRead = read;
    final value = await _billing.subscriptions();
    if (_current(work) && read == _billingRead) {
      _billingOverview = _object(value);
    }
  }

  Future<void> refreshBilling() =>
      _run<void>('billing', null, _loadBilling, billing: true);

  Future<void> refreshRecurringOptions() =>
      _run<void>('recurringOptions', null, (work) async {
        _recurringConfig = null;
        final config = await _billing.config(authenticated: true);
        if (_current(work)) _recurringConfig = _object(config);
      }, billing: true);

  Future<void> cancelRenewal(int id) => _renewal(id, resume: false);

  Future<void> resumeRenewal(int id) => _renewal(id, resume: true);

  Future<void> _renewal(int id, {required bool resume}) => _run<void>(
    'renewal',
    null,
    (work) async {
      if (resume && !checkout.allowStripe) {
        throw const ClientFailure('payment_disallowed');
      }
      if (resume) {
        await _billing.resumeSubscription(id);
      } else {
        await _billing.cancelSubscription(id);
      }
      if (_current(work)) await _loadBilling(work);
    },
    billing: true,
    intent: '$id:$resume',
  );

  Future<void> _loadOrders(_SessionWork work) async {
    final read = ++_readSequence;
    _ordersRead = read;
    final value = await api.orders();
    if (_current(work) && read == _ordersRead) _orders = _list(value);
  }

  Future<String?> createOrder({
    required int planId,
    required String period,
    String? coupon,
  }) => _run<String?>('createOrder', null, (work) async {
    if (!checkout.allowStripe) throw const ClientFailure('payment_disallowed');
    final trade = await api.createOrder(
      planId: planId,
      period: period,
      coupon: coupon,
    );
    if (!_current(work)) return null;
    if (trade.isEmpty) throw const ClientFailure('invalid_response');
    await _loadOrders(work);
    return _current(work) ? trade : null;
  }, intent: '$planId:$period:${coupon ?? ''}');

  Future<String?> createMonthlyOrder({
    required int planId,
    required int paymentId,
  }) => _run<String?>('createOrder', null, (work) async {
    if (!checkout.allowStripe) throw const ClientFailure('payment_disallowed');
    final confirm = confirmRecurring;
    if (confirm == null) {
      throw const ClientFailure('recurring_consent_required');
    }
    final config = await _billing.config(authenticated: true);
    if (!_current(work)) return null;
    _recurringConfig = _object(config);
    if (!recurringMethods.any((channel) => channel['id'] == paymentId)) {
      throw const ClientFailure('recurring_unavailable');
    }
    final quote = await _billing.monthlyQuote(
      paymentId: paymentId,
      planId: planId,
    );
    if (!_current(work)) return null;
    final approved = await confirm(quote.terms);
    if (!_current(work) || !approved) return null;
    final trade = await _billing.createRecurringOrder(quote, consent: true);
    if (!_current(work)) return null;
    _recurringTerms[trade] = quote.terms;
    await _loadOrders(work);
    return _current(work) ? trade : null;
  }, intent: 'monthly:$planId:$paymentId');

  Future<void> _reconcilePayment(_SessionWork work) async {
    final trade = checkout.tradeNo;
    if (checkout.stage != CheckoutStage.completed ||
        trade == null ||
        trade == _completedTrade) {
      return;
    }
    final pending = _flights['refresh'];
    if (pending != null) await pending;
    if (!_current(work)) return;
    await refresh();
    if (_current(work) && _failure == null) _completedTrade = trade;
  }

  Future<void> payOrder(String tradeNo, int methodId) =>
      _run<void>('payment', null, (work) async {
        await checkout.start(
          tradeNo,
          methodId,
          recurringTerms: _recurringTerms[tradeNo],
        );
        if (!_current(work)) return;
        if (checkout.failure != null &&
            checkout.stage != CheckoutStage.completed) {
          throw ClientFailure(
            checkout.failure!,
            serverMessage: checkout.failureMessage,
          );
        }
        await _reconcilePayment(work);
      }, intent: '$tradeNo:$methodId');

  Future<void> cancelOrder(String tradeNo) =>
      _run<void>('cancelOrder', null, (work) async {
        await api.cancelOrder(tradeNo);
        if (!_current(work)) return;
        if (checkout.tradeNo == tradeNo) checkout.reset();
        if (!_current(work)) return;
        await _loadOrders(work);
      }, intent: tradeNo);

  Future<void> refreshPayment() => _run<void>('payment', null, (work) async {
    await checkout.refresh();
    if (!_current(work)) return;
    if (checkout.failure != null && checkout.stage != CheckoutStage.completed) {
      throw ClientFailure(
        checkout.failure!,
        serverMessage: checkout.failureMessage,
      );
    }
    await _reconcilePayment(work);
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _flights.clear();
    _intents.clear();
    _clearSnapshots();
    checkout.removeListener(_checkoutChanged);
    checkout.dispose();
    api.close();
    super.dispose();
  }
}
