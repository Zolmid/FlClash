import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  const code = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
  final origin = Uri.parse('https://link.zolmid.com');

  test('authorizes with a bearer header and an empty JSON body', () async {
    final api = XboardClient(
      origin: origin,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/zolnit/client/web-session/authorize');
        expect(request.url.hasQuery, isFalse);
        expect(request.headers['Authorization'], 'Bearer sessionA');
        expect(jsonDecode(request.body), isEmpty);
        expect(request.followRedirects, isFalse);
        return http.Response(
          jsonEncode({
            'data': {'code': code},
          }),
          200,
        );
      }),
    )..setAuthorization('Bearer sessionA');
    expect(await api.authorizeWebSession(), code);
    api.close();
  });

  test('rejects malformed codes and unauthenticated requests', () async {
    var calls = 0;
    final api = XboardClient(
      origin: origin,
      client: MockClient((_) async {
        calls++;
        return http.Response('{"data":{"code":"bad"}}', 200);
      }),
    );
    await expectLater(api.authorizeWebSession(), throwsA(isA<ClientFailure>()));
    expect(calls, 0);
    api.setAuthorization('Bearer sessionA');
    await expectLater(api.authorizeWebSession(), throwsA(isA<ClientFailure>()));
    api.close();
  });

  test('discards an authorization returned after an account switch', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final api = XboardClient(
      origin: origin,
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    )..setAuthorization('Bearer sessionA');
    final grant = api.authorizeWebSession();
    final assertion = expectLater(
      grant,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
    await started.future;
    api.setAuthorization('Bearer sessionB');
    response.complete(
      http.Response(
        jsonEncode({
          'data': {'code': code},
        }),
        200,
      ),
    );
    await assertion;
    api.close();
  });
}
