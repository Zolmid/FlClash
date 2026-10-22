import 'dart:async';

import 'package:fl_clash/views/zolnit/auth.dart';
import 'package:fl_clash/views/zolnit/brand.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

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
    harness.session.logout();
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
    harness.session.logout();
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
