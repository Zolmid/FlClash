import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  for (final value in [true, 1, '1']) {
    test('active contract with cancellation flag $value is renewal off', () {
      final renewal = ZolnitRenewal({
        'status': 'active',
        'cancel_at_period_end': value,
        'paid_through': 1795219200,
        'can_cancel': false,
        'can_resume': true,
      });
      expect(renewal.state, RenewalState.disabled);
      expect(renewal.canResume, isTrue);
      expect(renewal.canCancel, isFalse);
      expect(renewal.data['paid_through'], 1795219200);
    });
  }
  test('terminal, pending and uncertain contracts remain distinct', () {
    expect(
      const ZolnitRenewal({'status': 'canceled'}).state,
      RenewalState.ended,
    );
    expect(
      const ZolnitRenewal({'status': 'incomplete_expired'}).state,
      RenewalState.ended,
    );
    expect(
      const ZolnitRenewal({
        'status': 'checkout',
        'initial_order_pending': 1,
      }).state,
      RenewalState.pending,
    );
    expect(
      const ZolnitRenewal({
        'status': 'active',
        'cancel_at_period_end': 0,
      }).state,
      RenewalState.enabled,
    );
    expect(
      const ZolnitRenewal({'status': 'unknown'}).state,
      RenewalState.attention,
    );
    expect(
      const ZolnitRenewal({'status': 'active', 'risk_hold': 1}).state,
      RenewalState.attention,
    );
  });
}
