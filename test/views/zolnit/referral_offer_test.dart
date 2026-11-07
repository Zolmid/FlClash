import 'dart:async';

import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  testWidgets('recurring promotion shows first and following frozen charges', (
    tester,
  ) async {
    harness.panel = (request) {
      if (request.url.path.endsWith('/zolnit-stripe/config')) {
        return zolnitJson({
          'enabled': true,
          'configured': true,
          'channels': [
            {'id': 1, 'name': 'Card', 'enabled': true, 'configured': true},
          ],
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
                    'available': true,
                    'period': 'monthly',
                    'months': 1,
                    'currency': 'CNY',
                    'charge_currency': 'SGD',
                    'price_cents': 2800,
                    'recurring_price_cents': 2520,
                    'handling_amount_cents': 0,
                    'recurring_total_cents': 2520,
                    'charge_amount_cents': 550,
                    'first_total_cents': 701,
                    'first_charge_amount_cents': 202,
                    'surplus_amount_cents': 0,
                    'surplus_credit_cents': 0,
                    'quote_id': 81,
                    'quote_expires_at':
                        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
                    'gift_replacement': false,
                    'switch_immediately': false,
                    'next_charge_at': null,
                    'referral_promotion': {
                      'campaign_name': 'Welcome offer',
                      'discount_percent': 20,
                    },
                  },
                ],
              },
          ],
        });
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('套餐').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('首期付款: ¥7.01'), findsOneWidget);
    expect(find.textContaining('后续付款: ¥25.20'), findsOneWidget);
    expect(find.text('Welcome offer'), findsOneWidget);
    expect(find.textContaining('Stripe'), findsNothing);
  });

  testWidgets('changing periods discards late first-order offers', (
    tester,
  ) async {
    final monthly = Completer<http.Response>();
    harness.panel = (request) {
      if (request.url.path.endsWith('/referral-offer')) {
        if (request.url.queryParameters['period'] == 'monthly') {
          return monthly.future;
        }
        return zolnitJson({'eligible': true, 'payable_amount': 1500});
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('套餐').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('年付'));
    await tester.pumpAndSettle();
    expect(find.textContaining('首单参考价: ¥15.00'), findsOneWidget);
    monthly.complete(zolnitJson({'eligible': true, 'payable_amount': 123}));
    await tester.pumpAndSettle();
    expect(find.textContaining('首单参考价: ¥15.00'), findsOneWidget);
    expect(find.textContaining('¥1.23'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
