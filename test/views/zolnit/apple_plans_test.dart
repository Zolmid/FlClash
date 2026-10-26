import 'dart:convert';

import 'package:fl_clash/providers/zolnit_apple.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../packages/zolnit_client/test/apple_test.dart' show Store;
import 'harness.dart';

void main() {
  late Store store;
  final harness = ZolnitHarness.register(
    clientPlatform: 'ios',
    distribution: 'apple-app-store',
    overrides: [zolnitAppleStoreProvider.overrideWith((ref) => store)],
  );
  setUp(() {
    store = Store();
  });
  tearDown(() async {
    await store.close();
  });

  void endpoint({bool ready = true}) {
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-apple/config')) {
        return http.Response(
          jsonEncode({
            'data': {
              'enabled': ready,
              'configured': ready,
              'account_id': 'accountA',
              'environment': 'Sandbox',
              'products': ready
                  ? {
                      'monthly': {
                        'plan_id': 1,
                        'period': 'monthly',
                        'type': 'Auto-Renewable Subscription',
                      },
                    }
                  : <String, Object>{},
              'prepare_path': '/api/v1/zolnit-apple/prepare',
              'verify_path': '/api/v1/zolnit-apple/verify',
              'management_url': 'https://apps.apple.com/account/subscriptions',
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/zolnit-apple/prepare')) {
        return http.Response(
          jsonEncode({
            'data': {
              'account_id': 'accountA',
              'product_id': 'monthly',
              'app_account_token': '11111111-2222-4333-8444-555555555555',
              'entitlement_effect': 'replace_gift_after_verified_payment',
              'gift': {'source': 'gift', 'expires_at': 2_000_000_000},
            },
          }),
          200,
        );
      }
      return zolnitPanelFixture(request);
    };
  }

  Future<void> open(WidgetTester tester) async {
    await harness.mount(
      tester,
      ZolnitSkin.ios,
      locale: const Locale('en'),
      includeNavigatorKey: true,
    );
    await tester.tap(find.text('Plans').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'App Store page uses native product price and never creates ordinary orders',
    (tester) async {
      endpoint();
      await open(tester);
      expect(find.textContaining('US\$4.99'), findsOneWidget);
      expect(find.text('Subscribe with App Store'), findsOneWidget);
      expect(find.textContaining('28.00'), findsNothing);
      expect(
        harness.requests.where((r) => r.url.path.endsWith('/order/save')),
        isEmpty,
      );
      expect(
        harness.requests.where((r) => r.url.path.contains('/zolnit-stripe/')),
        isEmpty,
      );
      expect(store.buys, 0);
    },
  );

  testWidgets(
    'gift replacement consent is shown before native purchase and can be declined',
    (tester) async {
      endpoint();
      await open(tester);
      await tester.tap(find.text('Subscribe with App Store'));
      await tester.pumpAndSettle();
      expect(find.textContaining('remaining gifted time'), findsOneWidget);
      expect(find.textContaining('US\$4.99'), findsNWidgets(2));
      expect(store.buys, 0);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(store.buys, 0);
      expect(store.finishes, 0);
      expect(
        harness.requests.where((r) => r.url.path.endsWith('/order/save')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'unconfigured Apple billing has no native or ordinary purchase entry',
    (tester) async {
      endpoint(ready: false);
      await open(tester);
      expect(find.text('Subscribe with App Store'), findsNothing);
      expect(store.queries, 0);
      expect(store.buys, 0);
      expect(
        harness.requests.where(
          (r) => r.method == 'POST' && !r.url.path.endsWith('/login'),
        ),
        isEmpty,
      );
    },
  );
}
