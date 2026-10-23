import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

(XboardClient, List<http.Request>) harness(
  http.Response Function(http.Request) reply,
) {
  final seen = <http.Request>[];
  final client = XboardClient(
    origin: Uri.parse('https://panel.example'),
    client: MockClient((request) async {
      seen.add(request);
      return reply(request);
    }),
  )..setAuthorization('Bearer session');
  return (client, seen);
}

http.Response data(Object? value) =>
    http.Response.bytes(utf8.encode(jsonEncode({'data': value})), 200);

Matcher failure(String code) =>
    isA<ClientFailure>().having((e) => e.code, 'code', code);

void main() {
  test(
    'parses orders, keeps the nested plan and skips unusable entries',
    () async {
      final (api, seen) = harness(
        (_) => data([
          {
            'id': 9,
            'trade_no': '2026102312345',
            'plan_id': 3,
            'period': 'year_price',
            'type': 2,
            'status': 3,
            'total_amount': 38000,
            'balance_amount': '500',
            'discount_amount': null,
            'handling_amount': 120,
            'surplus_amount': 0,
            'created_at': 1790000000,
            'updated_at': '1790000100',
            'plan': {'id': 3, 'name': '轻享'},
          },
          {'trade_no': ' ', 'status': 0},
          {'status': 0},
          'junk',
          {'trade_no': 'T2', 'status': 7, 'period': 'onetime_price'},
        ]),
      );
      final orders = await ZolnitOrdersClient(api).orders();
      expect(seen.single.url.path, '/api/v1/user/order/fetch');
      expect(orders.map((o) => o.tradeNo), ['2026102312345', 'T2']);
      final first = orders.first;
      expect(first.isCompleted, isTrue);
      expect(first.isPayable, isFalse);
      expect(first.planName, '轻享');
      expect(first.months, 12);
      expect(first.balanceCents, 500);
      expect(first.discountCents, 0);
      expect(first.handlingCents, 120);
      expect(first.createdAt, DateTime.utc(2026, 9, 21, 14, 13, 20));
      expect(first.updatedAt!.isAfter(first.createdAt!), isTrue);
      expect(orders.last.status, ZolnitOrderStatus.unknown);
      expect(orders.last.months, isNull);
      api.close();
    },
  );

  test('maps every panel status and treats only 0 as payable', () {
    ZolnitOrderStatus of(int code) =>
        ZolnitOrder.fromJson({'trade_no': 'T', 'status': code})!.status;
    expect(of(0), ZolnitOrderStatus.pending);
    expect(of(1), ZolnitOrderStatus.processing);
    expect(of(2), ZolnitOrderStatus.cancelled);
    expect(of(3), ZolnitOrderStatus.completed);
    expect(of(4), ZolnitOrderStatus.discounted);
    expect(of(-1), ZolnitOrderStatus.unknown);
    expect(
      ZolnitOrder.fromJson({'trade_no': 'T', 'status': 4})!.isCompleted,
      isFalse,
    );
    expect(
      ZolnitOrder.fromJson({'trade_no': 'T', 'status': 0})!.isPayable,
      isTrue,
    );
  });

  test('period keys map to months, including the non-legacy names', () {
    int? months(String period) =>
        ZolnitOrder.fromJson({'trade_no': 'T', 'period': period})!.months;
    expect(months('month_price'), 1);
    expect(months('quarter_price'), 3);
    expect(months('half_year_price'), 6);
    expect(months('two_year_price'), 24);
    expect(months('three_yearly'), 36);
    expect(months('reset_price'), isNull);
    expect(months('mystery'), isNull);
  });

  test('order detail sends the trade number as a query parameter', () async {
    final (api, seen) = harness(
      (_) => data({'trade_no': 'AB-12_x', 'status': 0, 'plan': null}),
    );
    final order = await ZolnitOrdersClient(api).order('AB-12_x');
    expect(seen.single.method, 'GET');
    expect(seen.single.url.path, '/api/v1/user/order/detail');
    expect(seen.single.url.queryParameters, {'trade_no': 'AB-12_x'});
    expect(order.isPayable, isTrue);
    expect(order.planName, isNull);
    api.close();
  });

  test(
    'order detail for a different trade number is invalid_response',
    () async {
      final (api, _) = harness(
        (_) => data({'trade_no': 'OTHER-9', 'status': 3, 'plan_id': 3}),
      );
      await expectLater(
        ZolnitOrdersClient(api).order('AB-12_x'),
        throwsA(failure('invalid_response')),
      );
      api.close();
    },
  );

  test('rejects a malformed trade number before any request', () async {
    final (api, seen) = harness((_) => data({}));
    final client = ZolnitOrdersClient(api);
    for (final bad in ['', 'a b', 'a/b', 'x' * 65, '../x', 'é']) {
      await expectLater(
        client.order(bad),
        throwsA(failure('invalid_trade_no')),
      );
    }
    expect(seen, isEmpty);
    api.close();
  });

  test('wrong response shapes are invalid_response', () async {
    for (final body in <Object?>[
      'x',
      5,
      null,
      {'a': 1},
    ]) {
      final (api, _) = harness((_) => data(body));
      await expectLater(
        ZolnitOrdersClient(api).orders(),
        throwsA(failure('invalid_response')),
      );
      await expectLater(
        ZolnitOrdersClient(api).paymentMethods(),
        throwsA(failure('invalid_response')),
      );
      api.close();
    }
    final (api, _) = harness((_) => data([1]));
    await expectLater(
      ZolnitOrdersClient(api).order('T1'),
      throwsA(failure('invalid_response')),
    );
    final (empty, _) = harness((_) => data({'status': 0}));
    await expectLater(
      ZolnitOrdersClient(empty).order('T1'),
      throwsA(failure('invalid_response')),
    );
    api.close();
    empty.close();
  });

  test('payment methods keep fee units and only https icons', () async {
    final (api, seen) = harness(
      (_) => data([
        {
          'id': 2,
          'name': 'Stripe',
          'payment': 'StripeCredit',
          'icon': 'https://cdn.example/s.png',
          'handling_fee_fixed': 30,
          'handling_fee_percent': '2.9',
        },
        {
          'id': 3,
          'name': 'Old',
          'payment': 'X',
          'icon': 'http://cdn.example/o.png',
        },
        {'id': 0, 'name': 'Zero'},
        {'id': '-4', 'name': 'Negative'},
        {'name': 'No id'},
      ]),
    );
    final methods = await ZolnitOrdersClient(api).paymentMethods();
    expect(seen.single.url.path, '/api/v1/user/order/getPaymentMethod');
    expect(methods.map((m) => m.id), [2, 3]);
    expect(methods.first.iconUrl, Uri.parse('https://cdn.example/s.png'));
    expect(methods.first.handlingFeeFixedCents, 30);
    expect(methods.first.handlingFeePercent, 2.9);
    expect(methods.last.iconUrl, isNull);
    expect(methods.last.handlingFeePercent, 0);
    api.close();
  });

  test('server refusals keep their message', () async {
    final (api, _) = harness(
      (_) => http.Response('{"message":"Order does not exist"}', 500),
    );
    await expectLater(
      ZolnitOrdersClient(api).order('T1'),
      throwsA(
        isA<ClientFailure>()
            .having((e) => e.code, 'code', 'api_error')
            .having((e) => e.statusCode, 'status', 500)
            .having((e) => e.serverMessage, 'message', 'Order does not exist'),
      ),
    );
    api.close();
  });
}
