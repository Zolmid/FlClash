import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  final origin = Uri.parse('https://panel.example');

  test(
    'config is public; other reads use Bearer and only supplied query',
    () async {
      final requests = <http.Request>[];
      final api = XboardClient(
        origin: origin,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"data":{}}', 200);
        }),
      );
      final billing = ZolnitBillingClient(api);
      await billing.config();
      api.setAuthorization('Bearer placeholderA');
      await billing.entitlement();
      await billing.plans();
      await billing.plans(planId: 3);
      await billing.plans(paymentId: 2, planId: 3, period: 'month_price');

      expect(requests.map((r) => r.url.path), [
        '/api/v1/zolnit-stripe/config',
        '/api/v1/zolnit-stripe/entitlement',
        '/api/v1/zolnit-stripe/plans',
        '/api/v1/zolnit-stripe/plans',
        '/api/v1/zolnit-stripe/plans',
      ]);
      expect(
        requests.every((r) => r.method == 'GET' && r.body.isEmpty),
        isTrue,
      );
      expect(requests.first.headers['Authorization'], isNull);
      expect(
        requests
            .skip(1)
            .every((r) => r.headers['Authorization'] == 'Bearer placeholderA'),
        isTrue,
      );
      expect(requests[2].url.queryParameters, isEmpty);
      expect(requests[3].url.queryParameters, {'plan_id': '3'});
      expect(requests[4].url.queryParameters, {
        'payment_id': '2',
        'plan_id': '3',
        'period': 'month_price',
      });
      api.close();
    },
  );

  test(
    'subscriptions require a list of objects and entitlement object',
    () async {
      var body = jsonEncode({
        'data': {
          'subscriptions': [
            {'id': 1, 'risk_hold': 1, 'cancel_at_period_end': false},
          ],
          'entitlement': {'source': 'gift', 'expires_at': 100},
        },
      });
      final requests = <http.Request>[];
      final api = XboardClient(
        origin: origin,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(body, 200);
        }),
      )..setAuthorization('Bearer placeholderA');
      final billing = ZolnitBillingClient(api);
      final result = await billing.subscriptions();
      expect(requests.single.url.path, '/api/v1/zolnit-stripe/subscriptions');
      expect(result['subscriptions'][0]['risk_hold'], 1);
      expect(result['entitlement'], {'source': 'gift', 'expires_at': 100});
      for (final invalid in [
        {'subscriptions': null, 'entitlement': <String, dynamic>{}},
        {
          'subscriptions': [1],
          'entitlement': <String, dynamic>{},
        },
        {'subscriptions': [], 'entitlement': null},
      ]) {
        body = jsonEncode({'data': invalid});
        await expectLater(
          billing.subscriptions(),
          throwsA(
            isA<ClientFailure>().having(
              (error) => error.code,
              'code',
              'invalid_billing_response',
            ),
          ),
        );
      }
      api.close();
    },
  );

  test(
    'cancel and resume use POST without body and preserve server fields',
    () async {
      final requests = <http.Request>[];
      final api = XboardClient(
        origin: origin,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'data': {
                'cancel_at_period_end': requests.length == 1,
                if (requests.length == 1) 'initial_order_canceled': true,
              },
            }),
            200,
          );
        }),
      )..setAuthorization('Bearer placeholderA');
      final billing = ZolnitBillingClient(api);
      expect(await billing.cancelSubscription(7), {
        'cancel_at_period_end': true,
        'initial_order_canceled': true,
      });
      expect(await billing.resumeSubscription(7), {
        'cancel_at_period_end': false,
      });
      expect(requests.map((r) => r.url.path), [
        '/api/v1/zolnit-stripe/subscriptions/7/cancel',
        '/api/v1/zolnit-stripe/subscriptions/7/resume',
      ]);
      expect(
        requests.every(
          (r) =>
              r.method == 'POST' &&
              r.body.isEmpty &&
              r.url.query.isEmpty &&
              r.headers['Authorization'] == 'Bearer placeholderA',
        ),
        isTrue,
      );
      api.close();
    },
  );

  test(
    'invalid IDs and malformed data never produce a usable response',
    () async {
      var calls = 0;
      var body = '{"data":null}';
      final api = XboardClient(
        origin: origin,
        client: MockClient((_) async {
          calls++;
          return http.Response(body, 200);
        }),
      )..setAuthorization('Bearer placeholderA');
      final billing = ZolnitBillingClient(api);
      for (final action in <Future<Json> Function()>[
        () => billing.plans(paymentId: 0),
        () => billing.plans(planId: -1),
        () => billing.cancelSubscription(0),
        () => billing.resumeSubscription(-1),
      ]) {
        await expectLater(action(), throwsA(isA<ClientFailure>()));
      }
      expect(calls, 0);
      for (final action in <Future<Json> Function()>[
        billing.config,
        billing.entitlement,
        billing.plans,
        billing.subscriptions,
        () => billing.cancelSubscription(1),
        () => billing.resumeSubscription(1),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<ClientFailure>().having(
              (error) => error.code,
              'code',
              'invalid_billing_response',
            ),
          ),
        );
      }
      body = '{"data":[]}';
      await expectLater(billing.config(), throwsA(isA<ClientFailure>()));
      body = '{}';
      await expectLater(
        billing.entitlement(),
        throwsA(
          isA<ClientFailure>().having(
            (error) => error.code,
            'code',
            'invalid_billing_response',
          ),
        ),
      );
      api.close();
    },
  );

  test('an account switch supersedes an in-flight subscription read', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = XboardClient(
      origin: origin,
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    )..setAuthorization('Bearer placeholderA');
    final result = ZolnitBillingClient(api).subscriptions();
    final assertion = expectLater(
      result,
      throwsA(
        isA<ClientFailure>().having(
          (error) => error.code,
          'code',
          'superseded',
        ),
      ),
    );
    await started.future;
    api.setAuthorization('Bearer placeholderB');
    response.complete(
      http.Response('{"data":{"subscriptions":[],"entitlement":{}}}', 200),
    );
    await assertion;
    api.close();
  });
}
