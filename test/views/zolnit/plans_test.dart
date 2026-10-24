import 'dart:async';

import 'package:fl_clash/views/zolnit/account.dart';
import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  Map<String, dynamic> quoteOffer(String period, {int? expiresAt}) => {
    'available': true,
    'period': period,
    'months': {
      'monthly': 1,
      'quarterly': 3,
      'half_yearly': 6,
      'yearly': 12,
      'two_yearly': 24,
      'three_yearly': 36,
    }[period],
    'currency': 'CNY',
    'charge_currency': 'SGD',
    'price_cents': 2800,
    'recurring_price_cents': 2520,
    'handling_amount_cents': 0,
    'recurring_total_cents': 2520,
    'charge_amount_cents': 550,
    'first_total_cents': 701,
    'first_charge_amount_cents': 202,
    'surplus_amount_cents': 1819,
    'surplus_credit_cents': 0,
    'quote_id': 81,
    'quote_expires_at':
        expiresAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
    'gift_replacement': false,
    'switch_immediately': true,
    'next_charge_at': null,
  };

  Object quoteBody(
    String period, {
    int? expiresAt,
    String? unavailableReason,
  }) => {
    'plans': [
      for (final id in [1, 2, 3])
        {
          'id': id,
          'periods': [
            unavailableReason != null && id == 2
                ? {
                    'period': period,
                    'available': false,
                    'unavailable_reason': unavailableReason,
                  }
                : quoteOffer(period, expiresAt: expiresAt),
          ],
        },
    ],
  };

  http.Response configuredChannels() => zolnitJson({
    'enabled': true,
    'configured': true,
    'channels': [
      {'id': 1, 'name': 'Stripe', 'enabled': true, 'configured': true},
    ],
  });

  List<http.Request> quoteRequests() => harness.requests
      .where((request) => request.url.path.endsWith('/zolnit-stripe/plans'))
      .toList();
  void expectReadOnly() {
    expect(
      harness.requests.where(
        (request) =>
            request.method != 'GET' && !request.url.path.endsWith('/login'),
      ),
      isEmpty,
    );
  }

  int saved() => harness.requests
      .where((request) => request.url.path.endsWith('/order/save'))
      .length;

  for (final skin in ZolnitSkin.values) {
    testWidgets('plans page renders the panel plans on ${skin.name}', (
      tester,
    ) async {
      await openPlans(tester, skin);
      expect(
        find.descendant(
          of: find.byType(ZolnitPageHeading),
          matching: find.text('套餐'),
        ),
        findsOneWidget,
      );
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
    expect(find.byType(ZolnitPageHeading), findsNothing);
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
    expect(
      find.descendant(
        of: find.byType(ZolnitPageHeading),
        matching: find.text('套餐'),
      ),
      findsOneWidget,
    );
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
    expect(find.text('查看包月报价 · Stripe'), findsNothing);
    expect(
      harness.requests.where(
        (request) => request.url.path.endsWith('/zolnit-stripe/plans'),
      ),
      hasLength(1),
    );
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

  for (final skin in ZolnitSkin.values) {
    testWidgets(
      'selected period strictly filters supported zero-price plans on ${skin.name}',
      (tester) async {
        harness.panel = (request) => request.url.path.endsWith('/plan/fetch')
            ? zolnitJson([
                {
                  'id': 10,
                  'name': 'CycleOnly',
                  'month_price': 0,
                  'quarter_price': 1200,
                  'half_year_price': 2200,
                  'year_price': 4200,
                  'two_year_price': 8000,
                  'three_year_price': 11000,
                },
                {'id': 20, 'name': 'OnceOnly', 'onetime_price': 0},
                {'id': 30, 'name': 'QuarterOnly', 'quarter_price': 0},
                {'id': 40, 'name': 'ResetOnly', 'reset_price': 0},
              ])
            : zolnitPanelFixture(request);
        await harness.relogin();
        await openPlans(tester, skin);
        expect(find.text('CycleOnly'), findsOneWidget);
        expect(find.text('OnceOnly'), findsNothing);
        expect(find.text('QuarterOnly'), findsNothing);
        expect(find.text('0'), findsOneWidget);
        await tester.tap(find.text('季付'));
        await tester.pumpAndSettle();
        expect(find.text('CycleOnly'), findsOneWidget);
        expect(find.text('QuarterOnly'), findsOneWidget);
        expect(find.text('OnceOnly'), findsNothing);
        for (final period in ['半年付', '年付', '两年付', '三年付']) {
          await tester.tap(find.text(period));
          await tester.pumpAndSettle();
          expect(find.text('CycleOnly'), findsOneWidget);
          expect(find.text('OnceOnly'), findsNothing);
          expect(find.text('QuarterOnly'), findsNothing);
        }
        await tester.tap(find.text('一次性'));
        await tester.pumpAndSettle();
        expect(find.text('OnceOnly'), findsOneWidget);
        expect(find.text('CycleOnly'), findsNothing);
        expect(find.text('0'), findsOneWidget);
        await tester.tap(find.text('重置流量'));
        await tester.pumpAndSettle();
        expect(find.text('ResetOnly'), findsOneWidget);
        expect(find.text('OnceOnly'), findsNothing);
        expect(find.text('CycleOnly'), findsNothing);
        expectReadOnly();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'entering plans automatically batches server quotes without writes on ${skin.name}',
      (tester) async {
        final response = Completer<http.Response>();
        harness.panel = (request) {
          if (request.url.path.endsWith('/zolnit-stripe/config')) {
            return configuredChannels();
          }
          if (request.url.path.endsWith('/zolnit-stripe/plans')) {
            return response.future;
          }
          return zolnitPanelFixture(request);
        };
        await harness.relogin();
        await openPlans(tester, skin);
        expect(quoteRequests(), hasLength(1));
        expect(quoteRequests().single.url.queryParameters, {
          'payment_id': '1',
          'period': 'monthly',
        });
        expect(
          harness.requests.where(
            (request) => request.url.path.endsWith('/zolnit-stripe/config'),
          ),
          hasLength(1),
        );
        expect(find.textContaining('查看包月报价'), findsNothing);
        expectReadOnly();
        response.complete(zolnitJson(quoteBody('monthly')));
        await tester.pumpAndSettle();
        expect(find.textContaining('首期付款: ¥7.01'), findsNWidgets(3));
        expect(find.textContaining('后续付款: ¥25.20'), findsNWidgets(3));
        expect(find.text('授权连续包月'), findsNWidgets(3));
        expect(quoteRequests(), hasLength(1));
        expectReadOnly();
        expect(tester.takeException(), isNull);
        await harness.capture(tester, 'plans-auto-quote-${skin.name}');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'failed quote retries once and partial unavailability is actionable',
    (tester) async {
      var failing = true;
      harness.panel = (request) {
        if (request.url.path.endsWith('/zolnit-stripe/config')) {
          return configuredChannels();
        }
        if (request.url.path.endsWith('/zolnit-stripe/plans')) {
          return failing
              ? http.Response('{}', 503)
              : zolnitJson(
                  quoteBody('monthly', unavailableReason: 'pending_order'),
                );
        }
        return zolnitPanelFixture(request);
      };
      await harness.relogin();
      await openPlans(tester, ZolnitSkin.macos);
      expect(find.text('暂时无法获取报价，请重试。'), findsNWidgets(3));
      expect(find.text('授权连续包月'), findsNothing);
      failing = false;
      await tester.ensureVisible(find.text('重试').first);
      await tester.tap(find.text('重试').first);
      await tester.pumpAndSettle();
      expect(quoteRequests(), hasLength(2));
      expect(find.textContaining('待处理订单'), findsOneWidget);
      expect(find.text('授权连续包月'), findsNWidgets(2));
      expectReadOnly();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in [404, 503]) {
    testWidgets(
      'configuration failure $status waits for explicit quote retry',
      (tester) async {
        var configurationReads = 0;
        var failing = true;
        harness.panel = (request) {
          if (request.url.path.endsWith('/zolnit-stripe/config')) {
            configurationReads++;
            if (failing) {
              return configurationReads < 3
                  ? http.Response('{}', status)
                  : zolnitJson({'enabled': false, 'configured': false});
            }
            return configuredChannels();
          }
          if (request.url.path.endsWith('/zolnit-stripe/plans')) {
            return zolnitJson(quoteBody('monthly'));
          }
          return zolnitPanelFixture(request);
        };
        await harness.relogin();
        await openPlans(tester, ZolnitSkin.macos);
        expect(configurationReads, 1);
        expect(quoteRequests(), isEmpty);
        expect(find.text('暂时无法获取报价，请重试。'), findsNWidgets(3));
        expect(find.text('加载中…'), findsNothing);
        expect(harness.session.busy, isFalse);
        await tester.pump(const Duration(seconds: 1));
        expect(configurationReads, 1);
        failing = false;
        final retry = find.text('重试').first;
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(configurationReads, 2);
        expect(quoteRequests(), hasLength(1));
        expect(find.text('授权连续包月'), findsNWidgets(3));
        expectReadOnly();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('configuration refresh failure waits for explicit quote retry', (
    tester,
  ) async {
    var configurationReads = 0;
    var failureReads = 0;
    var failing = false;
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-stripe/config')) {
        configurationReads++;
        if (failing) {
          return ++failureReads < 3
              ? http.Response('{}', 503)
              : zolnitJson({'enabled': false, 'configured': false});
        }
        return configuredChannels();
      }
      if (request.url.path.endsWith('/zolnit-stripe/plans')) {
        return zolnitJson(quoteBody('monthly'));
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await openPlans(tester, ZolnitSkin.macos);
    expect(configurationReads, 1);
    expect(quoteRequests(), hasLength(1));
    failing = true;
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('套餐').first);
    await tester.pumpAndSettle();
    expect(configurationReads, 2);
    expect(quoteRequests(), hasLength(1));
    expect(find.text('授权连续包月'), findsNothing);
    expect(find.textContaining('首期付款'), findsNothing);
    expect(find.text('暂时无法获取报价，请重试。'), findsNWidgets(3));
    expect(find.text('加载中…'), findsNothing);
    expect(harness.session.busy, isFalse);
    failing = false;
    final retry = find.text('重试').first;
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(configurationReads, 3);
    expect(quoteRequests(), hasLength(2));
    expect(find.text('授权连续包月'), findsNWidgets(3));
    expectReadOnly();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'expired quotes stop authorization and explicit retry refreshes the batch',
    (tester) async {
      var expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3;
      harness.panel = (request) {
        if (request.url.path.endsWith('/zolnit-stripe/config')) {
          return configuredChannels();
        }
        if (request.url.path.endsWith('/zolnit-stripe/plans')) {
          return zolnitJson(quoteBody('monthly', expiresAt: expiry));
        }
        return zolnitPanelFixture(request);
      };
      await harness.relogin();
      await openPlans(tester, ZolnitSkin.macos);
      expect(find.text('授权连续包月'), findsNWidgets(3));
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('报价已过期，请刷新后重试。'), findsNWidgets(3));
      expect(find.text('授权连续包月'), findsNothing);
      expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
      await tester.ensureVisible(find.text('重试').first);
      await tester.tap(find.text('重试').first);
      await tester.pumpAndSettle();
      expect(quoteRequests(), hasLength(2));
      expect(find.text('授权连续包月'), findsNWidgets(3));
      expectReadOnly();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('period change ignores the preceding quote response', (
    tester,
  ) async {
    final monthly = Completer<http.Response>();
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-stripe/config')) {
        return configuredChannels();
      }
      if (request.url.path.endsWith('/zolnit-stripe/plans')) {
        final period = request.url.queryParameters['period']!;
        return period == 'monthly'
            ? monthly.future
            : zolnitJson(quoteBody(period));
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await openPlans(tester, ZolnitSkin.macos);
    await tester.tap(find.text('年付'));
    await tester.pumpAndSettle();
    expect(
      quoteRequests().map((request) => request.url.queryParameters['period']),
      ['monthly'],
    );
    monthly.complete(zolnitJson(quoteBody('monthly')));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法获取报价，请重试。'), findsNothing);
    expect(find.text('授权连续包月'), findsNothing);
    expect(find.textContaining('首期付款'), findsNothing);
    expect(find.textContaining('后续付款'), findsNothing);
    expect(find.text('本次报价'), findsNothing);
    expect(find.text('每年 ¥268.80，一次支付'), findsOneWidget);
    expectReadOnly();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final skin in ZolnitSkin.values) {
    testWidgets(
      'ordinary cycles never request recurring quotes on ${skin.name}',
      (tester) async {
        harness.panel = (request) {
          if (request.url.path.endsWith('/plan/fetch')) {
            return zolnitJson([
              {
                'id': 8,
                'name': 'Ordinary',
                'quarter_price': 1200,
                'half_year_price': 2200,
                'year_price': 4200,
                'two_year_price': 8000,
                'three_year_price': 11000,
                'onetime_price': 1500,
                'reset_price': 500,
              },
            ]);
          }
          if (request.url.path.endsWith('/zolnit-stripe/config')) {
            return configuredChannels();
          }
          return zolnitPanelFixture(request);
        };
        await harness.relogin();
        await openPlans(tester, skin);
        for (final label in ['季付', '半年付', '年付', '两年付', '三年付', '一次性', '重置流量']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text('Ordinary'), findsOneWidget);
          expect(quoteRequests(), isEmpty);
          expect(find.text('连续包月'), findsNothing);
          expect(find.text('本次报价'), findsNothing);
          expect(find.textContaining('首期付款'), findsNothing);
          expect(find.textContaining('后续付款'), findsNothing);
          expect(find.text('授权连续包月'), findsNothing);
          expect(tester.takeException(), isNull);
        }
        expectReadOnly();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final value in [
    (
      name: 'pending order opens Orders',
      reason: '请先在‘我的订单’完成或取消待处理订单，再开通连续包月。',
      message:
          'You have a pending order. Continue paying or close it in Orders before placing another.',
      action: 'Orders',
      tab: ZolnitAccountTab.orders,
    ),
    (
      name: 'active renewal opens Account management',
      reason: '请先在个人中心取消原套餐的自动续费，再开通新的连续包月。',
      message:
          "Cancel your current plan's automatic renewal in Account before starting monthly billing for another plan.",
      action: 'Manage automatic renewal',
      tab: ZolnitAccountTab.info,
    ),
    (
      name: 'unknown reason stays localized',
      reason: '当前条件不满足，内部提示不应混入英文界面。',
      message: 'The quote is unavailable. Try again.',
      action: null,
      tab: null,
    ),
  ]) {
    testWidgets('real billing unavailable reason ${value.name}', (
      tester,
    ) async {
      harness.panel = (request) {
        if (request.url.path.endsWith('/zolnit-stripe/config')) {
          return configuredChannels();
        }
        if (request.url.path.endsWith('/zolnit-stripe/plans')) {
          return zolnitJson(
            quoteBody('monthly', unavailableReason: value.reason),
          );
        }
        return zolnitPanelFixture(request);
      };
      await harness.relogin();
      await openPlans(
        tester,
        ZolnitSkin.macos,
        locale: const Locale('en'),
        label: 'Plans',
      );
      final details = find.byKey(const ValueKey('zolnit-monthly-2-1'));
      expect(
        find.descendant(of: details, matching: find.text(value.message)),
        findsOneWidget,
      );
      expect(find.text(value.reason), findsNothing);
      expect(
        find.descendant(
          of: details,
          matching: find.text('Authorize monthly billing'),
        ),
        findsNothing,
      );
      if (value.action case final action?) {
        final button = find.descendant(
          of: details,
          matching: find.text(action),
        );
        expect(button, findsOneWidget);
        if (value.tab == ZolnitAccountTab.info) {
          expect(
            find.descendant(of: details, matching: find.text('Orders')),
            findsNothing,
          );
        }
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          tester.widget<ZolnitAccountPage>(find.byType(ZolnitAccountPage)).tab,
          value.tab,
        );
      } else {
        expect(
          find.descendant(of: details, matching: find.text('Orders')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: details,
            matching: find.text('Manage automatic renewal'),
          ),
          findsNothing,
        );
      }
      expectReadOnly();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('logout and disposal ignore late quotes', (tester) async {
    final response = Completer<http.Response>();
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-stripe/config')) {
        return configuredChannels();
      }
      if (request.url.path.endsWith('/zolnit-stripe/plans')) {
        return response.future;
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await openPlans(tester, ZolnitSkin.macos);
    await harness.session.logout();
    await tester.pumpAndSettle();
    response.complete(zolnitJson(quoteBody('monthly')));
    await tester.pumpAndSettle();
    expect(find.text('授权连续包月'), findsNothing);
    expect(find.textContaining('首期付款'), findsNothing);
    expect(tester.takeException(), isNull);
    expectReadOnly();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
