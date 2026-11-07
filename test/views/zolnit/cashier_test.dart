import 'package:fl_clash/views/zolnit/catalogue.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  testWidgets('awaiting payment keeps retry and cancellation available', (
    tester,
  ) async {
    harness.panel = (request) {
      if (request.url.path.endsWith('/order/fetch')) {
        return zolnitJson([
          {'trade_no': 'orderA', 'status': 0, 'total_amount': 1200},
        ]);
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await harness.session.refreshBilling();
    await harness.session.checkout.start('orderA', 1);
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: ZolnitCashierPage(
        session: harness.session,
        tradeNo: 'orderA',
        onClose: () {},
      ),
    );

    expect(harness.session.checkout.stage, CheckoutStage.awaitingPayment);
    final action = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(action.onPressed, isNotNull);
    expect(find.text('取消订单'), findsOneWidget);
    expect(find.text('前往付款'), findsOneWidget);
  });

  for (final status in [2, 3, 4]) {
    testWidgets('terminal order $status removes payment controls', (
      tester,
    ) async {
      harness.panel = (request) {
        if (request.url.path.endsWith('/order/fetch')) {
          return zolnitJson([
            {
              'trade_no': 'terminal-$status',
              'status': status,
              'total_amount': 1200,
            },
          ]);
        }
        return zolnitPanelFixture(request);
      };
      await harness.relogin();
      await harness.session.refreshBilling();
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: ZolnitCashierPage(
          session: harness.session,
          tradeNo: 'terminal-$status',
          onClose: () {},
        ),
      );

      expect(find.text('付款返回后仍需确认订单状态。'), findsNothing);
      expect(find.text('刷新'), findsNothing);
      expect(find.text('前往付款'), findsNothing);
      expect(find.text('取消订单'), findsNothing);
      expect(
        tester.widgetList<FilledButton>(find.byType(FilledButton)),
        hasLength(1),
      );
    });
  }
}
