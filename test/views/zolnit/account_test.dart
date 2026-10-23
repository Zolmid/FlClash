import 'dart:async';

import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/zolnit/catalogue.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  testWidgets('an order payment selection resets when the account changes', (
    tester,
  ) async {
    harness.panel = (request) {
      if (request.url.path.endsWith('/getPaymentMethod')) {
        return zolnitJson([
          {'id': 1, 'name': 'First method'},
          {'id': 2, 'name': 'Second method'},
        ]);
      }
      if (request.url.path.endsWith('/order/fetch')) {
        return zolnitJson([
          {'trade_no': 'orderA', 'status': 0, 'total_amount': 1200},
        ]);
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await harness.session.refreshBilling();
    Future<void> mount() => harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitOrdersPage(session: harness.session),
    );
    await mount();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second method').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      2,
    );

    await harness.relogin();
    await harness.session.refreshBilling();
    await mount();
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> openAccount(
    WidgetTester tester,
    ZolnitSkin skin, {
    bool dark = false,
    Size? size,
    Locale locale = const Locale('zh', 'CN'),
  }) async {
    await harness.mount(tester, skin, dark: dark, size: size, locale: locale);
    await tester.tap(
      find.text(locale.languageCode == 'en' ? 'Account' : '账号').first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> password(WidgetTester tester, String old, String fresh) async {
    for (final (key, value) in [
      ('zolnit-old-password', old),
      ('zolnit-new-password', fresh),
    ]) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextField),
        ),
        value,
      );
    }
  }

  for (final skin in ZolnitSkin.values) {
    testWidgets('account shows real panel fields on ${skin.name}', (
      tester,
    ) async {
      await openAccount(tester, skin);
      expect(find.text('我的账户'), findsOneWidget);
      expect(find.text('账号信息'), findsOneWidget);
      expect(find.text('订单记录'), findsOneWidget);
      expect(find.text('邀请有礼'), findsOneWidget);
      expect(find.text('lin@example.com'), findsOneWidget);
      expect(find.text('¥0.00'), findsOneWidget);
      await harness.capture(tester, 'account-${skin.name}');
      if (!skin.desktop) {
        await tester.scrollUntilVisible(find.text('MacBook Air'), 250);
        await tester.pumpAndSettle();
      }
      expect(find.text('登录会话'), findsOneWidget);
      expect(find.text('MacBook Air'), findsOneWidget);
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      expect(find.text('当前设备'), findsNothing);
      if (!skin.desktop) {
        await harness.capture(tester, 'account-${skin.name}-scrolled');
      }
    });
  }

  testWidgets(
    'session revocation waits for confirmation and reloads the list',
    (tester) async {
      var revoked = false;
      harness.panel = (request) {
        if (request.url.path.endsWith('/removeActiveSession')) {
          revoked = true;
          expect(request.body, '{"session_id":"41"}');
          return zolnitJson(true);
        }
        if (revoked && request.url.path.endsWith('/getActiveSession')) {
          return zolnitJson([]);
        }
        return zolnitPanelFixture(request);
      };
      await openAccount(tester, ZolnitSkin.macos);
      await tester.tap(find.byKey(const ValueKey('zolnit-revoke-41')));
      await tester.pumpAndSettle();
      expect(revoked, isFalse);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(revoked, isTrue);
      expect(find.text('MacBook Air'), findsNothing);
      expect(find.text('暂无可显示的登录会话。'), findsOneWidget);
    },
  );

  testWidgets(
    'session load failure can be retried without losing the profile',
    (tester) async {
      var fail = true;
      harness.panel = (request) =>
          fail && request.url.path.endsWith('/getActiveSession')
          ? http.Response('{"message":"Server Error"}', 503)
          : zolnitPanelFixture(request);
      await openAccount(tester, ZolnitSkin.macos);
      expect(find.text('lin@example.com'), findsOneWidget);
      expect(find.text('暂时无法获取登录会话，请重试。'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('刷新').last);
      await tester.pumpAndSettle();
      expect(find.text('MacBook Air'), findsOneWidget);
    },
  );

  testWidgets('password form validates before posting and hides secrets', (
    tester,
  ) async {
    harness.panel = (request) => request.url.path.endsWith('/changePassword')
        ? zolnitJson(true)
        : zolnitPanelFixture(request);
    await openAccount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('修改密码'));
    await tester.pumpAndSettle();
    await password(tester, 'oldpass12', 'short');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入当前密码，并使用至少八个字符的不同新密码。'), findsOneWidget);
    expect(
      harness.requests.where((r) => r.url.path.endsWith('/changePassword')),
      isEmpty,
    );
    await password(tester, 'oldpass12', 'differentpass12');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(
      harness.requests.where((r) => r.url.path.endsWith('/changePassword')),
      hasLength(1),
    );
    expect(find.text('密码已更新。'), findsOneWidget);
    expect(find.text('oldpass12'), findsNothing);
    expect(find.text('differentpass12'), findsNothing);
  });

  testWidgets('an old account session response cannot return after sign out', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    harness.panel = (request) => request.url.path.endsWith('/getActiveSession')
        ? pending.future
        : zolnitPanelFixture(request);
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('账号').first);
    await tester.pump();
    harness.session.logout();
    pending.complete(
      zolnitJson([
        {'id': 99, 'name': 'OLD_SESSION'},
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('OLD_SESSION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dark and narrow account pages keep controls within the viewport',
    (tester) async {
      await openAccount(tester, ZolnitSkin.macos, dark: true);
      await harness.capture(tester, 'account-macos-dark');
      await openAccount(
        tester,
        ZolnitSkin.ios,
        locale: const Locale('en'),
        size: const Size(320, 640),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final skin in ZolnitSkin.values) {
    testWidgets('preferences uses existing settings on ${skin.name}', (
      tester,
    ) async {
      await openAccount(tester, skin);
      final preferences = find.text('偏好设置', skipOffstage: false).last;
      await tester.ensureVisible(preferences);
      await tester.pumpAndSettle();
      await tester.tap(preferences);
      await tester.pumpAndSettle();
      expect(find.text('按你的习惯连接。'), findsOneWidget);
      expect(find.text('启动后自动连接'), findsOneWidget);
      expect(find.text('重新连接'), findsNothing);
      expect(harness.container.read(appSettingProvider).autoRun, isFalse);
      await harness.capture(tester, 'preferences-${skin.name}');
      harness.requests.clear();
      await tester.tap(find.byKey(const ValueKey('zolnit-auto-connect')));
      await tester.pumpAndSettle();
      expect(harness.container.read(appSettingProvider).autoRun, isTrue);
      expect(harness.requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }

  testWidgets('switching to orders tab shows the orders page', (tester) async {
    await openAccount(tester, ZolnitSkin.macos);
    expect(find.text('账号信息'), findsOneWidget);
    await tester.tap(find.text('订单记录'));
    await tester.pumpAndSettle();
    expect(find.text('暂无订单'), findsOneWidget);
  });

  testWidgets('switching to invite tab shows invite data', (tester) async {
    await openAccount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('邀请有礼'));
    await tester.pumpAndSettle();
    expect(find.text('好体验，值得分享。'), findsOneWidget);
    expect(find.text('TESTINVITE'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });
}
