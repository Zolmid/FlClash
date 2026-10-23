import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_wechat_pay/zolnit_wechat_pay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zolnit/stripe_wechat_pay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'forwards native SDK parameters through the dedicated channel',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'confirm');
        expect(call.arguments, {
          'publishableKey': 'pk_test_demo',
          'clientSecret': 'pi_demo_secret_demo',
          'appId': 'wxdemo',
        });
        return null;
      });
      await ZolnitWechatPay().confirm(
        publishableKey: 'pk_test_demo',
        clientSecret: 'pi_demo_secret_demo',
        appId: 'wxdemo',
      );
    },
  );

  test('preserves an unavailable wallet result for QR fallback', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'wallet_unavailable'),
    );
    await expectLater(
      ZolnitWechatPay().confirm(
        publishableKey: 'pk_test_demo',
        clientSecret: 'pi_demo_secret_demo',
        appId: 'wxdemo',
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'wallet_unavailable',
        ),
      ),
    );
  });

  test(
    'reports native in-flight ownership without launching another payment',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isBusy');
        return true;
      });
      expect(await ZolnitWechatPay().isBusy(), isTrue);
    },
  );
}
