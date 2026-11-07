import 'package:fl_clash/views/zolnit/brand.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  for (final skin in ZolnitSkin.values) {
    testWidgets('connect page renders the account data on ${skin.name}', (
      tester,
    ) async {
      await harness.mount(tester, skin);
      expect(find.text('当前尚未连接'), findsOneWidget);
      expect(find.text('轻享'), findsWidgets);
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await harness.capture(tester, 'connect-${skin.name}');
      if (!skin.desktop) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        await harness.capture(tester, 'connect-${skin.name}-scrolled');
      }
    });
  }

  for (final skin in [ZolnitSkin.macos, ZolnitSkin.ios]) {
    testWidgets(
      'connect page keeps its contrast in dark mode on ${skin.name}',
      (tester) async {
        await harness.mount(tester, skin, dark: true);
        expect(find.text('轻享'), findsWidgets);
        await harness.capture(tester, 'connect-${skin.name}-dark');
      },
    );
  }

  testWidgets('an account without a plan, nodes or notices says so plainly', (
    tester,
  ) async {
    harness.panel = zolnitEmptyPanelFixture;
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    expect(find.text('暂无有效套餐'), findsOneWidget);
    expect(find.text('当前套餐暂无可用线路。'), findsWidgets);
    expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
    await harness.capture(tester, 'connect-macos-empty');
  });

  testWidgets(
    'a wide home shows servers and the latest notice; phones do not',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.ios);
      expect(find.text('线路：3'), findsNothing);
      expect(find.text('一份更轻盈的连接体验'), findsNothing);
      await harness.mount(tester, ZolnitSkin.macos);
      expect(find.text('线路：3'), findsOneWidget);
      expect(find.text('一份更轻盈的连接体验'), findsOneWidget);
      expect(find.text('SG · 狮城 01'), findsOneWidget);
      await tester.tap(find.text('线路：3'));
      await tester.pumpAndSettle();
      expect(find.text('搜索线路或地区'), findsOneWidget);
    },
  );

  testWidgets('a narrow desktop window stacks the dashboard without overflow', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.windows, size: const Size(900, 700));
    expect(tester.takeException(), isNull);
    await harness.capture(tester, 'connect-windows-narrow');
  });

  testWidgets('a phone keeps its top bar below the status bar', (tester) async {
    const inset = FakeViewPadding(top: 47);
    tester.view.padding = inset;
    tester.view.viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await harness.mount(tester, ZolnitSkin.ios);
    expect(
      tester.getTopLeft(find.byType(ZolnitBrand)).dy,
      greaterThanOrEqualTo(47),
    );
  });

  testWidgets('English labels fit a 320 dp wide phone', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final skin in [ZolnitSkin.ios, ZolnitSkin.android]) {
      await harness.mount(
        tester,
        skin,
        locale: const Locale('en'),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
