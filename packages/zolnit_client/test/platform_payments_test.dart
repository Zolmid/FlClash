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

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('WeChat cannot invoke the native bridge on $target', () async {
      debugDefaultTargetPlatformOverride = target;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return false;
      });
      await expectLater(
        NativeCheckoutPlatform(
          merchantName: 'ZolNit',
          wechatAppId: 'wxdemo',
        ).confirmStripe(action(), isCurrent: () => true),
        throwsA(
          isA<ClientFailure>().having(
            (error) => error.code,
            'code',
            'wallet_unavailable',
          ),
        ),
      );
      expect(calls, 0);
    });
  }

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
      const website = channel == 'direct';
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

  test('Android native selection needs a matching server capability', () {
    const blocked = ClientPaymentPolicy(
      platform: TargetPlatform.android,
      isWeb: false,
      distribution: ClientDistribution.direct,
    );
    expect(blocked.allowStripe, isTrue);
    expect(blocked.allowAndroidSdk, isTrue);

    const capability = <String, dynamic>{
      'available': true,
      'platform': 'android',
      'wallets': ['payment_sheet', 'wechat_pay'],
    };
    expect(blocked.supportsNativeCapability(capability), isTrue);
    expect(blocked.nativeWalletForCapability(capability), 'payment_sheet');
    expect(
      blocked.supportsNativeCapability({...capability, 'available': false}),
      isFalse,
    );
    expect(
      blocked.supportsNativeCapability({...capability, 'available': 'true'}),
      isFalse,
    );
    expect(
      blocked.supportsNativeCapability({
        ...capability,
        'wallets': ['wechat_pay'],
      }),
      isFalse,
    );
    expect(
      blocked.supportsNativeCapability({
        ...capability,
        'wallets': 'payment_sheet',
      }),
      isFalse,
    );
    expect(
      blocked.supportsNativeCapability(capability, recurring: true),
      isFalse,
    );
    expect(blocked.supportsNativeCapability({}), isFalse);
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      final policy = ClientPaymentPolicy(
        platform: platform,
        isWeb: false,
        distribution: ClientDistribution.appleAppStore,
      );
      expect(policy.allowStripe, isFalse);
      expect(policy.supportsNativeCapability(capability), isFalse);
    }
  });
}
