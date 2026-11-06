import 'package:flutter/foundation.dart';

import 'api.dart';

enum ClientDistribution { direct, appleAppStore }

class ClientPaymentPolicy {
  const ClientPaymentPolicy({
    required this.platform,
    required this.isWeb,
    required this.distribution,
  });

  factory ClientPaymentPolicy.fromEnvironment() {
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
    );
  }

  final TargetPlatform platform;
  final bool isWeb;
  final ClientDistribution distribution;
  String get platformHeader => isWeb ? 'web' : platform.name.toLowerCase();
  String get distributionHeader =>
      distribution == ClientDistribution.direct ? 'direct' : 'apple-app-store';

  bool get allowStripe => distribution == ClientDistribution.direct;
  bool get allowAndroidSdk =>
      allowStripe && !isWeb && platform == TargetPlatform.android;

  String? nativeWalletForCapability(Json capability) {
    final wallets = capability['wallets'];
    if (!allowAndroidSdk ||
        capability['available'] != true ||
        capability['platform'] != 'android' ||
        wallets is! List) {
      return null;
    }
    return wallets.contains('payment_sheet') ? 'payment_sheet' : null;
  }

  bool supportsNativeCapability(Json capability, {bool recurring = false}) =>
      !recurring && nativeWalletForCapability(capability) != null;
  bool get allowAppleIap =>
      !isWeb &&
      {TargetPlatform.iOS, TargetPlatform.macOS}.contains(platform) &&
      distribution == ClientDistribution.appleAppStore;
}
