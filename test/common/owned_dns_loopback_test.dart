import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/owned_dns.dart';
import 'package:zolnit_client/src/owned_dns_loopback.dart';
import 'package:zolnit_client/src/owned_dns_sdk.dart';

class _Sdk extends OwnedDnsSdkAdapter {
  _Sdk() : super(mobile: true);
  late int port;
  late String key, secret;
  bool poisoned = false;
  int? timestampOverride;
  Future<OwnedDnsAnswer?> Function(String)? customLookup;
  final grants = <String>[];
  final replies = <int>[];
  @override
  Future<bool> configureLoopback({
    required Set<String> hosts,
    required int port,
    required String keyId,
    required String secret,
    required DateTime expiresAt,
  }) async {
    this.port = port;
    key = keyId;
    this.secret = secret;
    grants.add(keyId);
    return true;
  }

  Future<({int status, Map<String, dynamic>? body})> request(
    String host,
    int type, {
    bool valid = true,
  }) async {
    final timestamp =
        timestampOverride ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = sha256
        .convert(utf8.encode('1$secret$timestamp$host$key'))
        .toString();
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      final req = await client.getUrl(
        Uri.http('127.0.0.1:$port', '/resolve', {
          'name': host,
          'type': '$type',
          'uid': '1',
          'ts': '$timestamp',
          'ak': key,
          'key': valid ? signature : 'invalid',
        }),
      );
      final response = await req.close();
      final text = await response.transform(utf8.decoder).join();
      replies.add(response.statusCode);
      return (
        status: response.statusCode,
        body: text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<OwnedDnsAnswer?> lookup(String host) async {
    if (customLookup != null) return customLookup!(host);
    if (poisoned) return OwnedDnsAnswer(['192.0.2.99'], 0);
    expect((await request(host, 1, valid: false)).status, 403);
    expect((await request('example.com', 1)).status, 403);
    final a = await request(host, 1), aaaa = await request(host, 28);
    return OwnedDnsAnswer([
      for (final response in [a, aaaa])
        for (final rr in response.body!['Answer'] as List) rr['data'] as String,
    ], 0);
  }

  @override
  Future<void> disable() async {}
}

void main() {
  test(
    'official SDK wire uses loopback authentication, both families and raw TTL',
    () async {
      var rawCalls = 0;
      final sdk = _Sdk();
      final loopback = OwnedDnsSdkLoopback(
        hosts: {'link.zolmid.com'},
        adapter: sdk,
        rawLookup: (host) async {
          expect(host, 'link.zolmid.com');
          rawCalls++;
          return OwnedDnsAnswer(['192.0.2.10', '2001:db8::10'], 30);
        },
      );
      addTearDown(loopback.close);
      final result = await loopback.lookup('link.zolmid.com');
      expect(result, isNotNull);
      expect(result!.addresses.length, 2);
      expect(result.ttl, inInclusiveRange(29, 30));
      expect(rawCalls, 2);
      expect(await loopback.lookup('example.com'), isNull);
      expect(sdk.replies.where((value) => value == 403).length, 2);
    },
  );

  test(
    'cached or forged SDK addresses without a fresh issued raw answer are rejected',
    () async {
      final sdk = _Sdk()..poisoned = true;
      final loopback = OwnedDnsSdkLoopback(
        hosts: {'link.zolmid.com'},
        adapter: sdk,
        rawLookup: (_) async => throw StateError('must not query'),
      );
      addTearDown(loopback.close);
      expect(await loopback.lookup('link.zolmid.com'), isNull);
    },
  );

  test(
    'an otherwise valid signed request is rejected after the memory grant expires',
    () async {
      var now = DateTime.now();
      var rawCalls = 0;
      final sdk = _Sdk();
      final loopback = OwnedDnsSdkLoopback(
        hosts: {'link.zolmid.com'},
        adapter: sdk,
        now: () => now,
        rawLookup: (_) async {
          rawCalls++;
          return OwnedDnsAnswer(['192.0.2.10'], 30);
        },
      );
      addTearDown(loopback.close);
      sdk.customLookup = (host) async {
        now = now.add(const Duration(minutes: 6));
        sdk.timestampOverride = now.millisecondsSinceEpoch ~/ 1000;
        expect((await sdk.request(host, 1)).status, 403);
        return null;
      };
      expect(await loopback.lookup('link.zolmid.com'), isNull);
      expect(rawCalls, 0);
    },
  );

  test('closed proxy cannot use the SDK or disclose a new grant', () async {
    final loopback = OwnedDnsSdkLoopback(
      hosts: {'link.zolmid.com'},
      adapter: _Sdk(),
      rawLookup: (_) async => throw StateError('must not query'),
    );
    await loopback.close();
    expect(await loopback.lookup('link.zolmid.com'), isNull);
  });
}
