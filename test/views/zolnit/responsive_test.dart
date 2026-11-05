import 'dart:async';
import 'dart:ui' as ui;

import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/brand.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:fl_clash/views/zolnit/shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  testWidgets('a mobile platform shows the brand once at every width', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.android);
    for (final width in [390.0, 820.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(find.byType(ZolnitBrand), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.capture(tester, 'connect-width-${width.toInt()}');
    }
  });

  testWidgets('plan and cycle survive phone tablet and desktop resizing', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.android, size: const Size(390, 900));
    await tester.tap(find.text('套餐').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zolnit-plan-option-2')));
    await tester.tap(find.text('年付'));
    await tester.pumpAndSettle();
    for (final width in [320.0, 600.0, 820.0, 1024.0, 1440.0, 390.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      final selected = tester.widget<Semantics>(
        find.byKey(const ValueKey('zolnit-plan-state-2')),
      );
      expect(selected.properties.selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '年付'))
            .selected,
        isTrue,
      );
      if (width >= 1200) expect(find.byType(ZolnitSidebar), findsOneWidget);
      if (width >= 600 && width < 1200) {
        expect(find.byType(ZolnitNavRail), findsOneWidget);
      }
      expect(find.byTooltip('刷新'), findsNothing);
      expect(find.textContaining('Stripe'), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.capture(tester, 'plans-width-${width.toInt()}');
    }
  });

  testWidgets(
    'an occluding fold keeps controls on a usable pane and retains selection',
    (tester) async {
      await harness.mount(
        tester,
        ZolnitSkin.android,
        size: const Size(1200, 900),
      );
      await tester.tap(find.text('套餐').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zolnit-plan-option-2')));
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(590, 0, 20, 900),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.unknown,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('zolnit-plan-state-2')),
            )
            .properties
            .selected,
        isTrue,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('zolnit-plan-option-2')))
            .right,
        lessThanOrEqualTo(590),
      );
      expect(tester.takeException(), isNull);
      await harness.capture(tester, 'plans-fold-hinge');
      tester.view.resetDisplayFeatures();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('zolnit-plan-state-2')),
            )
            .properties
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'cancelled renewal retains entitlement and separates ended records',
    (tester) async {
      harness.panel = (request) {
        if (request.url.path.endsWith('/zolnit-stripe/config')) {
          return zolnitJson({
            'enabled': true,
            'configured': true,
            'channels': [
              {'id': 1, 'name': 'Stripe', 'enabled': true, 'configured': true},
            ],
          });
        }
        if (request.url.path.endsWith('/zolnit-stripe/subscriptions')) {
          return zolnitJson({
            'subscriptions': [
              {
                'id': 1,
                'plan_id': 1,
                'plan_name': '旧合同',
                'status': 'incomplete_expired',
              },
              {
                'id': 2,
                'plan_id': 1,
                'plan_name': '轻享',
                'status': 'active',
                'cancel_at_period_end': 1,
                'can_cancel': false,
                'can_resume': true,
                'paid_through': 1795219200,
              },
            ],
            'entitlement': {'source': 'paid'},
          });
        }
        if (request.url.path.endsWith('/zolnit-stripe/plans')) {
          return zolnitJson({
            'plans': [
              for (final id in [1, 2, 3])
                {
                  'id': id,
                  'periods': [
                    {
                      'period': 'monthly',
                      'available': false,
                      'unavailable_reason': 'active_subscription',
                    },
                  ],
                },
            ],
          });
        }
        return zolnitPanelFixture(request);
      };
      await harness.session.refreshBilling();
      await harness.mount(
        tester,
        ZolnitSkin.android,
        size: const Size(390, 900),
      );
      await tester.tap(find.text('套餐').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('自动续费已关闭'), findsOneWidget);
      expect(find.textContaining('请先在账号页'), findsNothing);
      expect(find.textContaining('Stripe'), findsNothing);
      await tester.tap(find.text('账号').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('自动续费已关闭'));
      expect(find.text('恢复自动续费'), findsOneWidget);
      expect(find.text('取消自动续费'), findsNothing);
      expect(find.text('旧合同'), findsNothing);
      await tester.ensureVisible(find.text('历史订阅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史订阅'));
      await tester.pumpAndSettle();
      expect(find.text('旧合同'), findsOneWidget);
      expect(
        harness.requests.where(
          (r) =>
              r.url.path.endsWith('/cancel') || r.url.path.endsWith('/resume'),
        ),
        isEmpty,
      );
      await harness.capture(tester, 'account-renewal-off');
    },
  );

  testWidgets(
    'data refresh is single flight retries and pauses in background',
    (tester) async {
      var now = DateTime.utc(2026, 11, 5);
      var syncs = 0;
      final first = Completer<int?>();
      harness.container.dispose();
      harness.container = ProviderContainer(
        overrides: [
          zolnitSessionProvider.overrideWithValue(harness.session),
          safeModeProvider.overrideWithValue(true),
          initProvider.overrideWithBuild((_, _) => true),
          zolnitBundleClockProvider.overrideWithValue(() => now),
          zolnitSyncProfileProvider.overrideWithValue(() {
            syncs++;
            return syncs == 1 ? first.future : Future.value(1);
          }),
        ],
      );
      globalState.container = harness.container;
      await harness.mount(tester, ZolnitSkin.android);
      expect(syncs, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(syncs, 1);
      first.completeError(const ClientFailure('network'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(syncs, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(syncs, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(syncs, 3);
      expect(find.byTooltip('刷新'), findsNothing);
      expect(
        harness.requests.where(
          (r) => r.method == 'POST' && !r.url.path.endsWith('/login'),
        ),
        isEmpty,
      );
    },
  );
}
