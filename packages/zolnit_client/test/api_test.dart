import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  final origin = Uri.parse('https://panel.example');
  test(
    'network failures from an old login session are superseded too',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final client = XboardClient(
        origin: origin,
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      client.setAuthorization('Bearer sessionA');
      final result = client.account();
      final assertion = expectLater(
        result,
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'superseded'),
        ),
      );
      await started.future;
      client.setAuthorization('Bearer sessionB');
      response.completeError(http.ClientException('old connection closed'));
      await assertion;
      client.close();
    },
  );
  test(
    'provides explicit platform context without changing existing checkout fields',
    () async {
      final client = XboardClient(
        origin: origin,
        clientPlatform: 'android',
        distribution: 'direct',
        client: MockClient((request) async {
          expect(request.headers['X-ZolNit-Platform'], 'android');
          expect(request.headers['X-ZolNit-Distribution'], 'direct');
          expect(jsonDecode(request.body), {'trade_no': 'orderA', 'method': 2});
          return http.Response('{"type":-1,"data":true}', 200);
        }),
      );
      client.setAuthorization('Bearer token');
      await client.checkout('orderA', 2);
      client.close();
    },
  );
  test('rejects insecure, credential-bearing or ambiguous API origins', () {
    for (final url in [
      'http://panel.example',
      'https://user:pass@panel.example',
      'https://panel.example/path',
      'https://panel.example?token=secret',
    ]) {
      expect(
        () => XboardClient(origin: Uri.parse(url)),
        throwsA(isA<ClientFailure>()),
      );
    }
  });

  test('uses Bearer headers, no redirects and no token in URLs', () async {
    final requests = <http.Request>[];
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': {'email': 'a@example.com'},
          }),
          200,
        );
      }),
    );
    client.setAuthorization('Bearer sessionA');
    await client.account();
    expect(requests.single.headers['Authorization'], 'Bearer sessionA');
    expect(
      requests.single.url.toString(),
      'https://panel.example/api/v1/user/info',
    );
    expect(requests.single.followRedirects, isFalse);
    client.close();
  });

  test('login never sends an existing account authorization', () async {
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'email': 'a@b.com',
          'password': 'secret',
        });
        return http.Response('{"data":{"auth_data":"Bearer token"}}', 200);
      }),
    );
    client.setAuthorization('Bearer sessionA');
    expect(
      (await client.login('a@b.com', 'secret'))['auth_data'],
      'Bearer token',
    );
    client.close();
  });

  test('old account responses cannot complete after account switch', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) {
        started.complete();
        return response.future;
      }),
    );
    client.setAuthorization('Bearer sessionA');
    final result = client.subscription();
    final assertion = expectLater(
      result,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
    await started.future;
    client.setAuthorization('Bearer sessionB');
    response.complete(http.Response('{"data":{"plan_id":1}}', 200));
    await assertion;
    client.close();
  });

  test('API errors never include returned secrets or stack traces', () async {
    final client = XboardClient(
      origin: origin,
      client: MockClient(
        (_) async => http.Response('{"message":"private-token-secret"}', 500),
      ),
    );
    client.setAuthorization('Bearer token');
    await expectLater(
      client.account(),
      throwsA(
        isA<ClientFailure>().having(
          (e) => e.toString(),
          'message',
          'ClientFailure(api_error)',
        ),
      ),
    );
    client.close();
  });

  for (final status in [401, 403, 404, 409, 500, 503]) {
    test(
      'HTTP $status retains safe metadata and existing error code',
      () async {
        final client = XboardClient(
          origin: origin,
          client: MockClient(
            (_) async => http.Response('private-response-secret', status),
          ),
        );
        addTearDown(client.close);
        client.setAuthorization('Bearer token');
        final code = {401, 403}.contains(status)
            ? 'unauthenticated'
            : 'api_error';
        await expectLater(
          client.account(),
          throwsA(
            isA<ClientFailure>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.statusCode, 'statusCode', status)
                .having((e) => e.toString(), 'message', 'ClientFailure($code)'),
          ),
        );
      },
    );
  }

  test('checkout preserves its nonstandard type/data envelope', () async {
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/user/order/detail') {
          expect(request.url.queryParameters, {'trade_no': 'orderA'});
          return http.Response('{"data":{"trade_no":"orderA"}}', 200);
        }
        if (request.url.path ==
            '/api/v1/zolnit-stripe/recurring-orders/orderA') {
          return http.Response('{}', 404);
        }
        expect(request.url.path, '/api/v1/user/order/checkout');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {'trade_no': 'orderA', 'method': 2});
        return http.Response(
          '{"type":1,"data":"https://checkout.stripe.com/pay"}',
          200,
        );
      }),
    );
    client.setAuthorization('Bearer token');
    final action = await XboardCheckoutBackend(client).start('orderA', 2);
    expect(action, isA<HostedCheckout>());
    client.close();
  });

  test('typed actions must belong to the requested order', () async {
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/user/order/detail') {
          return http.Response('{"data":{"trade_no":"orderA"}}', 200);
        }
        if (request.url.path ==
            '/api/v1/zolnit-stripe/recurring-orders/orderA') {
          return http.Response('{}', 404);
        }
        return http.Response(
          '{"type":3,"data":{"trade_no":"orderB","kind":"hosted","url":"https://checkout.stripe.com/pay"}}',
          200,
        );
      }),
    );
    client.setAuthorization('Bearer token');
    await expectLater(
      XboardCheckoutBackend(client).start('orderA', 2),
      throwsA(isA<ClientFailure>()),
    );
    client.close();
  });

  test('Apple endpoints are explicit, proof stays in POST body', () async {
    final client = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/client-billing/verify');
        expect(request.method, 'POST');
        expect(request.url.query, isEmpty);
        expect(jsonDecode(request.body)['verification_data'], 'signed-proof');
        return http.Response(
          '{"data":{"account_id":"a","product_id":"monthly","transaction_id":"tx1","applied":true}}',
          200,
        );
      }),
    );
    client.setAuthorization('Bearer token');
    final backend = XboardAppleBillingBackend(
      client,
      const AppleBillingPaths(
        prepare: '/api/v1/client-billing/prepare',
        verify: '/api/v1/client-billing/verify',
      ),
    );
    final result = await backend.verify(
      const ApplePurchaseProof(
        productId: 'monthly',
        transactionId: 'tx1',
        verificationData: 'signed-proof',
        source: 'app_store',
      ),
    );
    expect(result.applied, isTrue);
    client.close();
  });
}
