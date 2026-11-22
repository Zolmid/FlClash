import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/owned_dns.dart';
import 'package:zolnit_client/src/owned_dns_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.zolmid.zolnit/service');
  final calls = <MethodCall>[];
  Object? lookupResult;
  setUp(() {
    calls.clear();
    lookupResult = ['192.0.2.1', '2001:db8::1'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'configureOwnedDnsSdkLoopback') return true;
          if (call.method == 'lookupOwnedDnsSdk') return lookupResult;
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<bool> configure(OwnedDnsSdkAdapter adapter, {String secret = ''}) =>
      adapter.configureLoopback(
        hosts: {'link.zolmid.com', 'node.nodes.zolmid.com'},
        port: 34567,
        keyId: 'a' * 64,
        secret: secret.isEmpty ? 'b' * 64 : secret,
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );

  test(
    'disabled release boundary and missing input send no credentials',
    () async {
      final disabled = OwnedDnsSdkAdapter(
        diagnosticEnabled: false,
        mobile: true,
      );
      expect(await configure(disabled), isFalse);
      expect(await disabled.lookup('link.zolmid.com'), isNull);
      final debug = OwnedDnsSdkAdapter(diagnosticEnabled: true, mobile: true);
      expect(await configure(debug, secret: 'invalid'), isFalse);
      expect(calls, isEmpty);
    },
  );

  test(
    'normal shared resolver uses scoped native SDK answers with zero TTL',
    () async {
      final adapter = OwnedDnsSdkAdapter(diagnosticEnabled: true, mobile: true);
      expect(await configure(adapter), isTrue);
      final binding = OwnedDnsBinding.fromJson({
        'hosts': ['link.zolmid.com', 'node.nodes.zolmid.com'],
        'relay': 'https://link.zolmid.com/api/v1/zolnit/client/httpdns',
        'strict': true,
      }, sdkLookup: adapter.lookup);
      expect(
        (await binding.resolver.resolve('node.nodes.zolmid.com')).first.address,
        '192.0.2.1',
      );
      await binding.resolver.resolve('node.nodes.zolmid.com');
      expect(
        calls.where((call) => call.method == 'lookupOwnedDnsSdk').length,
        2,
      );
      expect(await adapter.lookup('unassigned.nodes.zolmid.com'), isNull);
      expect(await adapter.lookup('example.com'), isNull);
      await adapter.disable();
      expect(await adapter.lookup('node.nodes.zolmid.com'), isNull);
      expect(binding.config.containsKey('accessKeySecret'), isFalse);
    },
  );

  test(
    'invalid or failed SDK answer goes to strict relay boundary, never local DNS',
    () async {
      final adapter = OwnedDnsSdkAdapter(diagnosticEnabled: true, mobile: true);
      await configure(adapter);
      final binding = OwnedDnsBinding.fromJson({
        'hosts': ['link.zolmid.com', 'node.nodes.zolmid.com'],
        'relay': 'https://link.zolmid.com/api/v1/zolnit/client/httpdns',
        'strict': true,
      }, sdkLookup: adapter.lookup);
      for (final value in [
        <String>[],
        ['example.com'],
        ['127.0.0.1'],
        ['192.0.2.1', 'invalid'],
      ]) {
        lookupResult = value;
        await expectLater(
          binding.resolver.resolve('node.nodes.zolmid.com'),
          throwsA(
            isA<SocketException>().having(
              (error) => error.message,
              'relay auth boundary',
              'Owned DNS unauthenticated',
            ),
          ),
        );
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'SDK_UNAVAILABLE'),
          );
      expect(await adapter.lookup('node.nodes.zolmid.com'), isNull);
    },
  );
}
