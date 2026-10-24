import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

Json _offer(String period, {int? expiresAt}) => {
  'available': true,
  'period': period,
  'months': {
    'monthly': 1,
    'quarterly': 3,
    'half_yearly': 6,
    'yearly': 12,
    'two_yearly': 24,
    'three_yearly': 36,
  }[period],
  'currency': 'CNY',
  'charge_currency': 'SGD',
  'price_cents': 1200,
  'recurring_price_cents': 1080,
  'handling_amount_cents': 20,
  'recurring_total_cents': 1100,
  'charge_amount_cents': 350,
  'first_total_cents': 700,
  'first_charge_amount_cents': 200,
  'surplus_amount_cents': 400,
  'surplus_credit_cents': 0,
  'quote_id': 31,
  'quote_expires_at':
      expiresAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
  'gift_replacement': false,
  'switch_immediately': true,
  'next_charge_at': null,
};

class _NoCheckout implements CheckoutBackend {
  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async =>
      throw StateError('Quote reading must not start checkout');
  @override
  Future<int> status(String tradeNo) async => 0;
}

class _NoPlatform implements CheckoutPlatform {
  int openings = 0;
  @override
  Future<bool> open(Uri uri) async {
    openings++;
    return true;
  }

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async => throw StateError('Quote reading must not call payment SDKs');
}

http.Response _data(Object? data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': data})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late ZolnitSessionController session;
  late ZolnitBillingClient billing;
  late _NoPlatform platform;
  late List<http.Request> requests;
  Completer<http.Response>? pending;
  Completer<http.Response>? pendingConfiguration;
  var configurationStatus = 200;
  Json? responseOverride;
  var quoteStatus = 200;
  var confirmations = 0;

  setUp(() async {
    requests = [];
    pending = null;
    pendingConfiguration = null;
    configurationStatus = 200;
    responseOverride = null;
    quoteStatus = 200;
    confirmations = 0;
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/login')) {
          return _data({'auth_data': 'Bearer fixture'});
        }
        if (path.endsWith('/user/info')) {
          return _data({'email': 'fixture@example.com'});
        }
        if (path.endsWith('/getSubscribe')) return _data({'plan_id': 1});
        if (path.endsWith('/zolnit-stripe/config')) {
          if (pendingConfiguration != null) return pendingConfiguration!.future;
          return _data({
            'enabled': true,
            'configured': true,
            'channels': [
              {'id': 9, 'name': 'Stripe', 'enabled': true, 'configured': true},
            ],
          }, configurationStatus);
        }
        if (path.endsWith('/zolnit-stripe/plans')) {
          if (pending != null) return pending!.future;
          final period = request.url.queryParameters['period'] ?? 'monthly';
          return _data(
            responseOverride ??
                {
                  'plans': [
                    {
                      'id': 1,
                      'periods': [_offer(period)],
                    },
                    {
                      'id': 2,
                      'periods': [_offer(period)],
                    },
                    {
                      'id': 7,
                      'periods': [
                        {
                          'period': period,
                          'available': false,
                          'unavailable_reason': 'pending_order',
                        },
                      ],
                    },
                  ],
                },
            quoteStatus,
          );
        }
        return _data(<Json>[]);
      }),
    );
    billing = ZolnitBillingClient(api);
    platform = _NoPlatform();
    session = ZolnitSessionController(
      api: api,
      billing: billing,
      confirmRecurring: (_) async {
        confirmations++;
        return false;
      },
      checkout: CheckoutController(
        backend: _NoCheckout(),
        platform: platform,
        allowedHttpsOrigins: const {'https://checkout.stripe.com'},
        allowStripe: true,
      ),
    );
    await session.login('fixture@example.com', 'password123');
    expect(session.authenticated, isTrue);
  });
  tearDown(() => session.dispose());

  List<http.Request> quoteRequests() => requests
      .where((request) => request.url.path.endsWith('/zolnit-stripe/plans'))
      .toList();
  List<http.Request> writes() => requests
      .where(
        (request) =>
            request.method != 'GET' && !request.url.path.endsWith('/login'),
      )
      .toList();

  test(
    'batch preview reads every plan once without consent, order or checkout',
    () async {
      final result = await session.quotePlans(paymentId: 9, period: 'monthly');
      expect(result.keys, [1, 2, 7]);
      expect(result[1]!.quote!.terms['first_total_cents'], 700);
      expect(result[1]!.quote!.terms['total_cents'], 1100);
      expect(result[1]!.quote!.terms['recurring_price_cents'], 1080);
      expect(result[1]!.quote!.terms['surplus_amount_cents'], 400);
      expect(result[7]!.unavailableReason, 'pending_order');
      expect(result[7]!.quote, isNull);
      expect(quoteRequests().single.url.queryParameters, {
        'payment_id': '9',
        'period': 'monthly',
      });
      expect(writes(), isEmpty);
      expect(confirmations, 0);
      expect(platform.openings, 0);
      expect(session.checkout.stage, CheckoutStage.idle);
    },
  );

  test(
    'real unavailable reasons normalize to localized action codes',
    () async {
      for (final (reason, expected) in <(Object?, String)>[
        ('请先在‘我的订单’完成或取消待处理订单，再开通连续包月。', 'pending_order'),
        ('请先在“我的订单”完成或取消待处理订单，再开通连续包月。', 'pending_order'),
        ('请先在个人中心取消原套餐的自动续费，再开通新的连续包月。', 'active_subscription'),
        ('pending_order', 'pending_order'),
        ('unpaid_order', 'pending_order'),
        ('has_unpaid_orders', 'pending_order'),
        ('active_subscription', 'active_subscription'),
        ('existing_subscription', 'active_subscription'),
        ('checkout_exists', 'checkout_exists'),
        ('future_reason', 'recurring_unavailable'),
        ('未识别的服务端说明', 'recurring_unavailable'),
        (null, 'recurring_unavailable'),
        (3, 'recurring_unavailable'),
      ]) {
        responseOverride = {
          'plans': [
            {
              'id': 7,
              'periods': [
                {
                  'period': 'monthly',
                  'available': false,
                  'unavailable_reason': reason,
                },
              ],
            },
          ],
        };
        final result = await billing.quotePlans(
          paymentId: 9,
          period: 'monthly',
        );
        expect(result[7]!.quote, isNull);
        expect(result[7]!.unavailableReason, expected, reason: '$reason');
      }
      expect(writes(), isEmpty);
      expect(confirmations, 0);
      expect(platform.openings, 0);
    },
  );

  test(
    'concurrent readers coalesce; fresh complete quotes are cached per period',
    () async {
      responseOverride = {
        'plans': [
          {
            'id': 1,
            'periods': [_offer('monthly')],
          },
        ],
      };
      final values = await Future.wait([
        session.quotePlans(paymentId: 9, period: 'monthly'),
        session.quotePlans(paymentId: 9, period: 'monthly'),
      ]);
      expect(quoteRequests(), hasLength(1));
      expect(values[0][1]!.quote!.id, values[1][1]!.quote!.id);
      await session.quotePlans(paymentId: 9, period: 'monthly');
      expect(quoteRequests(), hasLength(1));
      await session.quotePlans(paymentId: 9, period: 'monthly', refresh: true);
      expect(quoteRequests(), hasLength(2));
      responseOverride = null;
      await session.quotePlans(paymentId: 9, period: 'quarterly');
      expect(quoteRequests(), hasLength(3));
      expect(quoteRequests().last.url.queryParameters['period'], 'quarterly');
      expect(writes(), isEmpty);
    },
  );

  test(
    'existing entry config hook and quote loader share one config request',
    () async {
      final options = session.refreshRecurringOptions();
      final quote = session.quotePlans(paymentId: 9, period: 'monthly');
      await options;
      await quote;
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/zolnit-stripe/config'),
        ),
        hasLength(1),
      );
      expect(quoteRequests(), hasLength(1));
    },
  );

  for (final status in [401, 403]) {
    test(
      'configuration failure $status preserves the authentication boundary',
      () async {
        configurationStatus = status;
        final generation = session.api.generation;
        await session.refreshRecurringOptions();
        expect(session.authenticated, status == 403);
        expect(
          session.api.generation,
          status == 401 ? greaterThan(generation) : generation,
        );
        expect(session.recurringMethods, isEmpty);
        expect(writes(), isEmpty);
      },
    );
  }

  for (final logout in [false, true]) {
    test(
      'late configuration cannot cross an account change (logout: $logout)',
      () async {
        final response = Completer<http.Response>();
        pendingConfiguration = response;
        final configuration = session.refreshRecurringOptions();
        await Future<void>.delayed(Duration.zero);
        expect(
          requests.where(
            (request) => request.url.path.endsWith('/zolnit-stripe/config'),
          ),
          hasLength(1),
        );
        if (logout) {
          await session.logout();
        } else {
          session.api.setAuthorization('Bearer next');
        }
        response.complete(
          _data({
            'enabled': true,
            'configured': true,
            'channels': [
              {
                'id': 9,
                'name': 'Old account',
                'enabled': true,
                'configured': true,
              },
            ],
          }),
        );
        await configuration;
        expect(session.recurringMethods, isEmpty);
        expect(session.authenticated, !logout);
        expect(writes(), isEmpty);
      },
    );
  }

  test(
    'logout rejects an in-flight response and never caches its account data',
    () async {
      await session.ensureRecurringOptions();
      final response = Completer<http.Response>();
      pending = response;
      final quote = session.quotePlans(paymentId: 9, period: 'monthly');
      final assertion = expectLater(
        quote,
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'superseded'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await session.logout();
      response.complete(
        _data({
          'plans': [
            {
              'id': 1,
              'periods': [_offer('monthly')],
            },
          ],
        }),
      );
      await assertion;
      expect(writes(), isEmpty);
      expect(session.authenticated, isFalse);
    },
  );

  test('plan refresh invalidates old quote responses and cache', () async {
    await session.ensureRecurringOptions();
    final response = Completer<http.Response>();
    pending = response;
    final quote = session.quotePlans(paymentId: 9, period: 'monthly');
    final assertion = expectLater(
      quote,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
    await Future<void>.delayed(Duration.zero);
    await session.refresh();
    response.complete(
      _data({
        'plans': [
          {
            'id': 1,
            'periods': [_offer('monthly')],
          },
        ],
      }),
    );
    await assertion;
    expect(writes(), isEmpty);
  });

  test(
    'permission failure retains status and does not become authentication failure',
    () async {
      quoteStatus = 403;
      await expectLater(
        session.quotePlans(paymentId: 9, period: 'monthly'),
        throwsA(
          isA<ClientFailure>()
              .having((e) => e.code, 'code', 'api_error')
              .having((e) => e.statusCode, 'status', 403),
        ),
      );
      expect(session.authenticated, isTrue);
      expect(session.checkout.stage, CheckoutStage.idle);
      expect(writes(), isEmpty);
    },
  );

  test(
    'batch rejects foreign period, duplicate plan or expired quote',
    () async {
      for (final body in [
        {
          'plans': [
            {
              'id': 1,
              'periods': [_offer('quarterly')],
            },
          ],
        },
        {
          'plans': [
            {
              'id': 1,
              'periods': [_offer('monthly')],
            },
            {
              'id': 1,
              'periods': [_offer('monthly')],
            },
          ],
        },
        {
          'plans': [
            {
              'id': 1,
              'periods': [_offer('monthly', expiresAt: 1)],
            },
          ],
        },
      ]) {
        responseOverride = body;
        await expectLater(
          billing.quotePlans(paymentId: 9, period: 'monthly'),
          throwsA(isA<ClientFailure>()),
        );
      }
    },
  );

  test(
    'unsupported price periods and signed-out previews do not reach quote API',
    () async {
      await expectLater(
        session.quotePlans(paymentId: 9, period: 'onetime_price'),
        throwsA(isA<ClientFailure>()),
      );
      expect(quoteRequests(), isEmpty);
      await session.logout();
      await expectLater(
        session.quotePlans(paymentId: 9, period: 'monthly'),
        throwsA(isA<ClientFailure>()),
      );
      expect(quoteRequests(), isEmpty);
      expect(writes(), isEmpty);
    },
  );
}
