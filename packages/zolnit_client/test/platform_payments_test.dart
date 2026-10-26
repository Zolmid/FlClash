import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zolnit/stripe_wechat_pay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  StripeCheckout action({String? appId = 'wxdemo'}) => StripeCheckout(
    publishableKey: 'pk_test_demo',
    clientSecret: 'pi_demo_secret_demo',
    wallet: StripeWallet.wechatPay,
    returnUri: Uri.parse('zolnit://safepay'),
    wechatAppId: appId,
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
      wechatAppId: 'wxdemo',
    ).confirmStripe(action(), isCurrent: () => true);
    expect(methods, ['isBusy', 'confirm']);
  });

  test('WeChat uses the fixed client AppID when checkout omits it', () async {
    Object? confirmed;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'confirm') confirmed = call.arguments;
      return call.method == 'isBusy' ? false : null;
    });
    await NativeCheckoutPlatform(
      merchantName: 'ZolNit',
      wechatAppId: 'wxdemo',
    ).confirmStripe(action(appId: null), isCurrent: () => true);
    expect((confirmed as Map)['appId'], 'wxdemo');
  });

  for (final configuredId in ['', 'wxtrusted']) {
    test(
      'unconfigured or mismatched WeChat AppID never invokes the SDK ($configuredId)',
      () async {
        var calls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls++;
          return false;
        });
        await expectLater(
          NativeCheckoutPlatform(
            merchantName: 'ZolNit',
            wechatAppId: configuredId,
          ).confirmStripe(action(), isCurrent: () => true),
          throwsA(
            isA<ClientFailure>().having(
              (e) => e.code,
              'code',
              'sdk_unavailable',
            ),
          ),
        );
        expect(calls, 0);
      },
    );
  }

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
        wechatAppId: 'wxdemo',
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
      wechatAppId: 'wxdemo',
    ).confirmStripe(action(), isCurrent: () => true);
    await queried.future;
    await expectLater(
      NativeCheckoutPlatform(
        merchantName: 'ZolNit',
        wechatAppId: 'wxdemo',
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

  test(
    'compiled macOS distribution binds billing policy and API headers',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = String.fromEnvironment('ZOLNIT_DISTRIBUTION');
      final website = channel == 'direct';
      final policy = ClientPaymentPolicy.fromEnvironment();
      expect(policy.platformHeader, 'macos');
      expect(policy.allowStripe, website);
      expect(policy.allowAppleIap, !website);
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        clientPlatform: policy.platformHeader,
        distribution: policy.distributionHeader,
        client: MockClient((request) async {
          expect(
            request.headers['X-ZolNit-Distribution'],
            website ? 'direct' : 'apple-app-store',
          );
          return http.Response('{"data":{}}', 200);
        }),
      );
      addTearDown(api.close);
      await api.request('/api/v1/guest/comm/config', authenticated: false);
    },
  );

  test(
    'all supported platform policies construct an API client with canonical headers',
    () async {
      for (final (platform, header) in [
        (TargetPlatform.android, 'android'),
        (TargetPlatform.iOS, 'ios'),
        (TargetPlatform.macOS, 'macos'),
        (TargetPlatform.windows, 'windows'),
        (TargetPlatform.linux, 'linux'),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final policy = ClientPaymentPolicy.fromEnvironment();
        expect(policy.platformHeader, header);
        final api = XboardClient(
          origin: Uri.parse('https://panel.example'),
          clientPlatform: policy.platformHeader,
          distribution: policy.distributionHeader,
          client: MockClient((request) async {
            expect(request.headers['X-ZolNit-Platform'], header);
            expect(
              request.headers['X-ZolNit-Distribution'],
              policy.distributionHeader,
            );
            return http.Response('{"data":{}}', 200);
          }),
        );
        await api.request('/api/v1/guest/comm/config', authenticated: false);
        api.close();
      }
      const web = ClientPaymentPolicy(
        platform: TargetPlatform.macOS,
        isWeb: true,
        distribution: ClientDistribution.direct,
      );
      expect(web.platformHeader, 'web');
    },
  );

  test(
    'Android eligibility needs server capability rather than a build flag',
    () {
      const blocked = ClientPaymentPolicy(
        platform: TargetPlatform.android,
        isWeb: false,
        distribution: ClientDistribution.direct,
      );
      expect(blocked.allowStripe, isTrue);
      expect(blocked.allowAndroidSdk, isTrue);

      const enabled = ClientPaymentPolicy(
        platform: TargetPlatform.android,
        isWeb: false,
        distribution: ClientDistribution.direct,
        androidNativeStripe: true,
      );
      expect(enabled.allowStripe, isTrue);
      expect(enabled.allowAndroidSdk, isTrue);
      const capability = <String, dynamic>{
        'available': true,
        'platform': 'android',
        'payment_method': 'wechat_pay',
        'recurring': false,
      };
      expect(blocked.supportsNativeCapability(capability), isTrue);
      expect(
        enabled.supportsNativeCapability({...capability, 'available': false}),
        isFalse,
      );
      expect(
        enabled.supportsNativeCapability({...capability, 'available': 'true'}),
        isFalse,
      );
      expect(
        enabled.supportsNativeCapability({
          ...capability,
          'payment_method': 'card',
        }),
        isFalse,
      );
      expect(
        enabled.supportsNativeCapability({
          ...capability,
          'payment_method': 'alipay',
        }),
        isFalse,
      );
      expect(
        enabled.supportsNativeCapability(capability, recurring: true),
        isFalse,
      );
      expect(enabled.supportsNativeCapability({}), isFalse);
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
      ]) {
        final policy = ClientPaymentPolicy(
          platform: platform,
          isWeb: false,
          distribution: ClientDistribution.appleAppStore,
          androidNativeStripe: true,
        );
        expect(policy.allowStripe, isFalse);
        expect(policy.supportsNativeCapability(capability), isFalse);
      }
    },
  );
}
