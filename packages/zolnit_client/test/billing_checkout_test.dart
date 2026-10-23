import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

const _detail = '/api/v1/user/order/detail';
const _probe = '/api/v1/zolnit-stripe/recurring-orders/orderA';
const _checkout = '/api/v1/user/order/checkout';
const _subscribe = '/api/v1/zolnit-stripe/subscribe';

Json _intent() => {
  'recurring': true,
  'trade_no': 'orderA',
  'payment_id': 2,
  'plan_id': 3,
  'quote_id': 4,
  'period': 'monthly',
  'status': 0,
  'price_cents': 900,
  'handling_amount_cents': 0,
  'total_cents': 900,
  'charge_amount_cents': 180,
  'charge_currency': 'SGD',
  'first_total_cents': 0,
  'first_charge_amount_cents': 0,
  'surplus_amount_cents': 900,
  'surplus_credit_cents': 100,
};

Json _hosted() => {
  'checkout_mode': 'hosted',
  'checkout_url': 'https://checkout.stripe.com/pay',
  'session_id': 'cs_test_session',
  'contract_id': 7,
};

http.Response _data(dynamic value) =>
    http.Response(jsonEncode({'data': value}), 200);

TypeMatcher<ClientFailure> _failure(String code) =>
    isA<ClientFailure>().having((e) => e.code, 'code', code);

class _Harness {
  _Harness({
    required Future<http.Response> Function(http.Request) probe,
    Future<bool> Function(Json)? confirm,
    dynamic detail = const {'trade_no': 'orderA', 'total_amount': 0},
    int detailStatus = 200,
    Json? ordinary,
    Json? subscribed,
  }) {
    api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case _detail:
            return http.Response(jsonEncode({'data': detail}), detailStatus);
          case _probe:
            return probe(request);
          case _checkout:
            return http.Response(
              jsonEncode(ordinary ?? {'type': -1, 'data': true}),
              200,
            );
          case _subscribe:
            return _data(subscribed ?? _hosted());
          case '/api/v1/user/order/check':
            return _data(0);
          default:
            return http.Response('{}', 500);
        }
      }),
    );
    api.setAuthorization('Bearer accountA');
    backend = XboardCheckoutBackend(api, confirmRecurring: confirm);
    addTearDown(api.close);
  }

  late final XboardClient api;
  late final XboardCheckoutBackend backend;
  final requests = <http.Request>[];

  List<String> get paths => requests.map((r) => r.url.path).toList();
  Iterable<http.Request> get posts => requests.where((r) => r.method == 'POST');
}

void main() {
  test(
    'known recurring order never falls back when its intent is missing',
    () async {
      final h = _Harness(probe: (_) async => http.Response('{}', 404));
      await expectLater(
        h.backend.startRecurring('orderA', 2, approvedTerms: _intent()),
        throwsA(isA<ClientFailure>()),
      );
      expect(h.paths, [_detail, _probe]);
      expect(h.posts, isEmpty);
    },
  );

  test(
    'owned detail then explicit 404 permits ordinary zero checkout',
    () async {
      final h = _Harness(probe: (_) async => http.Response('{}', 404));
      expect(await h.backend.start('orderA', 2), isA<StatusOnlyCheckout>());
      expect(h.paths, [_detail, _probe, _checkout]);
      expect(h.requests.take(2).map((r) => r.method), ['GET', 'GET']);
      expect(h.requests.first.url.queryParameters, {'trade_no': 'orderA'});
      expect(jsonDecode(h.posts.single.body), {
        'trade_no': 'orderA',
        'method': 2,
      });
    },
  );

  for (final status in [401, 403, 409, 500, 503]) {
    test('probe HTTP $status never falls back', () async {
      final h = _Harness(
        probe: (_) async => http.Response('private-error', status),
      );
      await expectLater(
        h.backend.start('orderA', 2),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.statusCode,
            'statusCode',
            status,
          ),
        ),
      );
      expect(h.paths, [_detail, _probe]);
      expect(h.posts, isEmpty);
    });
  }

  test('probe timeout never falls back', () async {
    final h = _Harness(probe: (_) async => throw TimeoutException('private'));
    await expectLater(
      h.backend.start('orderA', 2),
      throwsA(_failure('timeout')),
    );
    expect(h.paths, [_detail, _probe]);
    expect(h.posts, isEmpty);
  });

  for (final pendingPath in [_detail, _probe]) {
    test('account switch during $pendingPath prevents checkout', () async {
      final started = Completer<void>();
      final pending = Completer<http.Response>();
      final requests = <http.Request>[];
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == pendingPath) {
            started.complete();
            return pending.future;
          }
          return _data({'trade_no': 'orderA'});
        }),
      );
      addTearDown(api.close);
      api.setAuthorization('Bearer accountA');
      final result = XboardCheckoutBackend(api).start('orderA', 2);
      final assertion = expectLater(result, throwsA(_failure('superseded')));
      await started.future;
      api.setAuthorization('Bearer accountB');
      pending.complete(
        pendingPath == _probe
            ? http.Response('{}', 404)
            : _data({'trade_no': 'orderA'}),
      );
      await assertion;
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }

  for (final detail in [
    null,
    [],
    {},
    {'trade_no': 'foreign'},
  ]) {
    test('malformed or foreign detail $detail blocks even probe', () async {
      final h = _Harness(
        detail: detail,
        probe: (_) async => http.Response('{}', 404),
      );
      await expectLater(
        h.backend.start('orderA', 2),
        throwsA(_failure('invalid_billing_response')),
      );
      expect(h.paths, [_detail]);
      expect(h.posts, isEmpty);
    });
  }

  for (final status in [401, 403, 404, 409, 500]) {
    test('failed owned detail HTTP $status blocks probe and POST', () async {
      final h = _Harness(
        detailStatus: status,
        probe: (_) async => http.Response('{}', 404),
      );
      await expectLater(
        h.backend.start('orderA', 2),
        throwsA(isA<ClientFailure>()),
      );
      expect(h.paths, [_detail]);
      expect(h.posts, isEmpty);
    });
  }

  for (final tradeNo in ['', '../orderA', 'orderA/other', 'a?x', 'a%2fb']) {
    test('unsafe order identifier $tradeNo makes no request', () async {
      final h = _Harness(probe: (_) async => _data(_intent()));
      await expectLater(
        h.backend.start(tradeNo, 2),
        throwsA(_failure('invalid_path')),
      );
      expect(h.requests, isEmpty);
    });
  }

  test(
    'zero first cycle subscribes only after consent with exact IDs',
    () async {
      final consent = Completer<bool>();
      final confirming = Completer<void>();
      final intent = _intent();
      final h = _Harness(
        probe: (_) async => _data(intent),
        confirm: (received) {
          expect(received, intent);
          confirming.complete();
          return consent.future;
        },
      );
      final result = h.backend.start('orderA', 99);
      await confirming.future;
      expect(h.posts, isEmpty);
      consent.complete(true);
      final action = await result;
      expect(action, isA<HostedCheckout>());
      expect(h.paths, [_detail, _probe, _subscribe]);
      expect(jsonDecode(h.posts.single.body), {
        'payment_id': 2,
        'plan_id': 3,
        'period': 'monthly',
        'quote_id': 4,
        'trade_no': 'orderA',
        'consent': true,
      });
      expect(await h.backend.status('orderA'), 0);
      expect(h.paths.last, '/api/v1/user/order/check');
    },
  );

  for (final missing in [true, false]) {
    test('consent missing=$missing never posts', () async {
      final h = _Harness(
        probe: (_) async => _data(_intent()),
        confirm: missing ? null : (_) async => false,
      );
      await expectLater(
        h.backend.start('orderA', 2),
        throwsA(_failure('recurring_consent_required')),
      );
      expect(h.posts, isEmpty);
    });
  }

  for (final switchAccount in [false, true]) {
    test(
      'logout or account change during consent prevents POST $switchAccount',
      () async {
        final consent = Completer<bool>();
        final confirming = Completer<void>();
        final h = _Harness(
          probe: (_) async => _data(_intent()),
          confirm: (_) {
            confirming.complete();
            return consent.future;
          },
        );
        final result = h.backend.start('orderA', 2);
        final assertion = expectLater(result, throwsA(_failure('superseded')));
        await confirming.future;
        h.api.setAuthorization(null);
        if (switchAccount) h.api.setAuthorization('Bearer accountB');
        consent.complete(true);
        await assertion;
        expect(h.posts, isEmpty);
      },
    );
  }

  final badIntents = <dynamic>[
    null,
    [],
    {},
    {..._intent(), 'trade_no': 'foreign'},
    {..._intent(), 'recurring': false},
    {..._intent(), 'status': 1},
    {..._intent(), 'period': 'yearly'},
    {..._intent(), 'payment_id': 0},
    {..._intent(), 'plan_id': -1},
    {..._intent(), 'quote_id': '4'},
    {..._intent(), 'charge_currency': 'USD'},
    {..._intent(), 'first_total_cents': null},
    {..._intent(), 'first_charge_amount_cents': -1},
    {..._intent(), 'charge_amount_cents': '180'},
    {..._intent(), 'surplus_credit_cents': null},
  ];
  for (var i = 0; i < badIntents.length; i++) {
    test('malformed intent $i never confirms or posts', () async {
      var confirmed = false;
      final h = _Harness(
        probe: (_) async => _data(badIntents[i]),
        confirm: (_) async {
          confirmed = true;
          return true;
        },
      );
      await expectLater(
        h.backend.start('orderA', 2),
        throwsA(_failure('invalid_billing_response')),
      );
      expect(confirmed, isFalse);
      expect(h.posts, isEmpty);
    });
  }

  test('invalid JSON 200 is never treated as missing intent', () async {
    final h = _Harness(probe: (_) async => http.Response('not-json', 200));
    await expectLater(
      h.backend.start('orderA', 2),
      throwsA(_failure('invalid_response')),
    );
    expect(h.posts, isEmpty);
  });

  for (final mode in ['hosted', 'legacy_hosted']) {
    test(
      'ordinary type 1 $mode object parses without extension trade_no',
      () async {
        final h = _Harness(
          probe: (_) async => http.Response('{}', 404),
          ordinary: {
            'type': 1,
            'data': {..._hosted(), 'checkout_mode': mode},
          },
        );
        final action = (await h.backend.start('orderA', 2)) as HostedCheckout;
        expect(action.uri.toString(), 'https://checkout.stripe.com/pay');
      },
    );
  }

  for (final recurring in [true, false]) {
    test(
      'Embedded returns redacted unsupported error recurring=$recurring',
      () async {
        final embedded = {
          'checkout_mode': 'embedded',
          'client_secret': 'cs_test_session_secret_private',
          'session_id': 'cs_test_session',
        };
        final h = _Harness(
          probe: (_) async =>
              recurring ? _data(_intent()) : http.Response('{}', 404),
          confirm: (_) async => true,
          subscribed: embedded,
          ordinary: {'type': 1, 'data': embedded},
        );
        await expectLater(
          h.backend.start('orderA', 2),
          throwsA(
            _failure('unsupported_embedded_checkout').having(
              (e) => e.toString(),
              'redacted',
              'ClientFailure(unsupported_embedded_checkout)',
            ),
          ),
        );
        expect(h.posts.length, 1);
      },
    );
  }

  for (final secret in [
    'pi_example_secret_private',
    'cs_example_secret_private',
  ]) {
    test('Android typed extension accepts only pi secret $secret', () async {
      final h = _Harness(
        probe: (_) async => http.Response('{}', 404),
        ordinary: {
          'type': 3,
          'data': {
            'trade_no': 'orderA',
            'kind': 'stripe_android',
            'publishable_key': 'pk_test_example',
            'client_secret': secret,
            'wallet': 'card',
            'return_url': 'zolnit://safepay',
          },
        },
      );
      if (secret.startsWith('cs_')) {
        await expectLater(
          h.backend.start('orderA', 2),
          throwsA(_failure('invalid_stripe_action')),
        );
      } else {
        expect(await h.backend.start('orderA', 2), isA<StripeCheckout>());
      }
    });
  }

  test('typed QR and hosted extension preserve QR and order binding', () async {
    for (final kind in ['qr', 'hosted']) {
      final h = _Harness(
        probe: (_) async => http.Response('{}', 404),
        ordinary: {
          'type': 3,
          'data': {
            'trade_no': 'orderA',
            'kind': kind,
            'url': 'https://checkout.stripe.com/pay',
            'qr': {'payload': 'payment-payload', 'expires_at': 2000000000},
          },
        },
      );
      final action = await h.backend.start('orderA', 2);
      expect(action, kind == 'qr' ? isA<QrCheckout>() : isA<HostedCheckout>());
      expect(action.fallbackQr?.payload, 'payment-payload');
    }
  });

  for (final value in [
    {..._hosted(), 'checkout_url': 'http://checkout.stripe.com/pay'},
    {..._hosted(), 'contract_id': null},
    {..._hosted(), 'session_id': null},
    {..._hosted(), 'trade_no': 'foreign'},
  ]) {
    test(
      'invalid subscribe hosted response fails without replacement',
      () async {
        final h = _Harness(
          probe: (_) async => _data(_intent()),
          confirm: (_) async => true,
          subscribed: value,
        );
        await expectLater(
          h.backend.start('orderA', 2),
          throwsA(_failure('invalid_billing_response')),
        );
        expect(h.paths, [_detail, _probe, _subscribe]);
        expect(h.posts.length, 1);
      },
    );
  }
}
