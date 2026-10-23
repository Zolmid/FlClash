import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  Future<void> openPlans(
    WidgetTester tester,
    ZolnitSkin skin, {
    bool dark = false,
    Locale locale = const Locale('zh', 'CN'),
    Size? size,
    String label = '套餐',
  }) async {
    await harness.mount(tester, skin, dark: dark, locale: locale, size: size);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  int saved() => harness.requests
      .where((request) => request.url.path.endsWith('/order/save'))
      .length;

  for (final skin in ZolnitSkin.values) {
    testWidgets('plans page renders the panel plans on ${skin.name}', (
      tester,
    ) async {
      await openPlans(tester, skin);
      expect(find.text('刚刚好的套餐，刚刚好的自由。'), findsOneWidget);
      expect(find.text('当前套餐 · 轻享'), findsOneWidget);
      for (final name in ['轻享', '畅享', '尊享']) {
        expect(find.text(name), findsOneWidget);
      }
      for (final price in ['28', '48', '88']) {
        expect(find.text(price), findsOneWidget);
      }
      expect(find.text('每月 150 GB 高速流量'), findsOneWidget);
      expect(find.text('支持 5 台设备同时在线'), findsOneWidget);
      expect(find.text('覆盖五个常用地区'), findsOneWidget);
      expect(find.text('适合浏览、办公与轻量影音'), findsOneWidget);
      expect(find.text('续费当前套餐'), findsOneWidget);
      expect(find.text('选择套餐'), findsNWidgets(2));
      expect(find.text('当前套餐'), findsOneWidget);
      expect(find.textContaining('预览'), findsNothing);
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await harness.capture(tester, 'plans-${skin.name}');
      if (!skin.desktop) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        await harness.capture(tester, 'plans-${skin.name}-scrolled');
      }
    });
  }

  testWidgets(
    'a longer billing cycle shows the monthly equivalent and saving',
    (tester) async {
      await openPlans(tester, ZolnitSkin.macos);
      expect(find.text('省 20%'), findsOneWidget);
      expect(find.text('省 5%'), findsOneWidget);
      expect(find.text('按月付费，轻松开始'), findsNWidgets(3));
      await tester.tap(find.text('年付'));
      await tester.pumpAndSettle();
      expect(find.text('22.4'), findsOneWidget);
      expect(find.text('每年 ¥268.80，一次支付'), findsOneWidget);
      expect(find.text('按月付费，轻松开始'), findsNothing);
      await harness.capture(tester, 'plans-macos-yearly');
    },
  );

  testWidgets('site plan markup preserves total quotas and purchase notes', (
    tester,
  ) async {
    const note = '总流量不按月清零。再次购买会重置额度，余量不叠加。';
    harness.panel = (request) => request.url.path.endsWith('/plan/fetch')
        ? zolnitJson([
            {
              'id': 7,
              'name': '按量 · 轻用',
              'content':
                  '<div class="zn-plan">'
                  '<span class="zn-plan-badge">不限时</span>'
                  '<p class="zn-plan-scene">偶尔使用，按需连接</p>'
                  '<p class="zn-plan-metric">'
                  '<strong>200</strong><span>GiB / 总量</span></p>'
                  '<p class="zn-plan-metric-label">不限时 · 用完为止</p>'
                  '<ul class="zn-plan-features">'
                  '<li>最高 200 Mbps</li><li>2 个同时在线 IP</li>'
                  '<li>REALITY / HY2 双协议</li></ul>'
                  '<p class="zn-plan-note">$note</p></div>',
              'transfer_enable': 200,
              'device_limit': 2,
              'speed_limit': 200,
              'onetime_price': 1900,
            },
          ])
        : zolnitPanelFixture(request);
    await harness.relogin();
    for (final skin in [ZolnitSkin.macos, ZolnitSkin.ios]) {
      await openPlans(tester, skin);
      expect(find.text('偶尔使用，按需连接'), findsOneWidget);
      expect(find.text('200 GiB / 总量 · 不限时 · 用完为止'), findsOneWidget);
      expect(find.text('最高 200 Mbps'), findsOneWidget);
      expect(find.text('2 个同时在线 IP'), findsOneWidget);
      expect(find.text('REALITY / HY2 双协议'), findsOneWidget);
      expect(find.text(note), findsOneWidget);
      expect(find.text('每月 200 GB 高速流量'), findsNothing);
      expect(find.text('支持 2 台设备同时在线'), findsNothing);
      expect(find.text('19'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(saved(), 0);
  });

  testWidgets('a confirmed purchase creates the order and opens the orders', (
    tester,
  ) async {
    await openPlans(tester, ZolnitSkin.macos);
    final choose = find.text('选择套餐').first;
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.text('创建订单'), findsOneWidget);
    expect(find.text('畅享 · ¥48.00'), findsOneWidget);
    expect(saved(), 0);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    final request = harness.requests.singleWhere(
      (request) => request.url.path.endsWith('/order/save'),
    );
    expect(request.method, 'POST');
    expect(request.body, contains('"plan_id":2'));
    expect(request.body, contains('"period":"month_price"'));
    expect(find.text('刚刚好的套餐，刚刚好的自由。'), findsNothing);
    expect(find.text('订单记录'), findsWidgets);
  });

  testWidgets('declining the confirmation creates nothing', (tester) async {
    await openPlans(tester, ZolnitSkin.macos);
    final choose = find.text('选择套餐').first;
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(saved(), 0);
    expect(find.text('刚刚好的套餐，刚刚好的自由。'), findsOneWidget);
  });

  testWidgets('monthly enrollment is offered per configured channel only', (
    tester,
  ) async {
    harness.panel = (request) =>
        request.url.path.endsWith('/zolnit-stripe/config')
        ? zolnitJson({
            'enabled': true,
            'configured': true,
            'channels': [
              {'id': 1, 'name': 'Stripe', 'enabled': true, 'configured': true},
              {'id': 2, 'name': 'Off', 'enabled': false, 'configured': true},
            ],
          })
        : zolnitPanelFixture(request);
    await harness.relogin();
    await openPlans(tester, ZolnitSkin.macos);
    for (final plan in [1, 2, 3]) {
      expect(find.byKey(ValueKey('zolnit-monthly-$plan-1')), findsOneWidget);
      expect(find.byKey(ValueKey('zolnit-monthly-$plan-2')), findsNothing);
    }
    expect(find.text('查看包月报价 · Stripe'), findsNWidgets(3));
    await tester.tap(find.text('年付'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zolnit-monthly-1-1')), findsNothing);
  });

  testWidgets('without a recurring channel no enrollment is offered', (
    tester,
  ) async {
    await openPlans(tester, ZolnitSkin.macos);
    expect(find.byKey(const ValueKey('zolnit-monthly-1-1')), findsNothing);
    expect(find.text('连续包月'), findsNothing);
    expect(find.text('选择套餐'), findsNWidgets(2));
  });

  testWidgets('an account without plans shows a plain empty state', (
    tester,
  ) async {
    harness.panel = zolnitEmptyPanelFixture;
    await harness.relogin();
    await openPlans(tester, ZolnitSkin.macos);
    expect(find.text('暂无有效套餐'), findsOneWidget);
    expect(find.text('你还没有有效套餐，选择一个开始使用。'), findsOneWidget);
    expect(find.text('选择套餐'), findsNothing);
  });

  testWidgets('dark theme keeps the plan cards legible', (tester) async {
    await openPlans(tester, ZolnitSkin.macos, dark: true);
    expect(find.text('畅享'), findsOneWidget);
    await harness.capture(tester, 'plans-macos-dark');
  });

  testWidgets('English labels fit a 320 dp wide phone', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final skin in [ZolnitSkin.ios, ZolnitSkin.android]) {
      await openPlans(
        tester,
        skin,
        locale: const Locale('en'),
        size: const Size(320, 640),
        label: 'Plans',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      await tester.pumpAndSettle();
      expect(
        find.text('Current plan · 轻享', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
