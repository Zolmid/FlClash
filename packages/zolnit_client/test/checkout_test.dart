import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

class Backend implements CheckoutBackend {
  int starts = 0;
  int checks = 0;
  int currentStatus = 0;
  CheckoutAction action = HostedCheckout(
    Uri.parse('https://checkout.stripe.com/pay'),
  );
  Completer<CheckoutAction>? deferred;
  Completer<int>? deferredStatus;

  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async {
    starts++;
    return deferred == null ? action : deferred!.future;
  }

  @override
  Future<int> status(String tradeNo) async {
    checks++;
    return deferredStatus == null ? currentStatus : deferredStatus!.future;
  }
}

class Platform implements CheckoutPlatform {
  int opens = 0;
  int confirmations = 0;
  bool launchable = true;
  String? sdkFailure;

  @override
  Future<bool> open(Uri uri) async {
    opens++;
    return launchable;
  }

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async {
    confirmations++;
    if (sdkFailure != null) throw ClientFailure(sdkFailure!);
  }
}

void main() {
  late Backend backend;
  late Platform platform;
  late CheckoutController controller;
  final now = DateTime.utc(2026, 10, 20);
  PaymentQr validQr() => PaymentQr(
    payload: 'weixin://wxpay/demo',
    expiresAt: now.add(const Duration(minutes: 10)),
  );

  setUp(() {
    backend = Backend();
    platform = Platform();
    controller = CheckoutController(
      backend: backend,
      platform: platform,
      allowStripe: true,
      allowedHttpsOrigins: {'https://checkout.stripe.com'},
      now: () => now,
    );
  });
  tearDown(() => controller.dispose());

  test('opening the provider does not mark an order paid', () async {
    await controller.start('orderA', 2);
    expect(platform.opens, 1);
    expect(controller.stage, CheckoutStage.awaitingPayment);
    backend.currentStatus = 3;
    await controller.refresh();
    expect(controller.stage, CheckoutStage.completed);
  });

  test('double click and reentrant listeners start one checkout', () async {
    final followups = <Future<void>>[];
    controller.addListener(() {
      if (controller.stage == CheckoutStage.launching) {
        followups.add(controller.start('orderA', 2));
      }
    });
    await Future.wait([
      controller.start('orderA', 2),
      controller.start('orderA', 2),
    ]);
    await Future.wait(followups);
    expect(backend.starts, 1);
    expect(platform.opens, 1);
  });

  test('an in-flight different order is not silently joined', () async {
    backend.deferred = Completer();
    final first = controller.start('orderA', 2);
    await expectLater(
      controller.start('orderB', 2),
      throwsA(isA<ClientFailure>()),
    );
    backend.deferred!.complete(backend.action);
    await first;
    expect(controller.tradeNo, 'orderA');
  });

  test(
    'logout during checkout prevents opening an old account action',
    () async {
      backend.deferred = Completer();
      final first = controller.start('orderA', 2);
      await Future<void>.delayed(Duration.zero);
      controller.reset();
      backend.deferred!.complete(backend.action);
      await first;
      expect(platform.opens, 0);
      expect(controller.stage, CheckoutStage.idle);
    },
  );

  test('old status response cannot complete a new checkout', () async {
    await controller.start('orderA', 2);
    backend.deferredStatus = Completer();
    final refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.reset();
    backend.deferredStatus!.complete(3);
    await refresh;
    expect(controller.stage, CheckoutStage.idle);
  });

  test('foreign or credential-bearing checkout URLs never launch', () async {
    for (final url in [
      'http://checkout.stripe.com/pay',
      'https://evil.example/pay',
      'https://user:secret@checkout.stripe.com/pay',
    ]) {
      backend.action = HostedCheckout(Uri.parse(url));
      await controller.start('orderA', 2);
      expect(controller.stage, CheckoutStage.failed);
      expect(platform.opens, 0);
    }
  });

  test(
    'unavailable wallet falls back to the supplied QR for the same order',
    () async {
      final action = StripeCheckout(
        publishableKey: 'pk_test_demo',
        clientSecret: 'pi_demo_secret_demo',
        wallet: StripeWallet.wechatPay,
        returnUri: Uri.parse('zolnit://safepay'),
        wechatAppId: 'wxdemo',
        fallbackQr: validQr(),
      );
      backend.action = action;
      platform.sdkFailure = 'wallet_unavailable';
      await controller.start('orderA', 2);
      expect(controller.stage, CheckoutStage.qr);
      expect(controller.qr, same(action.fallbackQr));
      expect(backend.starts, 1);
      expect(controller.tradeNo, 'orderA');
      expect(action.toString(), isNot(contains('pi_demo')));
      expect(controller.qr.toString(), isNot(contains('weixin:')));
    },
  );

  test('expired QR never appears or starts a new payment', () async {
    backend.action = QrCheckout(PaymentQr(payload: 'expired', expiresAt: now));
    await controller.start('orderA', 2);
    expect(controller.stage, CheckoutStage.failed);
    expect(controller.failure, 'qr_expired');
    expect(platform.opens, 0);
    expect(backend.starts, 1);
  });

  test('processing, cancelled and credited are not completed', () async {
    await controller.start('orderA', 2);
    for (final entry in {
      1: CheckoutStage.processing,
      2: CheckoutStage.cancelled,
      4: CheckoutStage.cancelled,
    }.entries) {
      backend.currentStatus = entry.key;
      await controller.refresh();
      expect(controller.stage, entry.value);
    }
  });

  test('App Store policy blocks Stripe before backend side effects', () async {
    final apple = CheckoutController(
      backend: backend,
      platform: platform,
      allowStripe: false,
      allowedHttpsOrigins: const {},
    );
    await expectLater(apple.start('orderA', 2), throwsA(isA<ClientFailure>()));
    expect(backend.starts, 0);
    apple.dispose();
  });

  test(
    'reset before the scheduled checkout prevents backend side effects',
    () async {
      final first = controller.start('orderA', 2);
      controller.reset();
      await first;
      expect(backend.starts, 0);
      expect(platform.opens, 0);
      expect(controller.stage, CheckoutStage.idle);
    },
  );

  test('poll is bounded and stops after an authoritative completion', () async {
    await controller.start('orderA', 2);
    await controller.poll(interval: Duration.zero, attempts: 2);
    expect(backend.checks, 3);
    backend.currentStatus = 3;
    await controller.poll(interval: Duration.zero, attempts: 5);
    expect(backend.checks, 4);
    expect(controller.stage, CheckoutStage.completed);
  });
}
