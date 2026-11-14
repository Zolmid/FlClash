import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

const code = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';

class TestSession extends ChangeNotifier implements ZolnitSessionController {
  TestSession(this.api, this.authenticated);
  @override
  final XboardClient api;
  @override
  bool authenticated;
  @override
  int accountGeneration = 0;
  void switchAccount() {
    accountGeneration++;
    api.setAuthorization('Bearer next');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestBrowser implements ZolnitWebSessionBrowser {
  int opens = 0;
  int closes = 0;
  String? receivedCode;
  String? destination;
  bool result = true;
  Completer<bool>? openResult;
  Completer<void>? openStarted;
  @override
  Future<bool> open(String code, String destination) async {
    opens++;
    receivedCode = code;
    this.destination = destination;
    openStarted?.complete();
    return openResult == null ? result : await openResult!.future;
  }

  @override
  Future<void> close() async {
    closes++;
  }
}

void main() {
  test('opens a grant for the canonical first party destination', () async {
    var calls = 0;
    final api = XboardClient(
      origin: Uri.parse(zolnitWebOrigin),
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/v1/zolnit/client/web-session/authorize');
        return http.Response(
          jsonEncode({
            'data': {'code': code},
          }),
          200,
        );
      }),
    )..setAuthorization('Bearer current');
    final session = TestSession(api, true);
    final browser = TestBrowser();
    final fallback = <Uri>[];
    final controller = ZolnitWebSessionCoordinator(
      session: session,
      browser: browser,
      fallback: (uri) async {
        fallback.add(uri);
        return true;
      },
    );
    expect(
      await controller.open(Uri.parse('$zolnitWebOrigin/#/dashboard')),
      isTrue,
    );
    expect(calls, 1);
    expect(browser.receivedCode, code);
    expect(browser.destination, '/#/dashboard');
    expect(fallback, isEmpty);
    controller.dispose();
    expect(browser.closes, 1);
    session.dispose();
    api.close();
  });

  test('guest and non-first-party links use only ordinary fallback', () async {
    var calls = 0;
    final api = XboardClient(
      origin: Uri.parse(zolnitWebOrigin),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    final session = TestSession(api, false);
    final browser = TestBrowser();
    final fallback = <Uri>[];
    final controller = ZolnitWebSessionCoordinator(
      session: session,
      browser: browser,
      fallback: (uri) async {
        fallback.add(uri);
        return true;
      },
    );
    await controller.open(Uri.parse('$zolnitWebOrigin/'));
    session.authenticated = true;
    api.setAuthorization('Bearer current');
    await controller.open(Uri.parse('https://other.example/'));
    await controller.open(Uri.parse('$zolnitWebOrigin/#/other'));
    expect(calls, 0);
    expect(browser.opens, 0);
    expect(fallback.length, 3);
    controller.cancel();
    controller.dispose();
    expect(browser.closes, 0);
    session.dispose();
    api.close();
  });

  test('failed authorization falls back without credentials', () async {
    final api = XboardClient(
      origin: Uri.parse(zolnitWebOrigin),
      client: MockClient((_) async => http.Response('{}', 403)),
    )..setAuthorization('Bearer current');
    final session = TestSession(api, true);
    final browser = TestBrowser();
    final fallback = <Uri>[];
    final controller = ZolnitWebSessionCoordinator(
      session: session,
      browser: browser,
      fallback: (uri) async {
        fallback.add(uri);
        return true;
      },
    );
    await controller.open(
      Uri.parse('$zolnitWebOrigin/theme/ZolNit/downloads.html'),
    );
    expect(browser.opens, 0);
    expect(
      fallback.single.toString(),
      '$zolnitWebOrigin/theme/ZolNit/downloads.html',
    );
    controller.dispose();
    session.dispose();
    api.close();
  });

  test(
    'account switch discards a late grant and single flight coalesces',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final api = XboardClient(
        origin: Uri.parse(zolnitWebOrigin),
        client: MockClient((_) {
          calls++;
          started.complete();
          return response.future;
        }),
      )..setAuthorization('Bearer current');
      final session = TestSession(api, true);
      final browser = TestBrowser();
      final fallback = <Uri>[];
      final controller = ZolnitWebSessionCoordinator(
        session: session,
        browser: browser,
        fallback: (uri) async {
          fallback.add(uri);
          return true;
        },
      );
      final first = controller.open(Uri.parse('$zolnitWebOrigin/'));
      await started.future;
      final second = controller.open(Uri.parse('$zolnitWebOrigin/'));
      session.switchAccount();
      response.complete(
        http.Response(
          jsonEncode({
            'data': {'code': code},
          }),
          200,
        ),
      );
      expect(await first, isFalse);
      expect(await second, isFalse);
      expect(calls, 1);
      expect(browser.opens, 0);
      expect(browser.closes, 0);
      expect(fallback, isEmpty);
      controller.dispose();
      session.dispose();
      api.close();
    },
  );
  test('unsupported platforms do not request a grant', () async {
    var calls = 0;
    final api = XboardClient(
      origin: Uri.parse(zolnitWebOrigin),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    )..setAuthorization('Bearer current');
    final session = TestSession(api, true);
    final browser = TestBrowser();
    final fallback = <Uri>[];
    final controller = ZolnitWebSessionCoordinator(
      session: session,
      browser: browser,
      canAuthorize: false,
      fallback: (uri) async {
        fallback.add(uri);
        return true;
      },
    );
    await controller.open(Uri.parse('$zolnitWebOrigin/'));
    expect(calls, 0);
    expect(browser.opens, 0);
    expect(fallback.single.toString(), '$zolnitWebOrigin/');
    controller.dispose();
    session.dispose();
    api.close();
  });
  test('only canonical destinations request grants', () async {
    final seen = <Uri>[];
    var grants = 0;
    final api = XboardClient(
      origin: Uri.parse(zolnitWebOrigin),
      client: MockClient((_) async {
        grants++;
        return http.Response(
          jsonEncode({
            'data': {'code': code},
          }),
          200,
        );
      }),
    )..setAuthorization('Bearer current');
    final session = TestSession(api, true);
    final browser = TestBrowser();
    final controller = ZolnitWebSessionCoordinator(
      session: session,
      browser: browser,
      fallback: (uri) async {
        seen.add(uri);
        return true;
      },
    );
    for (final path in ['/', '/#/dashboard', '/theme/ZolNit/downloads.html']) {
      expect(await controller.open(Uri.parse('$zolnitWebOrigin$path')), isTrue);
      expect(browser.destination, path);
    }
    for (final url in [
      'https://link.zolmid.com.evil.example/',
      'https://link.zolmid.com/?x=1',
      'https://link.zolmid.com/#/dashboard?x=1',
      'https://link.zolmid.com/theme/ZolNit/downloads.html#other',
      'mailto:someone@example.com',
    ]) {
      await controller.open(Uri.parse(url));
    }
    expect(grants, 3);
    expect(seen.length, 5);
    controller.dispose();
    session.dispose();
    api.close();
  });

  test(
    'browser failure closes its window before uncredentialed fallback',
    () async {
      final api = XboardClient(
        origin: Uri.parse(zolnitWebOrigin),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {'code': code},
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer current');
      final session = TestSession(api, true);
      final browser = TestBrowser()..result = false;
      final seen = <Uri>[];
      final controller = ZolnitWebSessionCoordinator(
        session: session,
        browser: browser,
        fallback: (uri) async {
          expect(browser.closes, 1);
          seen.add(uri);
          return true;
        },
      );
      expect(await controller.open(Uri.parse('$zolnitWebOrigin/')), isTrue);
      expect(seen.single.toString(), '$zolnitWebOrigin/');
      controller.dispose();
      expect(browser.closes, 1);
      session.dispose();
      api.close();
    },
  );
  test(
    'account switch closes an opening browser and ignores its late success',
    () async {
      final api = XboardClient(
        origin: Uri.parse(zolnitWebOrigin),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {'code': code},
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer current');
      final session = TestSession(api, true);
      final browser = TestBrowser()
        ..openStarted = Completer<void>()
        ..openResult = Completer<bool>();
      var fallbacks = 0;
      final controller = ZolnitWebSessionCoordinator(
        session: session,
        browser: browser,
        fallback: (_) async {
          fallbacks++;
          return true;
        },
      );
      final opened = controller.open(Uri.parse('$zolnitWebOrigin/'));
      await browser.openStarted!.future;
      session.switchAccount();
      browser.openResult!.complete(true);
      expect(await opened, isFalse);
      expect(browser.closes, 1);
      expect(fallbacks, 0);
      controller.dispose();
      session.dispose();
      api.close();
    },
  );
}
