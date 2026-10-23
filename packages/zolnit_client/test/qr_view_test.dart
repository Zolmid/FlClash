import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  testWidgets(
    'QR expires without navigation and never displays its secret as text',
    (tester) async {
      var now = DateTime.utc(2026, 10, 20);
      final qr = PaymentQr(
        payload: 'weixin://wxpay/private-payload',
        expiresAt: now.add(const Duration(seconds: 2)),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PaymentQrView(
            qr: qr,
            instruction: 'Scan in wallet',
            expiredLabel: 'Expired',
            now: () => now,
          ),
        ),
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(qr.payload), findsNothing);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Expired'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );
}
