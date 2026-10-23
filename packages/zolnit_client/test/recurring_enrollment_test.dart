import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

Json _offer() => {
  'available': true,
  'period': 'monthly',
  'months': 1,
  'currency': 'CNY',
  'charge_currency': 'SGD',
  'price_cents': 1000,
  'recurring_price_cents': 900,
  'handling_amount_cents': 10,
  'recurring_total_cents': 910,
  'charge_amount_cents': 180,
  'first_total_cents': 0,
  'first_charge_amount_cents': 0,
  'surplus_amount_cents': 1000,
  'surplus_credit_cents': 100,
  'quote_id': 4,
  'quote_expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
  'gift_replacement': false,
  'switch_immediately': true,
  'next_charge_at': null,
};

class _Platform implements CheckoutPlatform {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async => throw StateError('Hosted enrollment must not call native SDK');
}

void main() {
  late List<http.Request> requests;
  late ZolnitSessionController session;
  late ZolnitBillingClient billing;
  late _Platform platform;
  late Json offer;
  late Json config;
  bool approve = true;
  bool allowStripe = true;
  int quoteStatus = 200;
  int orderStatus = 200;
  int probeStatus = 200;
  int consentCount = 0;
  Completer<bool>? approval;
  Json? displayed;

  setUp(() {
    requests = [];
    offer = _offer();
    config = {
      'enabled': true,
      'configured': true,
      'channels': [
        {'id': 2, 'name': 'Stripe', 'enabled': true, 'configured': true},
      ],
    };
    approve = true;
    allowStripe = true;
    quoteStatus = orderStatus = probeStatus = 200;
    consentCount = 0;
    approval = null;
    displayed = null;
  });

  void build() {
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      clientPlatform: 'macos',
      distribution: 'direct',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        dynamic data;
        var status = 200;
        if (path.endsWith('/login')) {
          data = {'auth_data': 'Bearer fixture'};
        } else if (path.endsWith('/user/info')) {
          data = {'email': 'fixture@example.com'};
        } else if (path.endsWith('/getSubscribe')) {
          data = {'plan_id': 1};
        } else if (path.endsWith('/zolnit-stripe/config')) {
          data = config;
        } else if (path.endsWith('/zolnit-stripe/plans')) {
          status = quoteStatus;
          data = {
            'plans': [
              {
                'id': 3,
                'periods': [offer],
              },
            ],
          };
        } else if (path.endsWith('/recurring-orders')) {
          status = orderStatus;
          data = {'trade_no': 'monthlyA'};
        } else if (path.endsWith('/order/detail')) {
          data = {'trade_no': 'monthlyA', 'total_amount': 0};
        } else if (path.endsWith('/recurring-orders/monthlyA')) {
          status = probeStatus;
          data = {
            ...offer,
            'recurring': true,
            'trade_no': 'monthlyA',
            'payment_id': 2,
            'plan_id': 3,
            'total_cents': offer['recurring_total_cents'],
            'status': 0,
          };
        } else if (path.endsWith('/subscribe')) {
          data = {
            'checkout_mode': 'hosted',
            'checkout_url': 'https://checkout.stripe.com/pay/monthlyA',
            'session_id': 'cs_test_fixture',
            'contract_id': 5,
          };
        } else if (path.endsWith('/order/check')) {
          data = 0;
        } else {
          data = <Json>[];
        }
        return http.Response(jsonEncode({'data': data}), status);
      }),
    );
    Future<bool> confirm(Json terms) async {
      consentCount++;
      displayed = terms;
      return approval == null ? approve : approval!.future;
    }

    billing = ZolnitBillingClient(api);
    platform = _Platform();
    session = ZolnitSessionController(
      api: api,
      billing: billing,
      confirmRecurring: confirm,
      checkout: CheckoutController(
        backend: XboardCheckoutBackend(api, confirmRecurring: confirm),
        platform: platform,
        allowedHttpsOrigins: const {'https://checkout.stripe.com'},
        allowStripe: allowStripe,
      ),
    );
    addTearDown(session.dispose);
  }

  Future<void> login() => session.login('fixture@example.com', 'password123');
  List<http.Request> posts() => requests
      .where((r) => r.method == 'POST' && !r.url.path.endsWith('/login'))
      .toList();

  test(
    'quote and explicit consent create original recurring order before Hosted subscribe',
    () async {
      build();
      await login();
      await session.refreshRecurringOptions();
      expect(session.recurringMethods.single['id'], 2);
      final trade = await session.createMonthlyOrder(planId: 3, paymentId: 2);
      expect(trade, 'monthlyA');
      expect(displayed?['first_total_cents'], 0);
      expect(displayed?['total_cents'], 910);
      expect(displayed?['surplus_credit_cents'], 100);
      final quoteRequest = requests.singleWhere(
        (r) => r.url.path.endsWith('/zolnit-stripe/plans'),
      );
      expect(quoteRequest.url.queryParameters, {
        'payment_id': '2',
        'plan_id': '3',
        'period': 'monthly',
      });
      expect(quoteRequest.headers['Authorization'], 'Bearer fixture');
      expect(quoteRequest.headers['User-Agent'], startsWith('ZolNit/'));
      expect(quoteRequest.headers['X-ZolNit-Platform'], 'macos');
      expect(jsonDecode(posts().single.body), {
        'payment_id': 2,
        'plan_id': 3,
        'quote_id': 4,
        'consent': true,
      });
      expect(session.checkout.stage, CheckoutStage.idle);
      await session.payOrder(trade!, 2);
      expect(consentCount, 1);
      expect(posts().map((r) => r.url.path), [
        '/api/v1/zolnit-stripe/recurring-orders',
        '/api/v1/zolnit-stripe/subscribe',
      ]);
      expect(jsonDecode(posts().last.body), {
        'payment_id': 2,
        'plan_id': 3,
        'period': 'monthly',
        'quote_id': 4,
        'trade_no': 'monthlyA',
        'consent': true,
      });
      expect(platform.opened.single.host, 'checkout.stripe.com');
      expect(session.checkout.stage, CheckoutStage.awaitingPayment);
      expect(session.subscription?['plan_id'], 1);
    },
  );

  test('declined consent never creates an order or checkout', () async {
    approve = false;
    build();
    await login();
    expect(await session.createMonthlyOrder(planId: 3, paymentId: 2), isNull);
    expect(posts(), isEmpty);
    expect(platform.opened, isEmpty);
  });

  test('terms that differ at payment time are confirmed again', () async {
    build();
    await login();
    final trade = await session.createMonthlyOrder(planId: 3, paymentId: 2);
    expect(consentCount, 1);
    offer['first_charge_amount_cents'] = 90;
    await session.payOrder(trade!, 2);
    expect(consentCount, 2);
    expect(displayed?['first_charge_amount_cents'], 90);
    expect(posts().last.url.path, '/api/v1/zolnit-stripe/subscribe');
  });

  test('declining changed terms never reaches subscribe', () async {
    build();
    await login();
    final trade = await session.createMonthlyOrder(planId: 3, paymentId: 2);
    approve = false;
    offer['first_charge_amount_cents'] = 90;
    await session.payOrder(trade!, 2);
    expect(session.failure, 'recurring_consent_required');
    expect(posts().map((r) => r.url.path), [
      '/api/v1/zolnit-stripe/recurring-orders',
    ]);
    expect(platform.opened, isEmpty);
  });

  for (final failure in [
    'unavailable',
    'expired',
    'malformed',
    'http',
    'order-http',
    'unconfigured',
    'store',
  ]) {
    test('$failure blocks enrollment without ordinary fallback', () async {
      switch (failure) {
        case 'unavailable':
          offer['available'] = false;
        case 'expired':
          offer['quote_expires_at'] = 1;
        case 'malformed':
          offer['first_charge_amount_cents'] = '0';
        case 'http':
          quoteStatus = 503;
        case 'order-http':
          orderStatus = 409;
        case 'unconfigured':
          config['configured'] = false;
        case 'store':
          allowStripe = false;
      }
      build();
      await login();
      expect(await session.createMonthlyOrder(planId: 3, paymentId: 2), isNull);
      expect(session.failure, isNotNull);
      expect(platform.opened, isEmpty);
      expect(
        posts().where((r) => !r.url.path.endsWith('/recurring-orders')),
        isEmpty,
      );
      expect(posts(), hasLength(failure == 'order-http' ? 1 : 0));
    });
  }

  test('logout during consent discards quote without side effects', () async {
    approval = Completer<bool>();
    build();
    await login();
    final operation = session.createMonthlyOrder(planId: 3, paymentId: 2);
    while (consentCount == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await session.logout();
    approval!.complete(true);
    expect(await operation, isNull);
    expect(posts(), isEmpty);
    expect(session.authenticated, isFalse);
  });

  test(
    'reentrant enrollment is single flight and known trade never becomes ordinary',
    () async {
      build();
      await login();
      final trades = await Future.wait([
        session.createMonthlyOrder(planId: 3, paymentId: 2),
        session.createMonthlyOrder(planId: 3, paymentId: 2),
      ]);
      expect(trades, ['monthlyA', 'monthlyA']);
      expect(posts(), hasLength(1));
      probeStatus = 404;
      await session.payOrder('monthlyA', 2);
      expect(session.checkout.stage, CheckoutStage.failed);
      expect(posts(), hasLength(1));
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'quote cannot be reused for a changed account or without consent',
    () async {
      build();
      await login();
      final quote = await billing.monthlyQuote(paymentId: 2, planId: 3);
      await expectLater(
        billing.createRecurringOrder(quote, consent: false),
        throwsA(isA<ClientFailure>()),
      );
      await session.logout();
      await expectLater(
        billing.createRecurringOrder(quote, consent: true),
        throwsA(isA<ClientFailure>()),
      );
      expect(posts(), isEmpty);
    },
  );
}
