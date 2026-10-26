import 'package:flutter/foundation.dart';

import 'api.dart';

enum ClientDistribution { direct, appleAppStore }

class ClientPaymentPolicy {
  const ClientPaymentPolicy({
    required this.platform,
    required this.isWeb,
    required this.distribution,
    this.androidNativeStripe = false,
  });

  factory ClientPaymentPolicy.fromEnvironment({
    bool androidNativeStripe = const bool.fromEnvironment(
      'ZOLNIT_ANDROID_NATIVE_STRIPE',
    ),
  }) {
    const channel = String.fromEnvironment('ZOLNIT_DISTRIBUTION');
    final apple =
        {
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform) &&
        !kIsWeb;
    final distribution = switch (channel) {
      '' =>
        apple ? ClientDistribution.appleAppStore : ClientDistribution.direct,
      'direct' => ClientDistribution.direct,
      'apple-app-store' => ClientDistribution.appleAppStore,
      _ => throw const ClientFailure('invalid_distribution'),
    };
    return ClientPaymentPolicy(
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
      distribution: distribution,
      androidNativeStripe: androidNativeStripe,
    );
  }

  final TargetPlatform platform;
  final bool isWeb;
  final ClientDistribution distribution;
  final bool androidNativeStripe;

  String get platformHeader => isWeb ? 'web' : platform.name.toLowerCase();
  String get distributionHeader =>
      distribution == ClientDistribution.direct ? 'direct' : 'apple-app-store';

  bool get allowStripe => distribution == ClientDistribution.direct;
  bool get allowAndroidSdk =>
      allowStripe && !isWeb && platform == TargetPlatform.android;

  bool supportsNativeCapability(Json capability, {bool recurring = false}) =>
      allowAndroidSdk &&
      !recurring &&
      capability['available'] == true &&
      capability['platform'] == 'android' &&
      capability['payment_method'] == 'wechat_pay' &&
      capability['recurring'] == false;
  bool get allowAppleIap =>
      !isWeb &&
      {TargetPlatform.iOS, TargetPlatform.macOS}.contains(platform) &&
      distribution == ClientDistribution.appleAppStore;
}
