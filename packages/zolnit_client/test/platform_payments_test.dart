import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zolnit/stripe_wechat_pay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  StripeCheckout action() => StripeCheckout(
    publishableKey: 'pk_test_demo',
    clientSecret: 'pi_demo_secret_demo',
    wallet: StripeWallet.wechatPay,
    returnUri: Uri.parse('zolnit://safepay'),
    wechatAppId: 'wxdemo',
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android WeChat uses the dedicated native SDK bridge', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'isBusy' ? false : null;
    });
    await NativeCheckoutPlatform(
      merchantName: 'ZolNit',
    ).confirmStripe(action(), isCurrent: () => true);
    expect(methods, ['isBusy', 'confirm']);
  });

  test(
    'account invalidation during SDK preparation prevents native confirmation',
    () async {
      final ready = Completer<bool>();
      final queried = Completer<void>();
      var current = true;
      var confirmations = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isBusy') {
          queried.complete();
          return ready.future;
        }
        confirmations++;
        return null;
      });
      final operation = NativeCheckoutPlatform(
        merchantName: 'ZolNit',
      ).confirmStripe(action(), isCurrent: () => current);
      final assertion = expectLater(operation, throwsA(isA<ClientFailure>()));
      await queried.future;
      current = false;
      ready.complete(false);
      await assertion;
      expect(confirmations, 0);
    },
  );

  test('SDK gate spans separate platform instances', () async {
    final ready = Completer<bool>();
    final queried = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isBusy') {
        queried.complete();
        return ready.future;
      }
      return null;
    });
    final first = NativeCheckoutPlatform(
      merchantName: 'ZolNit',
    ).confirmStripe(action(), isCurrent: () => true);
    await queried.future;
    await expectLater(
      NativeCheckoutPlatform(
        merchantName: 'ZolNit',
      ).confirmStripe(action(), isCurrent: () => true),
      throwsA(
        isA<ClientFailure>().having(
          (e) => e.code,
          'code',
          'purchase_in_progress',
        ),
      ),
    );
    ready.complete(false);
    await first;
  });

  test('store policy separates Apple IAP from direct-distribution Stripe', () {
    const apple = ClientPaymentPolicy(
      platform: TargetPlatform.iOS,
      isWeb: false,
      distribution: ClientDistribution.appleAppStore,
    );
    const macDirect = ClientPaymentPolicy(
      platform: TargetPlatform.macOS,
      isWeb: false,
      distribution: ClientDistribution.direct,
    );
    expect(apple.allowStripe, isFalse);
    expect(apple.allowAppleIap, isTrue);
    expect(macDirect.allowStripe, isTrue);
    expect(macDirect.allowAppleIap, isFalse);
  });
}
