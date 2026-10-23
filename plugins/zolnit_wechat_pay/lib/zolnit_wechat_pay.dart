import 'package:flutter/services.dart';

class ZolnitWechatPay {
  static const _channel = MethodChannel('zolnit/stripe_wechat_pay');

  Future<bool> isBusy() async =>
      await _channel.invokeMethod<bool>('isBusy') ?? false;

  Future<void> confirm({
    required String publishableKey,
    required String clientSecret,
    required String appId,
  }) async {
    await _channel.invokeMethod<void>('confirm', {
      'publishableKey': publishableKey,
      'clientSecret': clientSecret,
      'appId': appId,
    });
  }
}
