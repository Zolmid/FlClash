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
      expect(find.text('你好，Lin。'), findsOneWidget);
      expect(find.text('当前尚未连接'), findsOneWidget);
      expect(find.text('轻享'), findsWidgets);
      expect(find.textContaining('85.6'), findsOneWidget);
      expect(find.text('香港 · 轻风 01'), findsWidgets);
      if (skin.desktop) {
        expect(find.text('一份更轻盈的连接体验'), findsOneWidget);
      }
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await harness.capture(tester, 'connect-${skin.name}');
      if (!skin.desktop) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(find.text('一份更轻盈的连接体验'), findsOneWidget);
        await harness.capture(tester, 'connect-${skin.name}-scrolled');
      }
    });
  }

  for (final skin in [ZolnitSkin.macos, ZolnitSkin.ios]) {
    testWidgets(
      'connect page keeps its contrast in dark mode on ${skin.name}',
      (tester) async {
        await harness.mount(tester, skin, dark: true);
        expect(find.text('你好，Lin。'), findsOneWidget);
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
    expect(find.text('未订阅'), findsOneWidget);
    expect(find.text('暂无有效套餐'), findsOneWidget);
    expect(find.text('选择套餐'), findsOneWidget);
    expect(find.text('暂无公告'), findsOneWidget);
    expect(find.text('当前订阅暂无可用节点。'), findsWidgets);
    expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
    await harness.capture(tester, 'connect-macos-empty');
  });

  testWidgets('English labels fit a 320 dp wide phone', (tester) async {
    for (final skin in [ZolnitSkin.ios, ZolnitSkin.android]) {
      await harness.mount(
        tester,
        skin,
        locale: const Locale('en'),
        size: const Size(320, 640),
      );
      expect(find.text('Hello, Lin.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
