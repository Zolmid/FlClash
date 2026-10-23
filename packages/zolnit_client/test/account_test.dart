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
  test('info reads the panel user and never exposes the uuid', () async {
    final (api, seen) = harness(
      (_) => data({
        'email': 'a@example.com',
        'transfer_enable': 161061273600,
        'last_login_at': 1790000000,
        'created_at': 1780000000,
        'banned': 0,
        'remind_expire': 1,
        'remind_traffic': '0',
        'expired_at': null,
        'balance': 1250,
        'commission_balance': '300',
        'plan_id': 3,
        'discount': 10,
        'commission_rate': 12.5,
        'telegram_id': 123456,
        'uuid': 'secret-uuid-value',
        'avatar_url': 'https://cdn.v2ex.com/gravatar/abc?s=64&d=identicon',
      }),
    );
    final info = await ZolnitAccountClient(api).info();
    expect(seen.single.url.path, '/api/v1/user/info');
    expect(info.email, 'a@example.com');
    expect(info.balanceCents, 1250);
    expect(info.commissionBalanceCents, 300);
    expect(info.planId, 3);
    expect(info.expiresAt, isNull);
    expect(info.transferEnableBytes, 161061273600);
    expect(info.remindExpire, isTrue);
    expect(info.remindTraffic, isFalse);
    expect(info.banned, isFalse);
    expect(info.discountPercent, 10);
    expect(info.commissionRatePercent, 12.5);
    expect(info.telegramLinked, isTrue);
    expect(info.avatarUrl!.host, 'cdn.v2ex.com');
    expect(info.toString(), isNot(contains('secret')));
    api.close();
  });

  test('info tolerates a sparse user and rejects other shapes', () async {
    final sparse = ZolnitAccountInfo.fromJson({
      'email': 'b@example.com',
      'plan_id': 0,
      'telegram_id': null,
      'avatar_url': 'http://insecure.example/a.png',
      'discount': null,
      'expired_at': 1800000000,
    })!;
    expect(sparse.planId, isNull);
    expect(sparse.telegramLinked, isFalse);
    expect(sparse.avatarUrl, isNull);
    expect(sparse.discountPercent, isNull);
    expect(sparse.commissionRatePercent, isNull);
    expect(sparse.expiresAt!.isUtc, isTrue);
    for (final body in <Object?>[
      [],
      'x',
      {'balance': 1},
    ]) {
      final (api, _) = harness((_) => data(body));
      await expectLater(
        ZolnitAccountClient(api).info(),
        throwsA(failure('invalid_response')),
      );
      api.close();
    }
  });

  test(
    'devices read Sanctum token rows and hide the id from toString',
    () async {
      final (api, seen) = harness(
        (_) => data([
          {
            'id': 41,
            'tokenable_type': 'App\\Models\\User',
            'name': 'Pixel 9',
            'abilities': ['*'],
            'last_used_at': '2026-10-22T08:30:00.000000Z',
            'expires_at': '2027-10-01T00:00:00.000000Z',
            'created_at': 1790000000,
          },
          {'id': '42', 'name': '  ', 'last_used_at': null, 'ip': '203.0.113.9'},
          {'id': 0, 'name': 'bad'},
          {'name': 'no id'},
          'junk',
        ]),
      );
      final devices = await ZolnitAccountClient(api).devices();
      expect(seen.single.url.path, '/api/v1/user/getActiveSession');
      expect(devices.map((d) => d.id), ['41', '42']);
      expect(devices[0].label, 'Pixel 9');
      expect(devices[0].lastUsedAt, DateTime.utc(2026, 10, 22, 8, 30));
      expect(devices[0].createdAt, DateTime.utc(2026, 9, 21, 14, 13, 20));
      expect(devices[0].toString(), isNot(contains('41')));
      expect(devices[1].label, isNull);
      expect(devices[1].ip, '203.0.113.9');
      expect(devices[1].lastUsedAt, isNull);
      api.close();
    },
  );

  test('numeric strings are Unix seconds and ISO strings still parse', () {
    final device = ZolnitDevice.fromJson({
      'id': 1,
      'last_used_at': '1790000000',
      'created_at': '20261022',
    })!;
    expect(device.lastUsedAt, DateTime.utc(2026, 9, 21, 14, 13, 20));
    expect(device.createdAt, DateTime.utc(1970, 8, 23, 12, 3, 42));
    expect(
      ZolnitDevice.fromJson({
        'id': 1,
        'last_used_at': '2026-10-22T08:30:00+08:00',
      })!.lastUsedAt,
      DateTime.utc(2026, 10, 22, 0, 30),
    );
  });

  test('devices need a list', () async {
    final (api, _) = harness((_) => data({'id': 1}));
    await expectLater(
      ZolnitAccountClient(api).devices(),
      throwsA(failure('invalid_response')),
    );
    api.close();
  });

  test('removeDevice posts the session id and requires literal true', () async {
    final (api, seen) = harness((_) => data(true));
    await ZolnitAccountClient(api).removeDevice('41');
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/api/v1/user/removeActiveSession');
    expect(jsonDecode(seen.single.body), {'session_id': '41'});
    api.close();

    final (bad, badSeen) = harness((_) => data('true'));
    await expectLater(
      ZolnitAccountClient(bad).removeDevice('41'),
      throwsA(failure('device_failed')),
    );
    await expectLater(
      ZolnitAccountClient(bad).removeDevice('  '),
      throwsA(failure('invalid_device')),
    );
    expect(badSeen, hasLength(1));
    bad.close();
  });

  test('changePassword mirrors the panel rules before sending', () async {
    final (api, seen) = harness((_) => data(true));
    final client = ZolnitAccountClient(api);
    for (final (old, fresh) in [
      ('', 'longenough'),
      ('oldpass1', 'short'),
      ('samesame1', 'samesame1'),
    ]) {
      await expectLater(
        client.changePassword(oldPassword: old, newPassword: fresh),
        throwsA(failure('invalid_password')),
      );
    }
    expect(seen, isEmpty);

    await client.changePassword(
      oldPassword: 'oldpass1',
      newPassword: 'newpass12',
    );
    expect(seen.single.url.path, '/api/v1/user/changePassword');
    expect(jsonDecode(seen.single.body), {
      'old_password': 'oldpass1',
      'new_password': 'newpass12',
    });
    api.close();
  });

  test('changePassword failures never echo the passwords', () async {
    final (refused, _) = harness(
      (_) => http.Response('{"message":"The old password is wrong"}', 400),
    );
    final error = await ZolnitAccountClient(refused)
        .changePassword(oldPassword: 'oldpass1', newPassword: 'newpass12')
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, failure('api_error'));
    expect(
      (error! as ClientFailure).serverMessage,
      'The old password is wrong',
    );
    expect(error.toString(), isNot(contains('newpass12')));
    refused.close();

    final (odd, _) = harness((_) => data(false));
    await expectLater(
      ZolnitAccountClient(
        odd,
      ).changePassword(oldPassword: 'oldpass1', newPassword: 'newpass12'),
      throwsA(failure('password_failed')),
    );
    odd.close();
  });

  test('setReminders sends only the chosen flags as 0/1', () async {
    final (api, seen) = harness((_) => data(true));
    final client = ZolnitAccountClient(api);
    await expectLater(
      client.setReminders(),
      throwsA(failure('invalid_reminders')),
    );
    expect(seen, isEmpty);

    await client.setReminders(expiry: true);
    await client.setReminders(traffic: false);
    expect(seen.map((r) => r.url.path).toSet(), {'/api/v1/user/update'});
    expect(jsonDecode(seen[0].body), {'remind_expire': 1});
    expect(jsonDecode(seen[1].body), {'remind_traffic': 0});
    api.close();

    final (bad, _) = harness((_) => data(null));
    await expectLater(
      ZolnitAccountClient(bad).setReminders(expiry: false),
      throwsA(failure('reminders_failed')),
    );
    bad.close();
  });
}
