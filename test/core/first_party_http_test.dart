import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/core/first_party_http.dart';
import 'package:fl_clash/core/method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  final uri = Uri.parse('https://link.zolmid.com/api/v1/user/info');
  Map<String, dynamic> response() => {
    'status': 200,
    'headers': <String, String>{'content-type': 'application/json'},
    'body': base64Encode(utf8.encode('{"data":true}')),
  };

  test(
    'Core sends one request with opaque scope and decodes its response',
    () async {
      final calls = <Map<String, dynamic>>[];
      var fallbackCalls = 0;
      final cancelled = <String>[];
      final client = CoreFirstPartyHttpClient(
        invoke: (p) async {
          calls.add(p);
          return response();
        },
        cancel: (c, r) async {
          cancelled.add('$c/$r');
          return true;
        },
        useCore: () => true,
        fallback: MockClient((_) async {
          fallbackCalls++;
          return http.Response('', 200);
        }),
      );
      addTearDown(client.close);
      final result = await client.post(
        uri,
        headers: {'Authorization': 'Bearer fixture'},
        body: 'fixture-body',
      );
      expect(result.statusCode, 200);
      expect(result.body, '{"data":true}');
      expect(calls, hasLength(1));
      expect(calls.single['client-id'], isNotEmpty);
      expect(
        utf8.decode(base64Decode(calls.single['body'] as String)),
        'fixture-body',
      );
      expect(fallbackCalls, 0);
      expect(cancelled, isEmpty);
    },
  );

  for (final failure in [
    null,
    const CoreMethodException(
      code: 'transport_disconnected',
      message: 'closed',
    ),
  ]) {
    test('an ambiguous dispatched POST is never repeated ($failure)', () async {
      var coreCalls = 0;
      var fallbackCalls = 0;
      final client = CoreFirstPartyHttpClient(
        invoke: (_) async {
          coreCalls++;
          if (failure != null) throw failure;
          return null;
        },
        cancel: (_, _) async => true,
        useCore: () => true,
        fallback: MockClient((_) async {
          fallbackCalls++;
          return http.Response('', 200);
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.post(uri, body: 'fixture'),
        throwsA(isA<ClientFailure>()),
      );
      expect(coreCalls, 1);
      expect(fallbackCalls, 0);
    });
  }

  test('tunnel-off fallback is chosen before any Core dispatch', () async {
    var calls = 0;
    final client = CoreFirstPartyHttpClient(
      invoke: (_) async => throw StateError('must not dispatch'),
      cancel: (_, _) async => true,
      useCore: () => false,
      fallback: MockClient((r) async {
        calls++;
        expect(r.followRedirects, isFalse);
        return http.Response('ready', 200);
      }),
    );
    addTearDown(client.close);
    expect((await client.get(uri)).body, 'ready');
    expect(calls, 1);
  });

  test('a body stream that never ends is bounded before dispatch', () async {
    var dispatched = false;
    final client = CoreFirstPartyHttpClient(
      invoke: (_) async {
        dispatched = true;
        return response();
      },
      cancel: (_, _) async => true,
      useCore: () => true,
      requestTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(client.close);
    final request = http.StreamedRequest('POST', uri);
    await expectLater(client.send(request), throwsA(isA<TimeoutException>()));
    unawaited(request.sink.close());
    expect(dispatched, isFalse);
  });

  test('closing one client promptly cancels only its own requests', () async {
    final calls = <Map<String, dynamic>>[];
    final cancels = <String>[];
    final gates = [
      Completer<Map<String, dynamic>?>(),
      Completer<Map<String, dynamic>?>(),
    ];
    var next = 0;
    CoreFirstPartyHttpClient make() => CoreFirstPartyHttpClient(
      invoke: (p) {
        calls.add(p);
        return gates[next++].future;
      },
      cancel: (c, _) async {
        cancels.add(c);
        return true;
      },
      useCore: () => true,
    );
    final a = make();
    final b = make();
    addTearDown(a.close);
    addTearDown(b.close);
    final first = a.get(uri);
    final firstCheck = expectLater(first, throwsA(isA<ClientFailure>()));
    final second = b.get(uri);
    await Future<void>.delayed(Duration.zero);
    a.close();
    await firstCheck;
    expect(cancels, everyElement(calls.first['client-id']));
    gates[1].complete(response());
    expect((await second).statusCode, 200);
    gates[0].complete(response());
  });

  test(
    'foreign URLs fail before transport and oversized replies are rejected',
    () async {
      var calls = 0;
      final client = CoreFirstPartyHttpClient(
        invoke: (_) async {
          calls++;
          return {
            'status': 200,
            'headers': {},
            'body': 'A' * (12 * 1024 * 1024),
          };
        },
        cancel: (_, _) async => true,
        useCore: () => true,
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse('https://example.invalid/api/v1/test')),
        throwsFormatException,
      );
      expect(calls, 0);
      await expectLater(client.get(uri), throwsFormatException);
      expect(calls, 1);
    },
  );
}
