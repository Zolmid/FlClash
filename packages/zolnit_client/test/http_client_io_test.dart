import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/src/http_client_io.dart';

class _AmbientProxyOverrides extends HttpOverrides {
  var clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context)
      ..findProxy = (_) => 'PROXY 127.0.0.1:1';
  }
}

void main() {
  test('control-plane client does not inherit the ambient proxy', () async {
    final overrides = _AmbientProxyOverrides();

    await HttpOverrides.runWithHttpOverrides(() async {
      final client = createClient(isAndroid: false);
      client.close();
    }, overrides);

    expect(overrides.clients, 0);
  });

  test(
    'Android selects native transport only for the exact first-party origin',
    () {
      final firstParty = createClient(
        origin: Uri.parse('https://link.zolmid.com'),
        isAndroid: true,
        nativeRequest: (_, _) async => null,
      );
      final foreign = createClient(
        origin: Uri.parse('https://example.com'),
        isAndroid: true,
        nativeRequest: (_, _) async => null,
      );
      expect(firstParty, isA<AndroidFirstPartyClient>());
      expect(foreign, isNot(isA<AndroidFirstPartyClient>()));
      firstParty.close();
      foreign.close();
    },
  );

  test(
    'known Android origin uses the native channel without serialization',
    () async {
      final pending = <Completer<Object?>>[];
      final client = AndroidFirstPartyClient(
        nativeRequest: (method, arguments) {
          if (method == 'cancelFirstPartyHttpRequest') return Future.value();
          expect(
            arguments['url'],
            startsWith('https://link.zolmid.com/api/v1/'),
          );
          final completer = Completer<Object?>();
          pending.add(completer);
          return completer.future;
        },
        fallback: MockClient(
          (_) async => throw StateError('unexpected fallback'),
        ),
      );
      final first = client.get(
        Uri.parse('https://link.zolmid.com/api/v1/user/info'),
      );
      final second = client.get(
        Uri.parse('https://link.zolmid.com/api/v1/guest/comm/config'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(2));
      for (final request in pending) {
        request.complete({
          'status': 200,
          'headers': <String, String>{'content-type': 'application/json'},
          'body': Uint8List.fromList('{}'.codeUnits),
        });
      }
      await Future.wait([first, second]);
      client.close();
    },
  );

  test('native transport rejects non-first-party URLs and methods', () async {
    final client = AndroidFirstPartyClient(
      nativeRequest: (_, _) async => throw StateError('must not invoke'),
      fallback: MockClient((_) async => throw StateError('must not fallback')),
    );
    await expectLater(
      client.get(Uri.parse('https://example.com/api/v1/user/info')),
      throwsFormatException,
    );
    await expectLater(
      client.send(
        http.Request(
          'PUT',
          Uri.parse('https://link.zolmid.com/api/v1/user/info'),
        ),
      ),
      throwsFormatException,
    );
    await expectLater(
      client.get(Uri.parse('https://link.zolmid.com/other')),
      throwsFormatException,
    );
    client.close();
  });

  test('only MissingPlugin falls back to strict direct HTTP', () async {
    var fallbacks = 0;
    final fallback = MockClient((request) async {
      fallbacks++;
      return http.Response('{}', 200);
    });
    final missing = AndroidFirstPartyClient(
      nativeRequest: (_, _) async => throw MissingPluginException(),
      fallback: fallback,
    );
    expect(
      (await missing.get(
        Uri.parse('https://link.zolmid.com/api/v1/user/info'),
      )).statusCode,
      200,
    );
    expect(fallbacks, 1);
    missing.close();

    final failed = AndroidFirstPartyClient(
      nativeRequest: (_, _) async => throw PlatformException(code: 'NETWORK'),
      fallback: MockClient((_) async {
        fallbacks++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      failed.get(Uri.parse('https://link.zolmid.com/api/v1/user/info')),
      throwsA(isA<PlatformException>()),
    );
    expect(fallbacks, 1);
    failed.close();
  });

  test(
    'disposing client A cancels only its requests while B finishes',
    () async {
      final pending = <String, Completer<Object?>>{};
      final cancelled = <String>[];
      Future<Object?> invoke(String method, Map<String, Object?> args) async {
        final key = '${args['clientId']}:${args['requestId']}';
        if (method == 'cancelFirstPartyHttpRequest') {
          cancelled.add(key);
          pending[key]!.completeError(PlatformException(code: 'CANCELLED'));
          return null;
        }
        final response = Completer<Object?>();
        pending[key] = response;
        return response.future;
      }

      AndroidFirstPartyClient makeClient() => AndroidFirstPartyClient(
        nativeRequest: invoke,
        fallback: MockClient((_) async => throw StateError('unexpected retry')),
      );
      final a = makeClient();
      final b = makeClient();
      final uri = Uri.parse('https://link.zolmid.com/api/v1/user/info');
      final aResult = a.get(uri);
      final aFailure = expectLater(
        aResult,
        throwsA(isA<http.ClientException>()),
      );
      final bResult = b.get(uri);
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(2));
      a.close();
      await aFailure;
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, hasLength(1));
      final bKey = pending.keys.singleWhere((key) => !cancelled.contains(key));
      pending[bKey]!.complete({
        'status': 200,
        'headers': <String, String>{},
        'body': Uint8List.fromList('{}'.codeUnits),
      });
      expect((await bResult).statusCode, 200);
      b.close();
      expect(cancelled, hasLength(1));
    },
  );

  test(
    'deadline cancels exactly the timed out POST without fallback',
    () async {
      var posts = 0;
      final cancels = <Map<String, Object?>>[];
      final never = Completer<Object?>();
      final client = AndroidFirstPartyClient(
        nativeRequest: (method, args) async {
          if (method == 'cancelFirstPartyHttpRequest') {
            cancels.add(args);
            return null;
          }
          posts++;
          return never.future;
        },
        fallback: MockClient(
          (_) async => throw StateError('POST must not replay'),
        ),
        requestTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        client.post(
          Uri.parse('https://link.zolmid.com/api/v1/passport/auth/login'),
          body: '{}',
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(posts, 1);
      expect(cancels, hasLength(1));
      never.completeError(PlatformException(code: 'NETWORK'));
      await Future<void>.delayed(Duration.zero);
      client.close();
    },
  );

  test(
    'closing while collecting a body never dispatches a late request',
    () async {
      var calls = 0;
      final client = AndroidFirstPartyClient(
        nativeRequest: (_, _) async {
          calls++;
          return null;
        },
        fallback: MockClient((_) async => throw StateError('unexpected retry')),
      );
      final request = http.StreamedRequest(
        'POST',
        Uri.parse('https://link.zolmid.com/api/v1/passport/auth/login'),
      );
      final result = client.send(request);
      final failure = expectLater(result, throwsA(isA<http.ClientException>()));
      client.close();
      await failure;
      await request.sink.close();
      expect(calls, 0);
    },
  );

  test(
    'URL header and streaming body bounds reject before channel dispatch',
    () async {
      var calls = 0;
      final client = AndroidFirstPartyClient(
        nativeRequest: (_, _) async {
          calls++;
          return null;
        },
        fallback: MockClient((_) async => throw StateError('unexpected retry')),
      );
      final uri = Uri.parse('https://link.zolmid.com/api/v1/user/info');
      await expectLater(
        client.get(uri.replace(queryParameters: {'q': 'a' * 8192})),
        throwsFormatException,
      );
      await expectLater(
        client.get(uri, headers: {'User-Agent': 'a' * 8193}),
        throwsFormatException,
      );
      await expectLater(
        client.get(uri, headers: {'Cookie': 'forbidden'}),
        throwsFormatException,
      );
      await expectLater(
        client.post(uri, body: Uint8List(1024 * 1024 + 1)),
        throwsFormatException,
      );
      expect(calls, 0);
      client.close();
    },
  );
}
