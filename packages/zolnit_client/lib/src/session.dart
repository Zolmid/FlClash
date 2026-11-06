import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'catalog.dart';
import 'parse.dart';
import 'client_bundle.dart';
import 'checkout.dart';
import 'policy.dart';
import 'subscriptions.dart';
import 'session_vault.dart';

class _SessionWork {
  _SessionWork(this.epoch, this.generation, this.sequence);

  final int epoch;
  int generation;
  final int sequence;
}

enum ZolnitRestoreState { signedOut, restoring, signedIn, offline, expired }

class ZolnitSessionController extends ChangeNotifier {
  ZolnitSessionController({
    required this.api,
    required ZolnitBillingClient billing,
    required this.checkout,
    this.vault,
    this.confirmRecurring,
    this.onAuthenticationInvalidated,
    this.vaultTimeout = const Duration(seconds: 5),
    this.authenticationTimeout = const Duration(seconds: 30),
  }) : _billing = billing {
    checkout.addListener(_checkoutChanged);
  }

  final XboardClient api;
  final ZolnitBillingClient _billing;
  final CheckoutController checkout;
  final Future<bool> Function(Json terms)? confirmRecurring;
  final ZolnitSessionVault? vault;
  final Future<void> Function()? onAuthenticationInvalidated;
  final Duration vaultTimeout;
  final Duration authenticationTimeout;
  final Map<String, Future<dynamic>> _flights = {};
  final Map<String, String?> _intents = {};
  final _quoteFlights =
      <(int, int, int, int, String), Future<Map<int, RecurringPlanQuote>>>{};
  final _quoteCache =
      <(int, int, int, int, String), Map<int, RecurringPlanQuote>>{};
  int _quoteRevision = 0;
  bool _disposed = false;
  bool _invalidating = false;
  int _readSequence = 0;
  int _coreRead = 0;
  int _ordersRead = 0;
  int _billingRead = 0;
  bool _authenticated = false;
  ZolnitClientBundle? _clientBundle;
  String? _clientBundleAccountId;
  int? _clientBundleGeneration;
  int? _clientBundleFailureGeneration;
  List<ZolnitNode> _clientBundleNodes = const [];
  String? _clientBundleFailure;
  int _epoch = 0;
  int _sequence = 0;
  int _coreSequence = 0;
  int _billingSequence = 0;
  int _vaultGeneration = 0;
  Future<void> _vaultTail = Future.value();
  String? _failure;
  String? _billingFailure;
  String? _failureMessage;
  String? _billingFailureMessage;
  Json? _account;
  Json? _subscription;
  Json? _displayUsage;
  List<Json> _nodes = const [];
  List<Json> _plans = const [];
  List<Json> _notices = const [];
  List<Json> _orders = const [];
  List<Json> _paymentMethods = const [];
  Json? _billingOverview;
  Json? _recurringConfig;
  bool _recurringOptionsAttempted = false;
  final Map<String, Json> _recurringTerms = {};
  final Set<String> _singlePaymentOrders = {};
  String? _completedTrade;
  Object? _nodesSource;
  Object? _plansSource;
  Object? _noticesSource;
  Object? _usageSource;
  List<ZolnitNode> _nodeModels = const [];
  List<ZolnitPlan> _planModels = const [];
  List<ZolnitNotice> _noticeModels = const [];
  ZolnitUsage? _usageModel;
  ZolnitRestoreState _restoreState = ZolnitRestoreState.signedOut;

  ZolnitClientBundle? get clientBundle =>
      _clientBundleGeneration == api.generation ? _clientBundle : null;
  String? get clientBundleAccountId =>
      _clientBundleGeneration == api.generation ? _clientBundleAccountId : null;
  String? get clientBundleFailure =>
      _clientBundleFailureGeneration == api.generation
      ? _clientBundleFailure
      : null;

  bool get authenticated => _authenticated;
  ZolnitRestoreState get restoreState => _restoreState;
  bool get restoring => _restoreState == ZolnitRestoreState.restoring;
  int get accountGeneration => _epoch;
  int get quoteRevision => _quoteRevision;
  bool get busy => _flights.isNotEmpty;
  String? get failure => _failure;
  String? get billingFailure => _billingFailure;
  String? get failureMessage => _failureMessage;
  String? get billingFailureMessage => _billingFailureMessage;
  Json? get account => _account;
  Json? get subscription => _subscription;
  List<Json> get nodes => _nodes;
  List<Json> get plans => _plans;
  List<Json> get notices => _notices;
  List<Json> get orders => _orders;

  List<ZolnitNode> get nodeList {
    if (clientBundle != null) return _clientBundleNodes;
    if (!identical(_nodesSource, _nodes)) {
      _nodesSource = _nodes;
      _nodeModels = List.unmodifiable(_nodes.map(ZolnitNode.fromJson));
    }
    return _nodeModels;
  }

  List<ZolnitPlan> get planList {
    if (!identical(_plansSource, _plans)) {
      _plansSource = _plans;
      _planModels = List.unmodifiable(_plans.map(ZolnitPlan.fromJson));
    }
    return _planModels;
  }

  List<ZolnitNotice> get noticeList {
    if (!identical(_noticesSource, _notices)) {
      _noticesSource = _notices;
      _noticeModels = List.unmodifiable(_notices.map(ZolnitNotice.fromJson));
    }
    return _noticeModels;
  }

  ZolnitUsage? get usage {
    final source = _displayUsage ?? _subscription;
    if (!identical(_usageSource, source)) {
      _usageSource = source;
      _usageModel = source == null
          ? null
          : ZolnitUsage.fromSubscription(source);
    }
    return _usageModel;
  }

  List<Json> get paymentMethods => _paymentMethods;
  bool knownSinglePayment(String tradeNo) =>
      _singlePaymentOrders.contains(tradeNo);

  bool hasRecurringTerms(String tradeNo) =>
      _recurringTerms.containsKey(tradeNo);

  String? nativeWalletForMethod(int methodId, ClientPaymentPolicy policy) {
    final method = _paymentMethods
        .where((method) => method['id'] == methodId)
        .singleOrNull;
    final provider = method?['payment'];
    if (provider != 'ZolnitStripe' ||
        _recurringConfig?['enabled'] != true ||
        _recurringConfig?['configured'] != true) {
      return null;
    }
    final channels = _recurringConfig?['channels'];
    final channel = channels is List
        ? channels
              .whereType<Json>()
              .where(
                (channel) =>
                    channel['id'] == methodId &&
                    channel['provider'] == provider &&
                    channel['enabled'] == true &&
                    channel['configured'] == true,
              )
              .singleOrNull
        : null;
    final capability = channel?['native_checkout'];
    return capability is Json
        ? policy.nativeWalletForCapability(capability)
        : null;
  }

  String? get billingSettlementCurrency {
    final value = _recurringConfig?['settlement_currency'];
    return value is String ? value.toUpperCase() : null;
  }

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
    bool clientBundle = false,
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
        } else if (!clientBundle) {
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
          final invalid =
              _authenticated &&
              error is ClientFailure &&
              error.code == 'unauthenticated';
          if (invalid) {
            final deletion = _invalidate();
            final invalidatedEpoch = _epoch;
            _restoreState = ZolnitRestoreState.expired;
            _failure = 'unauthenticated';
            notifyListeners();
            try {
              await Future.wait<void>([
                deletion,
                Future<void>.sync(() async {
                  if (!_disposed && _epoch == invalidatedEpoch) {
                    await onAuthenticationInvalidated?.call();
                  }
                }),
              ]).timeout(vaultTimeout);
            } catch (_) {}
            return fallback;
          }
          if (clientBundle) {
            _clientBundleFailure = _code(error);
            _clientBundleFailureGeneration = work.generation;
          } else if (billing && work.sequence == _billingSequence) {
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
    return _authenticate(() => api.login(email, password));
  }

  Future<void> exchangeRegistration(String code, String codeVerifier) {
    return _authenticate(() => api.exchangeRegistration(code, codeVerifier));
  }

  void reportSignInFailure(String code) {
    if (_disposed || _authenticated) return;
    _failure = code;
    _failureMessage = null;
    notifyListeners();
  }

  Future<void> _authenticate(Future<Json> Function() authenticate) {
    if (_disposed) return Future.value();
    final active = _flights['login'];
    if (active != null) return active as Future<void>;
    _invalidate(deleteAuthorization: false);
    return _run<void>('login', null, (work) async {
      try {
        final result = await authenticate().timeout(authenticationTimeout);
        if (!_current(work)) return;
        final authorization = result['auth_data'];
        if (authorization is! String || authorization.isEmpty) {
          throw const ClientFailure('invalid_authorization');
        }
        api.setAuthorization(authorization);
        work.generation = api.generation;
        await _loadIdentity(work);
        if (!_current(work)) return;
        final hydration = _startOptionalLoad(work);
        if (_current(work)) {
          await _persistAuthorization(work, authorization);
          if (!_current(work)) return;
          _authenticated = true;
          _restoreState = ZolnitRestoreState.signedIn;
          unawaited(hydration);
        }
      } catch (error) {
        if (_current(work)) {
          api.setAuthorization(null);
          work.generation = api.generation;
          _clearSnapshots();
          if (error is ClientFailure &&
              (error.code == 'unauthenticated' ||
                  error.code == 'invalid_authorization')) {
            await _deleteAuthorization(
              work,
            ).timeout(vaultTimeout, onTimeout: () {});
          }
        }
        rethrow;
      }
    }, login: true);
  }

  Future<void> restore() {
    if (_disposed || _authenticated) return Future.value();
    final active = _flights['restore'];
    if (active != null) return active as Future<void>;
    final vault = this.vault;
    if (vault == null) return Future.value();
    _restoreState = ZolnitRestoreState.restoring;
    notifyListeners();
    final work = _SessionWork(_epoch, api.generation, ++_sequence);
    late final Future<void> operation;
    operation = Future<void>.microtask(() async {
      try {
        final authorization = await _readAuthorization(vault);
        if (!_current(work)) return;
        if (authorization == null || authorization.isEmpty) {
          _restoreState = ZolnitRestoreState.signedOut;
          return;
        }
        api.setAuthorization(authorization);
        work.generation = api.generation;
        await _loadIdentity(work);
        if (!_current(work)) return;
        final hydration = _startOptionalLoad(work);
        if (_current(work)) {
          _authenticated = true;
          _restoreState = ZolnitRestoreState.signedIn;
          unawaited(hydration);
        }
      } catch (error) {
        if (_current(work)) {
          final invalid =
              error is ClientFailure &&
              (error.code == 'unauthenticated' ||
                  error.code == 'invalid_authorization');
          api.setAuthorization(null);
          work.generation = api.generation;
          _clearSnapshots();
          if (invalid) {
            try {
              await Future.wait<void>([
                _deleteAuthorization(work),
                Future<void>.sync(() async {
                  if (_current(work)) await onAuthenticationInvalidated?.call();
                }),
              ]).timeout(vaultTimeout);
            } catch (_) {}
          }
          if (!_current(work)) return;
          _restoreState = invalid
              ? ZolnitRestoreState.expired
              : ZolnitRestoreState.offline;
          _failure = invalid ? 'unauthenticated' : _code(error);
          _failureMessage = invalid ? null : _message(error);
        }
      } finally {
        if (identical(_flights['restore'], operation)) {
          unawaited(_flights.remove('restore'));
          if (!_disposed) notifyListeners();
        }
      }
    });
    _flights['restore'] = operation;
    return operation;
  }

  Future<String?> _readAuthorization(ZolnitSessionVault vault) async {
    try {
      await _vaultTail.timeout(vaultTimeout);
      return await vault.readAuthorization().timeout(vaultTimeout);
    } catch (error) {
      if (error is ClientFailure) rethrow;
      throw const ClientFailure('storage_unavailable');
    }
  }

  Future<void> _writeAuthorization(_SessionWork work, String authorization) {
    final vault = this.vault;
    if (vault == null) return Future.value();
    final generation = _vaultGeneration;
    return _queueVaultMutation(() async {
      if (_current(work) && generation == _vaultGeneration) {
        await vault.writeAuthorization(authorization);
      }
    });
  }

  Future<void> _persistAuthorization(
    _SessionWork work,
    String authorization,
  ) async {
    try {
      await _writeAuthorization(work, authorization).timeout(vaultTimeout);
    } on TimeoutException {
      _scheduleFailedPersistenceCleanup();
      throw const ClientFailure('storage_unavailable');
    } catch (error) {
      if (error is ClientFailure) rethrow;
      _scheduleFailedPersistenceCleanup();
      throw const ClientFailure('storage_unavailable');
    }
  }

  void _scheduleFailedPersistenceCleanup() {
    final vault = this.vault;
    if (vault == null) return;
    final generation = ++_vaultGeneration;
    unawaited(
      _queueVaultMutation(() async {
        if (generation == _vaultGeneration) {
          await vault.deleteAuthorization();
        }
      }),
    );
  }

  Future<void> _deleteAuthorization(_SessionWork work) {
    final vault = this.vault;
    if (vault == null) return Future.value();
    final generation = _vaultGeneration;
    return _queueVaultMutation(() async {
      if (generation == _vaultGeneration) {
        await vault.deleteAuthorization();
      }
    });
  }

  Future<void> _queueVaultMutation(Future<void> Function() action) {
    final operation = _vaultTail.catchError((_) {}).then((_) => action());
    _vaultTail = operation.catchError((_) {});
    return operation;
  }

  void _clearQuotePreviews() {
    _quoteRevision++;
    _quoteFlights.clear();
    _quoteCache.clear();
  }

  void _clearSnapshots() {
    _clearQuotePreviews();
    _authenticated = false;
    _clientBundle = null;
    _clientBundleAccountId = null;
    _clientBundleGeneration = null;
    _clientBundleNodes = const [];
    _clientBundleFailureGeneration = null;
    _clientBundleFailure = null;
    _account = null;
    _subscription = null;
    _displayUsage = null;
    _nodes = const [];
    _plans = const [];
    _notices = const [];
    _orders = const [];
    _paymentMethods = const [];
    _billingOverview = null;
    _recurringConfig = null;
    _recurringOptionsAttempted = false;
    _recurringTerms.clear();
    _singlePaymentOrders.clear();
    _completedTrade = null;
  }

  Future<void> _invalidate({bool deleteAuthorization = true}) {
    _epoch++;
    _vaultGeneration++;
    _flights.clear();
    _intents.clear();
    api.setAuthorization(null);
    _clearSnapshots();
    _failure = null;
    _billingFailure = null;
    _failureMessage = null;
    _billingFailureMessage = null;
    _restoreState = ZolnitRestoreState.signedOut;
    _invalidating = true;
    try {
      checkout.reset();
    } finally {
      _invalidating = false;
    }
    if (!deleteAuthorization) return Future.value();
    final vault = this.vault;
    if (vault == null) return Future.value();
    final generation = _vaultGeneration;
    return _queueVaultMutation(() async {
      if (generation == _vaultGeneration) await vault.deleteAuthorization();
    });
  }

  Future<void> logout() {
    if (_disposed) return Future.value();
    final deletion = _invalidate();
    final epoch = _epoch;
    notifyListeners();
    return deletion.timeout(vaultTimeout).catchError((Object _) {
      if (!_disposed && epoch == _epoch) {
        _failure = 'storage_unavailable';
        notifyListeners();
      }
    });
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

  Future<void> _loadIdentity(_SessionWork work) async {
    final account = _object(await api.account().timeout(authenticationTimeout));
    if (_current(work)) _account = account;
  }

  Future<void> _startOptionalLoad(_SessionWork work) {
    final active = _flights['optional'];
    if (active != null) return active as Future<void>;
    final read = ++_readSequence;
    _coreRead = read;
    _ordersRead = read;

    Future<void> load(
      Future<dynamic> request,
      void Function(dynamic value) apply,
    ) async {
      try {
        final value = await request.timeout(authenticationTimeout);
        if (_current(work) && read == _coreRead) {
          apply(value);
          if (_authenticated) notifyListeners();
        }
      } catch (_) {
        return;
      }
    }

    late final Future<void> operation;
    operation =
        Future.wait<void>([
          load(api.subscription(), (value) {
            if (value is Json) {
              _subscription = Map<String, dynamic>.unmodifiable(value);
              _displayUsage = null;
            }
          }),
          load(api.nodes(), (value) {
            if (value is List && value.every((entry) => entry is Json)) {
              _nodes = _list(value);
            }
          }),
          load(api.plans(), (value) {
            if (value is List && value.every((entry) => entry is Json)) {
              _clearQuotePreviews();
              _plans = _list(value);
            }
          }),
          load(api.orders(), (value) {
            if (read == _ordersRead &&
                value is List &&
                value.every((entry) => entry is Json)) {
              _orders = _list(value);
            }
          }),
          load(api.paymentMethods(), (value) {
            if (value is List && value.every((entry) => entry is Json)) {
              _paymentMethods = _list(value);
            }
          }),
          load(api.notices(), (value) {
            if (value is List) {
              _notices = List<Json>.unmodifiable(value.whereType<Json>());
            }
          }),
        ]).whenComplete(() {
          if (identical(_flights['optional'], operation)) {
            _flights.remove('optional');
            if (!_disposed && _current(work)) notifyListeners();
          }
        });
    _flights['optional'] = operation;
    return operation;
  }

  Future<ZolnitClientBundle?> refreshClientBundle({
    required String coreVersion,
    DateTime Function()? clock,
  }) => _run<ZolnitClientBundle?>('client_bundle:${api.generation}', null, (
    work,
  ) async {
    final raw = await api.fetchClientBundle(coreVersion: coreVersion);
    if (!_current(work)) return null;
    final parsed = await compute(_parseClientBundle, (
      raw: raw,
      now: clock?.call() ?? DateTime.now(),
      accountId: clientBundleAccountId,
      panelNodes: _nodes,
    ));
    if (!_current(work)) return null;
    final bundle = parsed.bundle;
    _clientBundleNodes = parsed.nodes;
    _clientBundleAccountId = bundle.accountId;
    _clientBundleGeneration = work.generation;
    _clientBundle = bundle;
    _clientBundleFailure = null;
    _clientBundleFailureGeneration = work.generation;
    return bundle;
  }, clientBundle: true);

  Future<void> refresh() => _run<void>('refresh', null, (work) async {
    final hydration = _startOptionalLoad(work);
    await _loadIdentity(work);
    if (_current(work)) await hydration;
  });

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

  Future<void> refreshRealtimeNotices() async {
    final generation = api.generation;
    final value = await api.notices();
    if (_disposed || !_authenticated || generation != api.generation) return;
    if (value is! List || !value.every((v) => v is Json)) {
      throw const ClientFailure('invalid_response');
    }
    _notices = List.unmodifiable(value.cast<Json>());
    notifyListeners();
  }

  void applyRealtimeUsage(Json data) {
    if (_disposed || !_authenticated || _subscription == null) return;
    const fields = ['u', 'd', 'transfer_enable'];
    if (fields.any(
      (field) => data[field] is! int || (data[field] as int) < 0,
    )) {
      return;
    }
    _displayUsage = Map<String, dynamic>.unmodifiable({
      ..._subscription!,
      for (final field in fields) field: data[field],
    });
    notifyListeners();
  }

  Future<void> refreshRecurringOptions() =>
      _run<void>('recurringOptions', null, (work) async {
        _recurringOptionsAttempted = true;
        _clearQuotePreviews();
        _recurringConfig = null;
        final config = await _billing.config(authenticated: true);
        if (_current(work)) _recurringConfig = _object(config);
      }, billing: true);

  Future<void> ensureRecurringOptions() async {
    final pending = _flights['recurringOptions'];
    if (pending != null) {
      await pending;
    } else if (!_recurringOptionsAttempted) {
      await refreshRecurringOptions();
    }
  }

  Future<Map<int, RecurringPlanQuote>> quotePlans({
    required int paymentId,
    required String period,
    bool refresh = false,
  }) async {
    final epoch = _epoch;
    final generation = api.generation;
    bool accountCurrent() =>
        !_disposed &&
        _authenticated &&
        _epoch == epoch &&
        api.generation == generation;
    if (!accountCurrent()) throw const ClientFailure('unauthenticated');
    if (!checkout.allowStripe) throw const ClientFailure('payment_disallowed');
    await ensureRecurringOptions();
    if (!accountCurrent()) throw const ClientFailure('superseded');
    if (!recurringMethods.any((method) => method['id'] == paymentId)) {
      throw const ClientFailure('recurring_unavailable');
    }
    final revision = _quoteRevision;
    final key = (epoch, generation, revision, paymentId, period);
    final active = _quoteFlights[key];
    if (active != null) return active;
    final cached = _quoteCache[key];
    if (!refresh &&
        cached != null &&
        cached.isNotEmpty &&
        cached.values.every(
          (option) => option.quote?.validAt(DateTime.now()) == true,
        )) {
      return cached;
    }
    late final Future<Map<int, RecurringPlanQuote>> operation;
    operation =
        Future<Map<int, RecurringPlanQuote>>.sync(() async {
          final quotes = await _billing.quotePlans(
            paymentId: paymentId,
            period: period,
          );
          if (!accountCurrent() || _quoteRevision != revision) {
            throw const ClientFailure('superseded');
          }
          _quoteCache[key] = quotes;
          return quotes;
        }).whenComplete(() {
          if (identical(_quoteFlights[key], operation)) {
            _quoteFlights.remove(key);
          }
        });
    _quoteFlights[key] = operation;
    return operation;
  }

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
      if (_current(work)) {
        _clearQuotePreviews();
        await _loadBilling(work);
      }
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
    _singlePaymentOrders.add(trade);
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
        if (_recurringTerms[tradeNo] == null) {
          await ensureRecurringOptions();
          if (!_current(work)) return;
        }
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
    if (checkout.stage == CheckoutStage.completed) {
      await _reconcilePayment(work);
    } else if (checkout.stage == CheckoutStage.cancelled) {
      await refresh();
    }
    if (!_current(work)) return;
    if (checkout.failure != null && checkout.stage != CheckoutStage.completed) {
      throw ClientFailure(
        checkout.failure!,
        serverMessage: checkout.failureMessage,
      );
    }
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

({ZolnitClientBundle bundle, List<ZolnitNode> nodes}) _parseClientBundle(
  ({Json raw, DateTime now, String? accountId, List<Json> panelNodes}) input,
) {
  final bundle = ZolnitClientBundle.parse(
    input.raw,
    now: input.now,
    expectedAccountId: input.accountId,
  );
  final panel = <String, Json>{
    for (final node in input.panelNodes)
      if (node['type'] is String && (node['id'] is int || node['id'] is String))
        '${node['type']}:${node['id']}': node,
  };
  final countries = {
    for (final node in bundle.routingManifest.nodes) node.id: node.countryCode,
  };
  final nodes = <ZolnitNode>[
    for (final outbound in bundle.outbounds)
      ZolnitNode(
        id: outbound.id,
        name: outbound.displayName,
        title: outbound.displayName,
        coreProxyName: outbound.proxyName,
        region: countries[outbound.id] ?? '',
        countryCode: countries[outbound.id],
        rate: decimalOrNull(panel[outbound.id]?['rate']) ?? 1,
        rateKnown: decimalOrNull(panel[outbound.id]?['rate']) != null,
        tags: textList(panel[outbound.id]?['tags']),
        online: flagOrNull(panel[outbound.id]?['is_online']),
      ),
  ];
  return (bundle: bundle, nodes: List.unmodifiable(nodes));
}
