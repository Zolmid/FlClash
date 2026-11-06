import 'dart:async';

import 'package:fl_clash/views/zolnit/auth.dart';
import 'package:fl_clash/views/zolnit/brand.dart';
import 'package:fl_clash/views/zolnit/data.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:fl_clash/providers/zolnit_registration.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

class _RegistrationBrowser implements ZolnitRegistrationBrowser {
  _RegistrationBrowser({this.launches = true});

  final bool launches;
  Uri? registration;
  ValueChanged<Uri>? onReturn;
  VoidCallback? onClosed;
  int closes = 0;

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<bool> open(
    Uri registration, {
    required ValueChanged<Uri> onReturn,
    required VoidCallback onClosed,
  }) async {
    this.registration = registration;
    this.onReturn = onReturn;
    this.onClosed = onClosed;
    return launches;
  }
}

class _RegistrationAttemptStore implements ZolnitRegistrationAttemptStore {
  ZolnitRegistrationAttempt? value;
  int reads = 0;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<ZolnitRegistrationAttempt?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write(ZolnitRegistrationAttempt attempt) async {
    value = attempt;
  }
}

void main() {
  final harness = ZolnitHarness.register();

  Future<void> mountLogin(
    WidgetTester tester,
    ZolnitSkin skin, {
    Size? size,
    VoidCallback? openRegistration,
    VoidCallback? openRecovery,
    VoidCallback? openWebsite,
    Future<void> Function()? onSignedIn,
    bool host = false,
  }) async {
    await harness.session.logout();
    harness.requests.clear();
    await harness.mount(
      tester,
      skin,
      size: size,
      child: host
          ? null
          : ZolnitLoginPage(
              session: harness.session,
              onSignedIn: onSignedIn ?? () async {},
              openWebsite: openWebsite ?? () {},
              openRegistration: openRegistration,
              openRecovery: openRecovery,
            ),
    );
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('zolnit-email')),
      'lin@example.com',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('zolnit-password')),
        matching: find.byType(TextFormField),
      ),
      'password123',
    );
  }

  for (final skin in ZolnitSkin.values) {
    testWidgets('login renders on ${skin.name}', (tester) async {
      await mountLogin(tester, skin, host: true);
      expect(find.byKey(const ValueKey('zolnit-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('zolnit-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('zolnit-sign-in')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('zolnit-brand-panel')),
        skin.desktop ? findsOneWidget : findsNothing,
      );
      await harness.capture(tester, 'login-${skin.name}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a 1024 dp desktop keeps the brand panel whole and says it once',
    (tester) async {
      await harness.session.logout();
      await harness.mount(
        tester,
        ZolnitSkin.linux,
        locale: const Locale('en'),
        size: const Size(1024, 768),
      );
      expect(find.byKey(const ValueKey('zolnit-brand-panel')), findsOneWidget);
      for (final label in [
        'Selected global routes',
        'Familiar on every screen',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width + 0.5),
          reason: label,
        );
      }
      expect(find.text('A LITTLE CLOSER TO YOUR WORLD'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.capture(tester, 'login-linux-1024');
    },
  );

  testWidgets('website entries use their own callbacks and legacy fallback', (
    tester,
  ) async {
    var website = 0;
    var registration = 0;
    var recovery = 0;
    await mountLogin(
      tester,
      ZolnitSkin.macos,
      openWebsite: () => website++,
      openRegistration: () => registration++,
      openRecovery: () => recovery++,
    );
    await tester.tap(find.text('注册'));
    await tester.tap(find.text('忘记密码？'));
    await tester.tap(find.text('打开 ZolNit 网站'));
    expect((website, registration, recovery), (1, 1, 1));

    await mountLogin(tester, ZolnitSkin.macos, openWebsite: () => website++);
    await tester.tap(find.text('注册'));
    await tester.tap(find.text('忘记密码？'));
    expect(website, 3);
  });

  test('registration callback exchanges a single matching PKCE return', () async {
    await harness.session.logout();
    harness.requests.clear();
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-registration/exchange')) {
        return zolnitJson({'auth_data': 'Bearer exchanged'});
      }
      return zolnitPanelFixture(request);
    };
    final browser = _RegistrationBrowser();
    final store = _RegistrationAttemptStore();
    final coordinator = ZolnitRegistrationCoordinator(
      session: harness.session,
      browser: browser,
      store: store,
      randomBytes: (length) => List<int>.filled(length, 0),
    );
    final registration = await coordinator.begin();
    final parameters = Uri.parse(
      'https://link.zolmid.com${registration.fragment}',
    ).queryParameters;
    final state = parameters['sso_state'];

    expect(registration.path, isEmpty);
    expect(parameters['sso_challenge']?.length, 43);
    expect(state, 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    expect(
      await coordinator.accept(
        Uri.parse(
          'zolnit://auth/register#code=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&state=wrong',
        ),
      ),
      isFalse,
    );
    expect(store.reads, 0);
    expect(
      await coordinator.accept(
        Uri.parse(
          'zolnit://auth/register#code=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&state=$state',
        ),
      ),
      isTrue,
    );
    expect(
      harness.requests
          .where(
            (request) =>
                request.url.path.endsWith('/zolnit-registration/exchange'),
          )
          .length,
      1,
    );
    expect(browser.closes, 1);
    expect(
      await coordinator.accept(
        Uri.parse(
          'zolnit://auth/register#code=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&state=$state',
        ),
      ),
      isFalse,
    );
    coordinator.dispose();
  });

  test('only the first-party registration site can navigate in-app', () {
    expect(
      isZolnitRegistrationWebsiteNavigation(
        Uri.parse('https://link.zolmid.com/#/register'),
      ),
      isTrue,
    );
    for (final url in [
      'http://link.zolmid.com/#/register',
      'https://link.zolmid.com:444/#/register',
      'https://user@link.zolmid.com/#/register',
      'https://link.zolmid.com.evil.example/#/register',
    ]) {
      expect(isZolnitRegistrationWebsiteNavigation(Uri.parse(url)), isFalse);
    }
  });

  test('a persisted ceremony survives replacement before its callback', () async {
    await harness.session.logout();
    harness.requests.clear();
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-registration/exchange')) {
        return zolnitJson({'auth_data': 'Bearer exchanged'});
      }
      return zolnitPanelFixture(request);
    };
    final store = _RegistrationAttemptStore();
    final first = ZolnitRegistrationCoordinator(
      session: harness.session,
      browser: _RegistrationBrowser(),
      store: store,
      randomBytes: (length) => List<int>.filled(length, 0),
    );
    final registration = await first.begin();
    final state = Uri.parse(
      'https://link.zolmid.com${registration.fragment}',
    ).queryParameters['sso_state'];
    first.dispose();
    final restored = ZolnitRegistrationCoordinator(
      session: harness.session,
      browser: _RegistrationBrowser(),
      store: store,
      randomBytes: (length) => List<int>.filled(length, 1),
    );

    expect(
      await restored.accept(
        Uri.parse(
          'zolnit://auth/register#code=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&state=$state',
        ),
      ),
      isTrue,
    );
    expect(store.value, isNull);
    restored.dispose();
  });

  test('manual login cancels a pending registration callback', () async {
    await harness.session.logout();
    harness.requests.clear();
    final browser = _RegistrationBrowser();
    final coordinator = ZolnitRegistrationCoordinator(
      session: harness.session,
      browser: browser,
      store: _RegistrationAttemptStore(),
      randomBytes: (length) => List<int>.filled(length, 0),
    );

    expect(await coordinator.start(), isTrue);
    final state = Uri.parse(
      'https://link.zolmid.com${browser.registration!.fragment}',
    ).queryParameters['sso_state'];
    await harness.session.login('manual@example.com', 'password123');
    browser.onReturn!(
      Uri.parse(
        'zolnit://auth/register#code=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&state=$state',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      harness.requests.where(
        (request) => request.url.path.endsWith('/zolnit-registration/exchange'),
      ),
      isEmpty,
    );
    coordinator.dispose();
  });

  test('a failed in-app launch leaves manual login actionable', () async {
    await harness.session.logout();
    final coordinator = ZolnitRegistrationCoordinator(
      session: harness.session,
      browser: _RegistrationBrowser(launches: false),
      store: _RegistrationAttemptStore(),
      randomBytes: (length) => List<int>.filled(length, 0),
    );

    expect(await coordinator.start(), isFalse);
    expect(harness.session.authenticated, isFalse);
    expect(harness.session.failure, 'registration_browser_unavailable');
    coordinator.dispose();
  });

  testWidgets('invalid inputs never start login', (tester) async {
    await mountLogin(tester, ZolnitSkin.macos);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    expect(harness.requests, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('zolnit-email')),
      'lin@example.com',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('zolnit-password')),
        matching: find.byType(TextFormField),
      ),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    expect(harness.requests, isEmpty);
  });

  testWidgets('storage recovery failure is not shown as a network error', (
    tester,
  ) async {
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: Builder(
        builder: (context) =>
            Text(zolnitFailureText(context, 'storage_unavailable', null)),
      ),
    );

    expect(
      find.text('ZolNit 无法使用系统钥匙串保存登录信息。请解锁系统钥匙串（Linux 上为登录密钥环）后重试。'),
      findsOneWidget,
    );
    expect(find.text('网络异常，请检查连接后重试'), findsNothing);
  });

  testWidgets('pending failure locks fields and clears attempted password', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var attempts = 0;
    harness.panel = (request) {
      if (request.url.path.endsWith('/login')) {
        attempts++;
        return response.future;
      }
      return zolnitPanelFixture(request);
    };
    await mountLogin(tester, ZolnitSkin.macos);
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    expect(attempts, 1);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('zolnit-email')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<SecretTextFormField>(
            find.byKey(const ValueKey('zolnit-password')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('zolnit-sign-in')))
          .onPressed,
      isNull,
    );
    response.complete(http.Response('{"message":"Invalid credentials"}', 401));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(harness.session.failure, isNotNull);
    expect(find.byType(ZolnitFailureMessage), findsOneWidget);
    expect(
      tester
          .widget<SecretTextFormField>(
            find.byKey(const ValueKey('zolnit-password')),
          )
          .controller
          .text,
      isEmpty,
    );
    expect(find.text('password123'), findsNothing);
  });

  testWidgets('a replaced account cannot receive an old login callback', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var signedIn = 0;
    harness.panel = (request) {
      if (request.url.path.endsWith('/login') &&
          request.body.contains('lin@example.com')) {
        return pending.future;
      }
      return zolnitPanelFixture(request);
    };
    await mountLogin(
      tester,
      ZolnitSkin.macos,
      onSignedIn: () async {
        signedIn++;
      },
    );
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    await harness.session.logout();
    await harness.session.login('other@example.com', 'password123');
    expect(harness.session.authenticated, isTrue);
    pending.complete(
      http.Response('{"data":{"auth_data":"Bearer previous"}}', 200),
    );
    await tester.pumpAndSettle();
    expect(signedIn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed login does not call signed-in callback', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var signedIn = 0;
    harness.panel = (request) => request.url.path.endsWith('/login')
        ? response.future
        : zolnitPanelFixture(request);
    await mountLogin(
      tester,
      ZolnitSkin.macos,
      onSignedIn: () async => signedIn++,
    );
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(
      http.Response('{"data":{"auth_data":"Bearer fixture"}}', 200),
    );
    await tester.pump();
    expect(signedIn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp large text and short viewport scroll without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mountLogin(
      tester,
      ZolnitSkin.ios,
      size: const Size(320, 480),
      host: true,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zolnit-sign-in')), findsOneWidget);
    await harness.capture(tester, 'login-ios-320-text-scale');
    expect(tester.takeException(), isNull);
  });
}
