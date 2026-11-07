import 'dart:convert';
import 'dart:async';

import 'package:fl_clash/views/zolnit/rewards.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

http.Response rewardFixture(http.Request request) =>
    request.url.path.endsWith('/user/info')
    ? zolnitJson({
        'email': 'lin@example.com',
        'balance': 0,
        'uuid': 'fixture-account',
      })
    : zolnitPanelFixture(request);

void main() {
  final harness = ZolnitHarness.register();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reopening a page recovers the same pending redemption', (
    tester,
  ) async {
    final requestIds = <String?>[];
    harness.panel = (request) {
      if (request.url.path.endsWith('/gift-card/check')) {
        return requestIds.isEmpty
            ? zolnitJson({
                'template': {'name': 'Gift', 'type': 1},
                'can_redeem': true,
                'rewards': {'balance': 100},
              })
            : http.Response('{"message":"already used"}', 400);
      }
      if (request.url.path.endsWith('/gift-card/redeem')) {
        requestIds.add(request.headers['idempotency-key']);
        return requestIds.length == 1
            ? http.Response('{}', 500)
            : zolnitJson({
                'rewards': {'balance': 100},
              });
      }
      if (request.url.path.endsWith('/gift-card/history')) {
        return zolnitJson({'records': [], 'current_page': 1, 'last_page': 1});
      }
      return rewardFixture(request);
    };
    await harness.relogin();
    Future<void> open() => harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitRewardsPage(
        session: harness.session,
        onRedeemed: () async {},
      ),
    );
    await open();
    await tester.enterText(find.byType(TextField), 'CARD123');
    await tester.tap(find.text('查看礼品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认兑换'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await open();
    await tester.enterText(find.byType(TextField), 'card123');
    await tester.tap(find.text('查看礼品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(requestIds, hasLength(2));
    expect(requestIds.first, requestIds.last);
    expect(find.text('兑换成功'), findsOneWidget);
  });

  testWidgets('late card preview cannot cross logout', (tester) async {
    final response = Completer<http.Response>();
    harness.panel = (request) {
      if (request.url.path.endsWith('/gift-card/check')) return response.future;
      if (request.url.path.endsWith('/gift-card/history')) {
        return zolnitJson({'records': [], 'current_page': 1, 'last_page': 1});
      }
      return rewardFixture(request);
    };
    await harness.relogin();
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitRewardsPage(
        session: harness.session,
        onRedeemed: () async {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'CARD123');
    await tester.tap(find.text('查看礼品'));
    await tester.pump();
    await harness.session.logout();
    response.complete(
      zolnitJson({
        'template': {'name': 'Old account', 'type': 1},
        'can_redeem': true,
        'rewards': {'balance': 1},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old account'), findsNothing);
    expect(find.text('确认兑换'), findsNothing);
  });

  testWidgets('history switches pages with server timestamps', (tester) async {
    harness.panel = (request) {
      if (request.url.path.endsWith('/gift-card/history')) {
        final page = int.parse(request.url.queryParameters['page']!);
        return zolnitJson({
          'records': [
            {
              'id': page,
              'template_name': 'Gift $page',
              'rewards': {'balance': 100},
              'created_at': 1794000000,
            },
          ],
          'current_page': page,
          'last_page': 2,
        });
      }
      return rewardFixture(request);
    };
    await harness.relogin();
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitRewardsPage(
        session: harness.session,
        onRedeemed: () async {},
      ),
    );
    expect(find.text('Gift 1'), findsOneWidget);
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('Gift 2'), findsOneWidget);
    expect(find.text('Gift 1'), findsNothing);
  });

  testWidgets('refresh retry does not redeem a second time', (tester) async {
    var redemptions = 0;
    var refreshes = 0;
    harness.panel = (request) {
      if (request.url.path.endsWith('/gift-card/check')) {
        return zolnitJson({
          'template': {'name': 'Gift', 'type': 1},
          'can_redeem': true,
          'rewards': {'balance': 100},
        });
      }
      if (request.url.path.endsWith('/gift-card/redeem')) {
        redemptions++;
        return zolnitJson({
          'rewards': {'balance': 100},
        });
      }
      if (request.url.path.endsWith('/gift-card/history')) {
        return zolnitJson({'records': [], 'current_page': 1, 'last_page': 1});
      }
      return rewardFixture(request);
    };
    await harness.relogin();
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitRewardsPage(
        session: harness.session,
        onRedeemed: () async {
          if (++refreshes == 1) throw StateError('offline');
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'CARD123');
    await tester.tap(find.text('查看礼品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认兑换'));
    await tester.pumpAndSettle();
    expect(find.text('账号刷新失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(refreshes, 2);
    expect(redemptions, 1);
  });

  testWidgets(
    'account hides missing feature and opens and returns when available',
    (tester) async {
      var available = false;
      harness.panel = (request) {
        if (request.url.path.endsWith('/zolnit-rewards/config') && available) {
          return zolnitJson({'enabled': true, 'gift_card_enabled': true});
        }
        if (request.url.path.endsWith('/gift-card/history')) {
          return zolnitJson({'records': [], 'current_page': 1, 'last_page': 1});
        }
        return rewardFixture(request);
      };
      await harness.relogin();
      await harness.mount(tester, ZolnitSkin.macos);
      await tester.tap(find.text('账号').first);
      await tester.pumpAndSettle();
      expect(find.text('礼品卡'), findsNothing);
      available = true;
      await harness.relogin();
      await tester.pumpAndSettle();
      await tester.tap(find.text('账号').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('礼品卡'));
      await tester.tap(find.text('礼品卡'));
      await tester.pumpAndSettle();
      expect(find.text('兑换记录'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('账号信息'), findsOneWidget);
    },
  );

  for (final (size, dark) in [
    (const Size(390, 800), false),
    (const Size(390, 800), true),
    (const Size(1440, 900), false),
    (const Size(1440, 900), true),
  ]) {
    testWidgets('gift redemption ${size.width} dark=$dark', (tester) async {
      var calls = 0;
      var refreshes = 0;
      harness.panel = (request) {
        if (request.url.path.endsWith('/gift-card/check')) {
          return zolnitJson({
            'template': {'name': 'Mystery', 'type': 3},
            'can_redeem': true,
            'possible_rewards': [
              {'weight': 1, 'balance': 100},
              {'weight': 2, 'expire_days': 3},
            ],
            'rewards': <String, dynamic>{},
          });
        }
        if (request.url.path.endsWith('/gift-card/redeem')) {
          calls++;
          expect(request.headers['idempotency-key'], isNotEmpty);
          expect(jsonDecode(request.body), {'code': 'TESTCARD'});
          return zolnitJson({
            'template_name': 'Mystery',
            'rewards': {
              'balance': 250,
              'plan': {
                'id': 5,
                'name': 'Gift plan',
                'validity_days': 30,
                'non_expiring': false,
              },
            },
          });
        }
        if (request.url.path.endsWith('/gift-card/history')) {
          return zolnitJson({'records': [], 'current_page': 1, 'last_page': 1});
        }
        return rewardFixture(request);
      };
      await harness.relogin();
      await harness.mount(
        tester,
        ZolnitSkin.android,
        size: size,
        dark: dark,
        child: ZolnitRewardsPage(
          session: harness.session,
          onRedeemed: () async {
            refreshes++;
          },
        ),
      );
      if (size.width == 390) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
      }
      await tester.enterText(find.byType(TextField), 'TESTCARD');
      await tester.tap(find.text('查看礼品'));
      await tester.pumpAndSettle();
      expect(find.text('可能获得'), findsOneWidget);
      expect(find.textContaining('¥1.00'), findsOneWidget);
      expect(find.textContaining('3 天'), findsOneWidget);
      await tester.ensureVisible(find.text('确认兑换'));
      await tester.tap(find.text('确认兑换'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(refreshes, 1);
      expect(find.text('实际获得'), findsOneWidget);
      expect(find.textContaining('¥2.50'), findsOneWidget);
      expect(find.textContaining('Gift plan'), findsOneWidget);
      expect(find.textContaining('30 天'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
