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
    'log sorts newest first, drops unusable rows and defaults the rate',
    () async {
      final (api, seen) = harness(
        (_) => data([
          {
            'd': 2000,
            'u': 500,
            'record_at': 1790000000,
            'server_rate': '1.50',
            'user_id': 8,
          },
          {
            'd': '4096',
            'u': null,
            'record_at': 1790086400,
            'server_rate': null,
          },
          {'d': 1, 'u': 1, 'record_at': 0, 'server_rate': 1},
          {'d': 1, 'u': 1, 'server_rate': 1},
          {'d': -5, 'u': 'x', 'record_at': 1789913600, 'server_rate': 0},
          7,
        ]),
      );
      final days = await ZolnitTrafficClient(api).log();
      expect(seen.single.url.path, '/api/v1/user/stat/getTrafficLog');
      expect(days.map((d) => d.day.millisecondsSinceEpoch ~/ 1000), [
        1790086400,
        1790000000,
        1789913600,
      ]);
      expect(days[0].downloadBytes, 4096);
      expect(days[0].uploadBytes, 0);
      expect(days[0].rate, 1);
      expect(days[1].rate, 1.5);
      expect(days[1].totalBytes, 2500);
      expect(days[2].totalBytes, 0);
      expect(days[2].rate, 1);
      expect(days.first.day.isUtc, isTrue);
      api.close();
    },
  );

  test('a non-list response is invalid_response', () async {
    final (api, _) = harness((_) => data({'d': 1}));
    await expectLater(
      ZolnitTrafficClient(api).log(),
      throwsA(failure('invalid_response')),
    );
    api.close();
  });

  test('server errors surface the panel message', () async {
    final (api, _) = harness(
      (_) => http.Response('{"message":"Try later"}', 400),
    );
    await expectLater(
      ZolnitTrafficClient(api).log(),
      throwsA(
        isA<ClientFailure>().having(
          (e) => e.serverMessage,
          'message',
          'Try later',
        ),
      ),
    );
    api.close();
  });
}
