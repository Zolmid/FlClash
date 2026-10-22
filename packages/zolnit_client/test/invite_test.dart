import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  final requests = <http.Request>[];
  late ZolnitInviteClient invites;
  late XboardClient api;

  void serve(int status, Object body) {
    requests.clear();
    api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      }),
    )..setAuthorization('Bearer sessionA');
    invites = ZolnitInviteClient(api);
  }

  tearDown(() => api.close());

  test('overview parses codes and positional stats', () async {
    serve(200, {
      'data': {
        'codes': [
          {
            'user_id': 1,
            'code': 'AbCd1234',
            'pv': '5',
            'status': 0,
            'created_at': 1760000000,
          },
          {'code': ''},
          {'code': 'ZZZZ'},
          3,
        ],
        'stat': [4, 1500, '300', 10, 1200],
      },
    });
    final invite = await invites.overview();
    expect(requests.single.url.path, '/api/v1/user/invite/fetch');
    expect(invite.codes.map((c) => c.code), ['AbCd1234', 'ZZZZ']);
    expect(invite.codes.first.pv, 5);
    expect(invite.codes.last.pv, 0);
    final stats = invite.stats!;
    expect(stats.registeredCount, 4);
    expect(stats.confirmedCommissionCents, 1500);
    expect(stats.pendingCommissionCents, 300);
    expect(stats.commissionRatePercent, 10);
    expect(stats.availableCommissionCents, 1200);
  });

  test('malformed stats become null, malformed overview throws', () async {
    for (final stat in [
      [1, 2, 3],
      [1, 2, 3, 4, 'x'],
      [1, 2.5, 3, 4, 5],
      {'a': 1},
      null,
    ]) {
      serve(200, {
        'data': {'codes': [], 'stat': stat},
      });
      expect((await invites.overview()).stats, isNull);
    }
    serve(200, {
      'data': {'stat': []},
    });
    await expectLater(invites.overview(), throwsA(isA<ClientFailure>()));
    serve(200, {'data': []});
    await expectLater(invites.overview(), throwsA(isA<ClientFailure>()));
  });

  test('createCode needs literal true and passes server refusals', () async {
    serve(200, {'data': true});
    await invites.createCode();
    expect(requests.single.url.path, '/api/v1/user/invite/save');
    serve(200, {'data': false});
    await expectLater(
      invites.createCode(),
      throwsA(
        isA<ClientFailure>().having((e) => e.code, 'code', 'invite_failed'),
      ),
    );
    serve(400, {'message': 'The maximum number of creations has been reached'});
    await expectLater(
      invites.createCode(),
      throwsA(
        isA<ClientFailure>().having(
          (e) => e.serverMessage,
          'message',
          'The maximum number of creations has been reached',
        ),
      ),
    );
  });

  test('commissions parse a page and send paging query', () async {
    serve(200, {
      'data': [
        {
          'id': 9,
          'order_amount': 5000,
          'trade_no': '2025ABC',
          'get_amount': '500',
          'created_at': 1760000000,
        },
        {'order_amount': 1},
        'junk',
      ],
      'total': 31,
    });
    final page = await invites.commissions(page: 2, pageSize: 20);
    expect(requests.single.url.path, '/api/v1/user/invite/details');
    expect(requests.single.url.queryParameters, {
      'current': '2',
      'page_size': '20',
    });
    expect(page.total, 31);
    expect(page.entries, hasLength(1));
    expect(page.entries.single.commissionCents, 500);
    expect(page.entries.single.orderAmountCents, 5000);
    expect(page.entries.single.tradeNo, '2025ABC');

    serve(200, {'data': {}, 'total': 0});
    await expectLater(invites.commissions(), throwsA(isA<ClientFailure>()));
    for (final total in [null, 'x', 1.5, -1, '2.5', true]) {
      serve(200, {'data': [], 'total': total});
      await expectLater(
        invites.commissions(),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    }
    serve(200, {'data': [], 'total': '12'});
    expect((await invites.commissions()).total, 12);
    serve(200, {'data': []});
    await expectLater(invites.commissions(), throwsA(isA<ClientFailure>()));
  });

  test('invalid paging is rejected before any request', () async {
    serve(200, {'data': [], 'total': 0});
    for (final (page, size) in [(0, 10), (1, 9), (1, 101)]) {
      await expectLater(
        invites.commissions(page: page, pageSize: size),
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'invalid_page'),
        ),
      );
    }
    expect(requests, isEmpty);
  });

  test('invite link uses hash routing on https origins', () {
    final link = zolnitInviteLink(
      Uri.parse('https://zolnit.example'),
      'AbCd1234',
    );
    expect(link.toString(), 'https://zolnit.example/#/register?code=AbCd1234');
    for (final code in ['abc', 'a b c d', 'ab&cd=1', '']) {
      expect(
        () => zolnitInviteLink(Uri.parse('https://zolnit.example'), code),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'invalid_invite_code',
          ),
        ),
      );
    }
    for (final bad in [
      'http://zolnit.example',
      'https://user:pw@zolnit.example',
      'https://zolnit.example/app',
      'https://zolnit.example/?a=1',
      'https://zolnit.example/#x',
      '/relative',
    ]) {
      expect(
        () => zolnitInviteLink(Uri.parse(bad), 'AbCd1234'),
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'invalid_origin'),
        ),
        reason: bad,
      );
    }
  });
}
