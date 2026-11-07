import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

const _account = 'account-1';
const _device = '0123456789abcdef0123456789abcdef';
const _seed = <int>[
  0x9d,
  0x61,
  0xb1,
  0x9d,
  0xef,
  0xfd,
  0x5a,
  0x60,
  0xba,
  0x84,
  0x4a,
  0xf4,
  0x92,
  0xec,
  0x2c,
  0xc4,
  0x44,
  0x49,
  0xc5,
  0x69,
  0x7b,
  0x32,
  0x69,
  0x19,
  0x70,
  0x3b,
  0xac,
  0x03,
  0x1c,
  0xae,
  0x7f,
  0x60,
];
const _public = <int>[
  0xd7,
  0x5a,
  0x98,
  0x01,
  0x82,
  0xb1,
  0x0a,
  0xb7,
  0xd5,
  0x4b,
  0xfe,
  0xd3,
  0xc9,
  0x64,
  0x07,
  0x3a,
  0x0e,
  0xe1,
  0x72,
  0xf3,
  0xda,
  0xa6,
  0x23,
  0x25,
  0xaf,
  0x02,
  0x1a,
  0x68,
  0xf7,
  0x07,
  0x51,
  0x1a,
];

Future<({Json envelope, List<int> publicKey})> _signed({
  String kind = 'bundle',
  int serial = 2,
}) async {
  final payload = <String, dynamic>{
    'schema_version': 2,
    'issuer': 'https://link.zolmid.com',
    'audience': 'zolnit-client-subscription-v2',
    'kind': kind,
    'account_id': _account,
    'device_id': _device,
    'serial': serial,
    'issued_at': 1000,
    'expires_at': kind == 'revoked' ? null : 2000,
    'bundle_id': 'bundle-$serial',
    if (kind == 'bundle') ...{
      'connection': <String, dynamic>{},
      'outbounds': <dynamic>[],
      'routing': <String, dynamic>{},
    },
    if (kind == 'state') ...{
      'current_bundle_id': 'bundle-1',
      'needs_refresh': true,
    },
    if (kind == 'revoked') 'reason': 'session_revoked',
  };
  final bytes = utf8.encode(jsonEncode(payload));
  final key = SimpleKeyPairData(
    Uint8List.fromList(_seed),
    publicKey: SimplePublicKey(
      Uint8List.fromList(_public),
      type: KeyPairType.ed25519,
    ),
    type: KeyPairType.ed25519,
  );
  final algorithm = Ed25519();
  final signature = await algorithm.sign(
    utf8.encode('$signedSubscriptionPrefix${utf8.decode(bytes)}'),
    keyPair: key,
  );
  final publicKey = await key.extractPublicKey();
  return (
    publicKey: publicKey.bytes.toList(),
    envelope: <String, dynamic>{
      'schema_version': 2,
      'kind': kind,
      'account_id': _account,
      'device_id': _device,
      'serial': serial,
      'issued_at': 1000,
      'expires_at': kind == 'revoked' ? null : 2000,
      'bundle_id': 'bundle-$serial',
      'signed': {
        'kid': 'rfc8032-test',
        'payload': base64UrlEncode(bytes).replaceAll('=', ''),
        'signature': base64UrlEncode(signature.bytes).replaceAll('=', ''),
      },
    },
  );
}

void main() {
  test('v2 capability never gates legacy or third-party subscriptions', () {
    const public = SignedSubscriptionCapability(
      officialInstallation: false,
      deviceRegistered: false,
      hasProductionPin: false,
      hasV2Floor: false,
    );
    expect(public.enabled, isFalse);
    expect(public.permitsUnsignedReplacement(), isTrue);
    const enrolled = SignedSubscriptionCapability(
      officialInstallation: true,
      deviceRegistered: true,
      hasProductionPin: true,
      hasV2Floor: true,
    );
    expect(enrolled.enabled, isTrue);
    expect(enrolled.permitsUnsignedReplacement(), isFalse);
  });

  test('production trust asset format yields pins only when populated', () {
    expect(
      SignedSubscriptionVerifier.fromTrustJson('{"public_key_map":{}}').hasPins,
      isFalse,
    );
    expect(
      SignedSubscriptionVerifier.fromTrustJson(
        '{"public_key_map":{"k":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"}}',
      ).hasPins,
      isTrue,
    );
    for (final invalid in [
      '{',
      '{"public_key_map":{"k":"AAAA"}}',
      '{"public_key_map":{},"test":{}}',
    ]) {
      expect(
        SignedSubscriptionVerifier.fromTrustJson(invalid).hasPins,
        isFalse,
      );
    }
  });

  test(
    'test-only injected RFC 8032 key verifies exact signed payload',
    () async {
      final fixture = await _signed();
      final verified = await SignedSubscriptionVerifier.testOnlyRfc8032(
        fixture.publicKey,
      ).verify(fixture.envelope, accountId: _account, deviceId: _device);
      expect(verified.kind, 'bundle');
      expect(verified.serial, 2);
    },
  );

  test('production empty trust map and tampering fail closed', () async {
    final fixture = await _signed();
    await expectLater(
      SignedSubscriptionVerifier().verify(
        fixture.envelope,
        accountId: _account,
        deviceId: _device,
      ),
      throwsA(isA<ClientFailure>()),
    );
    fixture.envelope['bundle_id'] = 'tampered';
    await expectLater(
      SignedSubscriptionVerifier.testOnlyRfc8032(
        fixture.publicKey,
      ).verify(fixture.envelope, accountId: _account, deviceId: _device),
      throwsA(isA<ClientFailure>()),
    );
  });

  test('state is verified but never projects credentials', () async {
    final fixture = await _signed(kind: 'state');
    final verified = await SignedSubscriptionVerifier.testOnlyRfc8032(
      fixture.publicKey,
    ).verify(fixture.envelope, accountId: _account, deviceId: _device);
    expect(verified.needsRefresh, isTrue);
    expect(verified.isBundle, isFalse);
  });
}
