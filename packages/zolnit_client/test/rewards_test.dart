import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  test('requests use bearer, body and a stable idempotency header', () async {
    final seen = <http.Request>[];
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        seen.add(request);
        return http.Response(
          jsonEncode({
            'data': {
              'rewards': {'balance': 25},
            },
          }),
          200,
        );
      }),
    )..setAuthorization('Bearer sessionA');
    addTearDown(api.close);
    final rewards = ZolnitRewardsClient(api);
    final result = await rewards.redeem('example-card', 'attempt_123');
    await rewards.redeem('example-card', 'attempt_123');
    expect(result['rewards'], {'balance': 25});
    expect(seen, hasLength(2));
    for (final request in seen) {
      expect(request.headers['authorization'], 'Bearer sessionA');
      expect(request.headers['idempotency-key'], 'attempt_123');
      expect(jsonDecode(request.body), {'code': 'example-card'});
      expect(request.url.hasQuery, isFalse);
    }
  });

  test(
    'missing plugin is unavailable, authentication errors are preserved',
    () async {
      var status = 404;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (_) async => http.Response('{"message":"no"}', status),
        ),
      )..setAuthorization('Bearer sessionA');
      addTearDown(api.close);
      final rewards = ZolnitRewardsClient(api);
      expect(await rewards.giftCardsAvailable(), isFalse);
      status = 401;
      await expectLater(
        rewards.giftCardsAvailable(),
        throwsA(isA<ClientFailure>()),
      );
      status = 403;
      await expectLater(
        rewards.giftCardsAvailable(),
        throwsA(
          isA<ClientFailure>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    },
  );

  test('account changes discard a late response', () async {
    final response = Completer<http.Response>();
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((_) => response.future),
    )..setAuthorization('Bearer sessionA');
    addTearDown(api.close);
    final pending = ZolnitRewardsClient(api).check('example-card');
    api.setAuthorization('Bearer sessionB');
    response.complete(
      http.Response(
        '{"data":{"template":{"name":"Gift"},"can_redeem":true}}',
        200,
      ),
    );
    await expectLater(
      pending,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
  });

  test('offer sends canonical period and accepts no eligible amount', () async {
    late Uri uri;
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        uri = request.url;
        return http.Response('{"data":{"eligible":false}}', 200);
      }),
    )..setAuthorization('Bearer sessionA');
    addTearDown(api.close);
    final result = await ZolnitRewardsClient(
      api,
    ).referralOffer(planId: 7, period: 'monthly', recurring: false);
    expect(result['eligible'], isFalse);
    expect(uri.queryParameters, {
      'plan_id': '7',
      'period': 'monthly',
      'recurring': '0',
    });
  });

  test(
    'timeout retries use one key and return the actual blind-box result',
    () async {
      final keys = <String?>[];
      var calls = 0;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        timeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/check')) {
            return http.Response(
              '{"data":{"template":{"name":"Gift"},"can_redeem":true,"possible_rewards":[{"balance":1}]}}',
              200,
            );
          }
          keys.add(request.headers['idempotency-key']);
          if (++calls == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
          return http.Response('{"data":{"rewards":{"balance":42}}}', 200);
        }),
      )..setAuthorization('Bearer sessionA');
      addTearDown(api.close);
      final attempt = ZolnitGiftCardAttempt(ZolnitRewardsClient(api))
        ..edit('card');
      await attempt.check();
      await expectLater(
        attempt.redeem(),
        throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'timeout')),
      );
      attempt.edit('');
      expect(attempt.canRetry, isFalse);
      attempt.edit(' CARD ');
      expect(attempt.preview, isNull);
      expect(attempt.canRetry, isTrue);
      expect((await attempt.redeem())['rewards'], {'balance': 42});
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      await expectLater(attempt.redeem(), throwsA(isA<ClientFailure>()));
      attempt.edit('another-card');
      expect(attempt.preview, isNull);
      await attempt.check();
      await attempt.redeem();
      expect(keys.last, isNot(keys.first));
    },
  );

  test(
    'a second confirmation is blocked while the first is in flight',
    () async {
      final response = Completer<http.Response>();
      var redeemCalls = 0;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((request) {
          if (request.url.path.endsWith('/check')) {
            return Future.value(
              http.Response(
                '{"data":{"template":{"name":"Gift"},"can_redeem":true}}',
                200,
              ),
            );
          }
          redeemCalls++;
          return response.future;
        }),
      )..setAuthorization('Bearer sessionA');
      addTearDown(api.close);
      final attempt = ZolnitGiftCardAttempt(ZolnitRewardsClient(api))
        ..edit('card');
      await attempt.check();
      final first = attempt.redeem();
      await expectLater(attempt.redeem(), throwsA(isA<ClientFailure>()));
      response.complete(http.Response('{"data":{"rewards":{}}}', 200));
      await first;
      expect(redeemCalls, 1);
    },
  );

  test('editing the card discards a late preview', () async {
    final response = Completer<http.Response>();
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((_) => response.future),
    )..setAuthorization('Bearer sessionA');
    addTearDown(api.close);
    final attempt = ZolnitGiftCardAttempt(ZolnitRewardsClient(api))
      ..edit('one1');
    final check = attempt.check();
    attempt.edit('two2');
    response.complete(
      http.Response(
        '{"data":{"template":{"name":"Gift"},"can_redeem":true}}',
        200,
      ),
    );
    await expectLater(
      check,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
    expect(attempt.preview, isNull);
    await expectLater(attempt.redeem(), throwsA(isA<ClientFailure>()));
  });

  test('configured availability and conflict preserve HTTP status', () async {
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient(
        (request) async => request.url.path.endsWith('/config')
            ? http.Response(
                '{"data":{"enabled":true,"gift_card_enabled":true}}',
                200,
              )
            : http.Response('{"message":"conflict"}', 409),
      ),
    )..setAuthorization('Bearer sessionA');
    addTearDown(api.close);
    final rewards = ZolnitRewardsClient(api);
    expect(await rewards.giftCardsAvailable(), isTrue);
    await expectLater(
      rewards.redeem('CARD', 'attempt_123'),
      throwsA(isA<ClientFailure>().having((e) => e.statusCode, 'status', 409)),
    );
  });
}
