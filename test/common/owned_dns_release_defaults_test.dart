import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/owned_dns.dart';

void main() {
  test('direct/native archives cannot omit the strict owned DNS binding', () {
    const client =
        bool.fromEnvironment('ZOLNIT_NATIVE_UI') ||
        bool.fromEnvironment('ZOLNIT_CLIENT_BUNDLE') ||
        String.fromEnvironment('ZOLNIT_DISTRIBUTION') == 'direct';
    if (client) {
      expect(ownedDnsBinding, isNotNull);
      expect(ownedDnsBinding!.resolver.strict, isTrue);
      expect(ownedDnsBinding!.resolver.owns('link.zolmid.com'), isTrue);
      expect(ownedDnsBinding!.resolver.owns('example.com'), isFalse);
      expect(ownedDnsBinding!.config.containsKey('authorization'), isFalse);
    } else {
      expect(ownedDnsBinding, isNull);
    }
  });
}
