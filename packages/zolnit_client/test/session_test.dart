import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

class _Backend implements CheckoutBackend {
  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async =>
      const StatusOnlyCheckout();

  @override
  Future<int> status(String tradeNo) async => 0;
}

class _Platform implements CheckoutPlatform {
  @override
  Future<bool> open(Uri uri) async => true;

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async {}
}

class _Checkout extends CheckoutController {
  _Checkout({super.allowStripe = true})
    : super(
        backend: _Backend(),
        platform: _Platform(),
        allowedHttpsOrigins: const {},
      );

  CheckoutStage value = CheckoutStage.idle;
  String? trade;
  int starts = 0;
  int refreshes = 0;
  int disposals = 0;
  int status = 0;
  Completer<void>? pendingStart;

  @override
  CheckoutStage get stage => value;

  @override
  String? get tradeNo => trade;

  @override
  Future<void> start(
    String tradeNo,
    int methodId, {
    Json? recurringTerms,
  }) async {
    starts++;
    trade = tradeNo;
    value = CheckoutStage.awaitingPayment;
    notifyListeners();
    await pendingStart?.future;
  }

  @override
  Future<void> refresh() async {
    refreshes++;
    value = status == 3
        ? CheckoutStage.completed
        : CheckoutStage.awaitingPayment;
    notifyListeners();
  }

  @override
  void reset() {
    trade = null;
    value = CheckoutStage.idle;
    super.reset();
  }

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

class _Http extends MockClient {
  _Http(super.handler);

  int closes = 0;

  @override
  void close() {
    closes++;
    super.close();
  }
}

class _Vault implements ZolnitSessionVault {
  String? value;
  Completer<void>? pendingWrite;
  Completer<void>? pendingRead;
  Completer<void>? pendingDelete;
  final deleteStarted = Completer<void>();

  @override
  Future<void> deleteAuthorization() async {
    if (!deleteStarted.isCompleted) deleteStarted.complete();
    await pendingDelete?.future;
    value = null;
  }

  @override
  Future<String?> readAuthorization() async {
    await pendingRead?.future;
    return value;
  }

  @override
  Future<void> writeAuthorization(String authorization) async {
    await pendingWrite?.future;
    value = authorization;
  }
}

http.Response _data(dynamic data) =>
    http.Response(jsonEncode({'data': data}), 200);

class _Fixture {
  _Fixture({
    bool allowStripe = true,
    this.vault,
    Future<void> Function()? onAuthenticationInvalidated,
  }) : checkout = _Checkout(allowStripe: allowStripe) {
    httpClient = _Http((request) async {
      requests.add(request);
      final custom = override;
      if (custom != null) {
        final result = await custom(request);
        if (result != null) return result;
      }
      final path = request.url.path;
      if (path.endsWith('/login')) {
        return _data({'auth_data': 'Bearer placeholder'});
      }
      if (path.endsWith('/info')) return _data({'email': 'student@example'});
      if (path.endsWith('/getSubscribe')) {
        return _data({'plan_id': 1, 'expired_at': expiry});
      }
      if (path.endsWith('/plan/fetch')) {
        return _data([
          {
            'id': 1,
            'month_price': 1200,
            'quarter_price': 3300,
            'half_year_price': null,
            'year_price': 10000,
            'two_year_price': 18000,
            'three_year_price': 25000,
            'onetime_price': 20000,
            'reset_price': 300,
          },
        ]);
      }
      if (path.endsWith('/subscriptions')) {
        return _data({
          'subscriptions': [
            {
              'id': 7,
              'can_cancel': !cancelled,
              'can_resume': cancelled,
              'paid_through': 400,
              'next_renewal_at': cancelled ? null : 400,
            },
          ],
          'entitlement': {
            'source': 'server',
            'label': 'Plan',
            'expires_at': 400,
          },
        });
      }
      if (path.endsWith('/7/cancel')) {
        cancelled = true;
        return _data(<String, dynamic>{});
      }
      if (path.endsWith('/7/resume')) {
        cancelled = false;
        return _data(<String, dynamic>{});
      }
      if (path.endsWith('/order/save')) return _data('original-trade');
      if (path.endsWith('/order/cancel')) return _data(true);
      return _data([]);
    });
    api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: httpClient,
    );
    session = ZolnitSessionController(
      api: api,
      billing: ZolnitBillingClient(api),
      checkout: checkout,
      vault: vault,
      onAuthenticationInvalidated: onAuthenticationInvalidated,
    );
  }

  final _Checkout checkout;
  final requests = <http.Request>[];
  late final _Http httpClient;
  late final XboardClient api;
  late final ZolnitSessionController session;
  Future<http.Response?> Function(http.Request)? override;
  final _Vault? vault;
  bool cancelled = false;
  int expiry = 100;

  int count(String suffix) =>
      requests.where((r) => r.url.path.endsWith(suffix)).length;

  Future<void> login() => session.login('student@example', 'test-password');
}

void main() {
  late _Fixture fixture;

  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.session.dispose());

  test(
    'constructor is offline; login accepts no account id and empty nodes',
    () async {
      final session = fixture.session;
      expect(fixture.requests, isEmpty);
      expect(session.authenticated, isFalse);
      await fixture.login();
      expect(session.authenticated, isTrue);
      expect(session.account, {'email': 'student@example'});
      expect(session.nodes, isEmpty);
      expect(session.failure, isNull);
      expect(session.plans.single['month_price'], 1200);
      expect(session.plans.single['three_year_price'], 25000);
      expect(session.plans.single['half_year_price'], isNull);
      expect(fixture.count('/subscriptions'), 0);
      expect(fixture.checkout.starts, 0);
      expect(
        fixture.requests
            .skip(1)
            .every((r) => r.headers['Authorization'] == 'Bearer placeholder'),
        isTrue,
      );
    },
  );

  test('restore queues behind pending logout deletion', () async {
    final gate = Completer<void>();
    final vault = _Vault()
      ..value = 'Bearer old'
      ..pendingDelete = gate;
    final client = _Fixture(vault: vault);
    addTearDown(client.session.dispose);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final logout = client.session.logout();
    await vault.deleteStarted.future;
    final restoring = client.session.restore();
    await Future<void>.delayed(Duration.zero);
    expect(client.session.authenticated, isFalse);
    expect(client.requests, isEmpty);
    gate.complete();
    await logout;
    await restoring;
    expect(client.session.restoreState, ZolnitRestoreState.signedOut);
    expect(vault.value, isNull);
  });

  test('an expired restore cannot overwrite a replacement login', () async {
    final gate = Completer<void>();
    final vault = _Vault()
      ..value = 'Bearer expired'
      ..pendingDelete = gate;
    final client = _Fixture(vault: vault);
    addTearDown(client.session.dispose);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    var replacement = false;
    client.override = (request) async =>
        request.url.path.endsWith('/info') && !replacement
        ? http.Response('unauthorized', 401)
        : null;
    final restoring = client.session.restore();
    await vault.deleteStarted.future;
    replacement = true;
    final login = client.login();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await restoring;
    await login;
    expect(client.session.authenticated, isTrue);
    expect(client.session.restoreState, ZolnitRestoreState.signedIn);
    expect(client.session.failure, isNull);
    expect(vault.value, 'Bearer placeholder');
  });

  test(
    'a rejected replacement login removes the preceding saved account',
    () async {
      final vault = _Vault()..value = 'Bearer preceding';
      final client = _Fixture(vault: vault);
      addTearDown(client.session.dispose);
      await client.session.restore();
      client.override = (request) async => request.url.path.endsWith('/login')
          ? http.Response('unauthorized', 401)
          : null;
      await client.session.login('other@example', 'fixture-rejected');
      expect(client.session.authenticated, isFalse);
      expect(vault.value, isNull);
    },
  );

  test('logout discards a pending secure-store read', () async {
    final gate = Completer<void>();
    final vault = _Vault()
      ..value = 'Bearer old'
      ..pendingRead = gate;
    final client = _Fixture(vault: vault);
    addTearDown(client.session.dispose);
    final restoring = client.session.restore();
    await Future<void>.delayed(Duration.zero);
    final logout = client.session.logout();
    gate.complete();
    await restoring;
    await logout;
    expect(client.session.authenticated, isFalse);
    expect(client.requests, isEmpty);
    expect(vault.value, isNull);
  });

  test('restores a saved authorization into a new controller', () async {
    final vault = _Vault()..value = 'Bearer restored';
    final restored = _Fixture(vault: vault);
    addTearDown(restored.session.dispose);

    await restored.session.restore();

    expect(restored.session.authenticated, isTrue);
    expect(restored.session.account?['email'], 'student@example');
    expect(
      restored.requests.any((request) => request.url.path.endsWith('/info')),
      isTrue,
    );
  });

  test('restore keeps a signed-in controller and its snapshots', () async {
    final vault = _Vault();
    final client = _Fixture(vault: vault);
    addTearDown(client.session.dispose);
    await client.login();
    final count = client.requests.length;
    vault.value = null;
    await client.session.restore();
    expect(client.requests, hasLength(count));
    expect(client.session.authenticated, isTrue);
    expect(client.session.restoreState, ZolnitRestoreState.signedIn);
    expect(client.session.account?['email'], 'student@example');
  });

  test('close keeps the saved authorization but logout removes it', () async {
    final vault = _Vault();
    final signedIn = _Fixture(vault: vault);
    await signedIn.login();
    expect(vault.value, 'Bearer placeholder');
    signedIn.session.dispose();
    expect(vault.value, 'Bearer placeholder');

    final restored = _Fixture(vault: vault);
    addTearDown(restored.session.dispose);
    await restored.session.restore();
    unawaited(restored.session.logout());
    await Future<void>.delayed(Duration.zero);
    expect(vault.value, isNull);
  });

  test(
    'network and subscription failures retain a restorable authorization',
    () async {
      final vault = _Vault()..value = 'Bearer retained';
      final restored = _Fixture(vault: vault);
      addTearDown(restored.session.dispose);
      restored.override = (request) async => request.url.path.endsWith('/info')
          ? http.Response('offline', 503)
          : null;

      await restored.session.restore();

      expect(restored.session.authenticated, isFalse);
      expect(restored.session.failure, 'api_error');
      expect(vault.value, 'Bearer retained');
    },
  );

  test(
    'explicit authentication failure removes a saved authorization',
    () async {
      final vault = _Vault()..value = 'Bearer expired';
      final restored = _Fixture(vault: vault);
      addTearDown(restored.session.dispose);
      restored.override = (request) async => request.url.path.endsWith('/info')
          ? http.Response('unauthorized', 401)
          : null;

      await restored.session.restore();

      expect(restored.session.failure, 'unauthenticated');
      expect(vault.value, isNull);
    },
  );

  test(
    'subscription 403 does not remove a valid saved authorization',
    () async {
      final vault = _Vault()..value = 'Bearer retained';
      final restored = _Fixture(vault: vault);
      addTearDown(restored.session.dispose);
      restored.override = (request) async =>
          request.url.path.endsWith('/getSubscribe')
          ? http.Response('forbidden', 403)
          : null;

      await restored.session.restore();

      expect(restored.session.restoreState, ZolnitRestoreState.offline);
      expect(vault.value, 'Bearer retained');
    },
  );

  test(
    'an authenticated user-info 401 expires and deletes the token',
    () async {
      final vault = _Vault();
      final signedIn = _Fixture(vault: vault);
      addTearDown(signedIn.session.dispose);
      await signedIn.login();
      signedIn.override = (request) async => request.url.path.endsWith('/info')
          ? http.Response('unauthorized', 401)
          : null;

      await signedIn.session.refresh();

      expect(signedIn.session.authenticated, isFalse);
      expect(signedIn.session.restoreState, ZolnitRestoreState.expired);
      expect(signedIn.session.failure, 'unauthenticated');
      expect(vault.value, isNull);
    },
  );

  test('auth expiry requests shutdown before slow storage deletion', () async {
    final vault = _Vault();
    final ownerCalled = Completer<void>();
    final client = _Fixture(
      vault: vault,
      onAuthenticationInvalidated: () async {
        ownerCalled.complete();
        throw const ClientFailure('owner_failure');
      },
    );
    addTearDown(client.session.dispose);
    await client.login();
    final deletion = Completer<void>();
    vault.pendingDelete = deletion;
    client.override = (request) async => request.url.path.endsWith('/info')
        ? http.Response('unauthorized', 401)
        : null;
    final refresh = client.session.refresh();
    await ownerCalled.future;
    expect(client.session.authenticated, isFalse);
    expect(client.session.restoreState, ZolnitRestoreState.expired);
    expect(vault.value, isNotNull);
    deletion.complete();
    await refresh;
    expect(vault.value, isNull);
    expect(client.session.failure, 'unauthenticated');
  });

  test(
    'logout deletion completes after dispose and cannot be overwritten',
    () async {
      final pendingWrite = Completer<void>();
      final vault = _Vault()
        ..value = 'Bearer old'
        ..pendingWrite = pendingWrite;
      final signedIn = _Fixture(vault: vault);

      final login = signedIn.login();
      await Future<void>.delayed(Duration.zero);
      final logout = signedIn.session.logout();
      signedIn.session.dispose();
      pendingWrite.complete();
      await login;
      await logout;

      expect(vault.value, isNull);
    },
  );

  test('a late login write cannot restore a session after logout', () async {
    final pendingWrite = Completer<void>();
    final vault = _Vault()..pendingWrite = pendingWrite;
    final signedIn = _Fixture(vault: vault);
    addTearDown(signedIn.session.dispose);

    final login = signedIn.login();
    await Future<void>.delayed(Duration.zero);
    unawaited(signedIn.session.logout());
    pendingWrite.complete();
    await login;
    await Future<void>.delayed(Duration.zero);

    expect(signedIn.session.authenticated, isFalse);
    expect(vault.value, isNull);
  });

  test(
    'missing or invalid auth_data and malformed lists fail closed',
    () async {
      for (final auth in [null, '', 'not bearer']) {
        fixture.override = (r) async =>
            r.url.path.endsWith('/login') ? _data({'auth_data': auth}) : null;
        await fixture.login();
        expect(fixture.session.authenticated, isFalse);
        expect(fixture.session.failure, 'invalid_authorization');
      }
      fixture.override = (r) async =>
          r.url.path.endsWith('/server/fetch') ? _data([null]) : null;
      await fixture.login();
      expect(fixture.session.authenticated, isFalse);
      expect(fixture.session.account, isNull);
      expect(fixture.session.failure, 'invalid_response');
    },
  );

  test(
    'login and refresh are single flight during reentrant notification',
    () async {
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        if (r.url.path.endsWith('/info')) {
          if (!entered.isCompleted) entered.complete();
          return response.future;
        }
        return null;
      };
      final login = fixture.login();
      expect(identical(login, fixture.login()), isTrue);
      await entered.future;
      response.complete(_data({'email': 'student@example'}));
      await login;
      fixture.override = null;
      var reentered = false;
      fixture.session.addListener(() {
        if (fixture.session.busy && !reentered) {
          reentered = true;
          unawaited(fixture.session.refresh());
        }
      });
      final refresh = fixture.session.refresh();
      expect(identical(refresh, fixture.session.refresh()), isTrue);
      await refresh;
      expect(fixture.count('/info'), 2);
      expect(fixture.count('/getSubscribe'), 2);
      expect(fixture.session.busy, isFalse);
    },
  );

  test(
    'logout and a new login discard pending previous account reads',
    () async {
      await fixture.login();
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        if (r.url.path.endsWith('/info') && !entered.isCompleted) {
          entered.complete();
          return response.future;
        }
        return null;
      };
      final pending = fixture.session.refresh();
      await entered.future;
      unawaited(fixture.session.logout());
      expect(fixture.session.account, isNull);
      expect(fixture.session.orders, isEmpty);
      expect(fixture.session.billingOverview, isNull);
      await fixture.login();
      response.complete(_data({'email': 'previous-account'}));
      await pending;
      expect(fixture.session.account!['email'], 'student@example');
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.failure, isNull);
    },
  );

  test(
    'logout during pending login never restores bearer or account',
    () async {
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        entered.complete();
        return response.future;
      };
      final login = fixture.login();
      await entered.future;
      unawaited(fixture.session.logout());
      response.complete(_data({'auth_data': 'Bearer late'}));
      await login;
      expect(fixture.session.authenticated, isFalse);
      expect(fixture.session.account, isNull);
      await expectLater(
        fixture.api.account(),
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'unauthenticated'),
        ),
      );
    },
  );

  test('billing outage preserves good login and core data', () async {
    fixture.override = (r) async => r.url.path.contains('zolnit-stripe')
        ? http.Response('sensitive response', 503)
        : null;
    await fixture.login();
    final account = fixture.session.account;
    await fixture.session.refreshBilling();
    expect(fixture.session.authenticated, isTrue);
    expect(fixture.session.account, same(account));
    expect(fixture.session.failure, isNull);
    expect(fixture.session.billingFailure, 'api_error');
    fixture.override = null;
    await fixture.session.refreshBilling();
    expect(fixture.session.billingFailure, isNull);
    expect(fixture.session.billingOverview!['entitlement']['source'], 'server');
  });

  test(
    'renewal actions reload server overview and do not claim failed changes',
    () async {
      await fixture.login();
      await fixture.session.cancelRenewal(7);
      expect(fixture.count('/7/cancel'), 1);
      expect(fixture.count('/subscriptions'), 1);
      expect(
        fixture.session.billingOverview!['subscriptions'][0]['can_resume'],
        true,
      );
      await fixture.session.resumeRenewal(7);
      expect(fixture.count('/7/resume'), 1);
      expect(fixture.count('/subscriptions'), 2);
      expect(
        fixture.session.billingOverview!['subscriptions'][0]['can_cancel'],
        true,
      );
      final overview = fixture.session.billingOverview;
      fixture.override = (r) async => r.url.path.endsWith('/7/cancel')
          ? http.Response('unavailable', 503)
          : null;
      await fixture.session.cancelRenewal(7);
      expect(fixture.session.billingFailure, 'api_error');
      expect(fixture.session.billingOverview, same(overview));
      expect(fixture.count('/subscriptions'), 2);
    },
  );

  test(
    'checkout keeps original order and reconciles only server status 3 once',
    () async {
      await fixture.login();
      final trade = await fixture.session.createOrder(
        planId: 1,
        period: 'month_price',
      );
      expect(trade, 'original-trade');
      expect(fixture.count('/order/fetch'), 2);
      final pendingStart = Completer<void>();
      fixture.checkout.pendingStart = pendingStart;
      final pay = fixture.session.payOrder(trade!, 2);
      final repeatedPay = fixture.session.payOrder(trade, 2);
      expect(identical(pay, repeatedPay), isTrue);
      await Future<void>.microtask(() {});
      pendingStart.complete();
      await pay;
      expect(fixture.checkout.trade, 'original-trade');
      expect(fixture.checkout.starts, 1);
      expect(fixture.count('/getSubscribe'), 1);
      await fixture.session.refreshPayment();
      expect(fixture.count('/getSubscribe'), 1);
      fixture.expiry = 200;
      fixture.checkout.status = 3;
      final refresh = fixture.session.refreshPayment();
      expect(identical(refresh, fixture.session.refreshPayment()), isTrue);
      await refresh;
      expect(fixture.session.subscription!['expired_at'], 200);
      expect(fixture.count('/getSubscribe'), 2);
      await fixture.session.refreshPayment();
      expect(fixture.count('/getSubscribe'), 2);
      expect(fixture.count('/order/save'), 1);
      expect(fixture.checkout.starts, 1);
      await fixture.session.cancelOrder(trade);
      expect(fixture.checkout.tradeNo, isNull);
      expect(fixture.count('/order/cancel'), 1);
      expect(fixture.count('/order/fetch'), 4);
    },
  );

  test(
    'a different pending plan is not silently joined to an existing order',
    () async {
      await fixture.login();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (request) async {
        if (!request.url.path.endsWith('/order/save')) return null;
        started.complete();
        return response.future;
      };
      final original = fixture.session.createOrder(
        planId: 1,
        period: 'month_price',
      );
      await started.future;
      expect(
        await fixture.session.createOrder(planId: 2, period: 'year_price'),
        isNull,
      );
      expect(fixture.session.failure, 'operation_in_progress');
      response.complete(_data('original-trade'));
      expect(await original, 'original-trade');
      expect(fixture.count('/order/save'), 1);
    },
  );

  test(
    'unready store channel keeps prices but blocks external paid side effects',
    () async {
      final restricted = _Fixture(allowStripe: false);
      addTearDown(restricted.session.dispose);
      await restricted.login();
      expect(restricted.session.plans.single['month_price'], 1200);
      expect(
        await restricted.session.createOrder(planId: 1, period: 'month_price'),
        isNull,
      );
      expect(restricted.session.failure, 'payment_disallowed');
      expect(restricted.count('/order/save'), 0);
      await restricted.session.resumeRenewal(7);
      expect(restricted.session.billingFailure, 'payment_disallowed');
      expect(restricted.count('/7/resume'), 0);
      await restricted.session.cancelRenewal(7);
      expect(restricted.count('/7/cancel'), 1);
    },
  );

  test(
    'signed-out lifecycle calls handle unauthenticated without network',
    () async {
      final session = fixture.session;
      await session.refresh();
      expect(session.failure, 'unauthenticated');
      await session.refreshPayment();
      await session.payOrder('original', 1);
      await session.cancelOrder('original');
      expect(
        await session.createOrder(planId: 1, period: 'month_price'),
        isNull,
      );
      await session.refreshBilling();
      expect(session.billingFailure, 'unauthenticated');
      await session.cancelRenewal(7);
      await session.resumeRenewal(7);
      expect(fixture.requests, isEmpty);
      unawaited(session.logout());
      expect(session.failure, isNull);
      expect(session.billingFailure, isNull);
      await fixture.login();
      expect(session.authenticated, isTrue);
    },
  );

  test(
    'failed order and cancellation never replace or reset tracked checkout',
    () async {
      await fixture.login();
      await fixture.session.payOrder('original-trade', 1);
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        if (r.url.path.endsWith('/order/cancel')) {
          entered.complete();
          return response.future;
        }
        if (r.url.path.endsWith('/order/save')) {
          return http.Response('private response', 503);
        }
        return null;
      };
      final cancel = fixture.session.cancelOrder('original-trade');
      expect(
        identical(cancel, fixture.session.cancelOrder('original-trade')),
        true,
      );
      await entered.future;
      response.complete(http.Response('private response', 503));
      await cancel;
      expect(fixture.session.failure, 'api_error');
      expect(fixture.checkout.tradeNo, 'original-trade');
      expect(fixture.count('/order/cancel'), 1);
      expect(
        await fixture.session.createOrder(planId: 1, period: 'month_price'),
        isNull,
      );
      expect(fixture.count('/order/save'), 1);
      expect(fixture.checkout.starts, 1);
    },
  );

  test('older failed refresh cannot erase a newer action error', () async {
    await fixture.login();
    final entered = Completer<void>();
    final response = Completer<http.Response>();
    fixture.override = (r) async {
      if (r.url.path.endsWith('/info')) {
        entered.complete();
        return response.future;
      }
      if (r.url.path.endsWith('/order/save')) {
        return http.Response('private response', 401);
      }
      return null;
    };
    final refresh = fixture.session.refresh();
    await entered.future;
    await fixture.session.createOrder(planId: 1, period: 'month_price');
    expect(fixture.session.failure, 'unauthenticated');
    response.complete(http.Response('private response', 503));
    await refresh;
    expect(fixture.session.failure, 'unauthenticated');
  });

  test(
    'API generation changes and logout discard pending billing overview',
    () async {
      await fixture.login();
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        if (r.url.path.endsWith('/subscriptions')) {
          entered.complete();
          return response.future;
        }
        return null;
      };
      final refresh = fixture.session.refreshBilling();
      await entered.future;
      fixture.api.setAuthorization('Bearer different');
      unawaited(fixture.session.logout());
      response.complete(
        _data({
          'subscriptions': [],
          'entitlement': {'source': 'previous-account'},
        }),
      );
      await refresh;
      expect(fixture.session.billingOverview, isNull);
      expect(fixture.session.billingFailure, isNull);
      expect(fixture.session.failure, isNull);
    },
  );

  test(
    'dispose once drops pending work and releases owned dependencies',
    () async {
      await fixture.login();
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.override = (r) async {
        if (r.url.path.endsWith('/info')) {
          entered.complete();
          return response.future;
        }
        return null;
      };
      var notices = 0;
      fixture.session.addListener(() => notices++);
      final pending = fixture.session.refresh();
      await entered.future;
      fixture.session.dispose();
      final before = notices;
      fixture.session.dispose();
      response.complete(_data({'email': 'late'}));
      await pending;
      await fixture.session.refresh();
      expect(notices, before);
      expect(fixture.session.account, isNull);
      expect(fixture.session.busy, isFalse);
      expect(fixture.httpClient.closes, 1);
      expect(fixture.checkout.disposals, 1);
    },
  );

  test(
    'typed lists follow the panel and are rebuilt only on refresh',
    () async {
      fixture.override = (request) async {
        final path = request.url.path;
        if (path.endsWith('/notice/fetch')) {
          return _data([
            {
              'id': 1,
              'title': 'Maintenance',
              'content': '<p>Tonight</p>',
              'tags': ['news'],
              'created_at': 1700000000,
            },
            'not a notice',
          ]);
        }
        if (path.endsWith('/server/fetch')) {
          return _data([
            {'id': 5, 'name': 'Tokyo 01', 'rate': '1.5'},
          ]);
        }
        return null;
      };
      await fixture.login();
      final session = fixture.session;
      expect(session.noticeList.single.title, 'Maintenance');
      expect(session.noticeList.single.body, 'Tonight');
      expect(session.nodeList.single.countryCode, 'JP');
      expect(session.planList.single.prices['month_price'], 1200);
      expect(session.usage?.planId, 1);
      expect(identical(session.nodeList, session.nodeList), isTrue);
      final before = session.nodeList;
      await session.refresh();
      expect(identical(session.nodeList, before), isFalse);
    },
  );

  test('a failing notice request does not block sign-in', () async {
    fixture.override = (request) async =>
        request.url.path.endsWith('/notice/fetch')
        ? http.Response('{"message":"unavailable"}', 500)
        : null;
    await fixture.login();
    expect(fixture.session.authenticated, isTrue);
    expect(fixture.session.failure, isNull);
    expect(fixture.session.noticeList, isEmpty);
  });
}
