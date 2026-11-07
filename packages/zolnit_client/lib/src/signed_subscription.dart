import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

const signedSubscriptionPrefix = 'ZOLNIT-SUBSCRIPTION-V2\n';
const _issuer = 'https://link.zolmid.com';
const _audience = 'zolnit-client-subscription-v2';
const _maxSafeInteger = 9007199254740991;
const _deviceId = r'^[a-f0-9]{32}$';

/// Official signed enrollment leaves public subscription formats unchanged.
class SignedSubscriptionCapability {
  const SignedSubscriptionCapability({
    required this.officialInstallation,
    required this.deviceRegistered,
    required this.hasProductionPin,
    required this.hasV2Floor,
  });

  final bool officialInstallation;
  final bool deviceRegistered;
  final bool hasProductionPin;
  final bool hasV2Floor;

  bool get enabled =>
      officialInstallation && deviceRegistered && hasProductionPin;

  bool permitsUnsignedReplacement() => !hasV2Floor;
}

class SignedSubscription {
  const SignedSubscription._({
    required this.kind,
    required this.accountId,
    required this.deviceId,
    required this.serial,
    required this.issuedAt,
    required this.expiresAt,
    required this.bundleId,
    required this.payload,
    required this.digest,
  });

  final String kind;
  final String accountId;
  final String deviceId;
  final int serial;
  final int issuedAt;
  final int? expiresAt;
  final String bundleId;
  final Json payload;
  final String digest;

  bool get isBundle => kind == 'bundle';
  bool get isRevoked => kind == 'revoked';
  bool get isState => kind == 'state';
  bool get needsRefresh => payload['needs_refresh'] == true;
  String? get currentBundleId => payload['current_bundle_id'] as String?;
}

/// Pins come from the bundled Core trust asset; responses cannot add keys.
class SignedSubscriptionVerifier {
  SignedSubscriptionVerifier() : _keys = const {};

  SignedSubscriptionVerifier._(this._keys);

  /// An unreadable or malformed trust document yields no pins.
  factory SignedSubscriptionVerifier.fromTrustJson(String source) {
    try {
      final document = jsonDecode(source);
      final map = document is Json ? document['public_key_map'] : null;
      if (document is! Json || document.length != 1 || map is! Json) {
        return SignedSubscriptionVerifier();
      }
      final keys = <String, SimplePublicKey>{};
      for (final MapEntry(:key, :value) in map.entries) {
        if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(key) ||
            value is! String) {
          return SignedSubscriptionVerifier();
        }
        final bytes = _decodeBase64Url(value);
        if (bytes.length != 32) return SignedSubscriptionVerifier();
        keys[key] = SimplePublicKey(
          Uint8List.fromList(bytes),
          type: KeyPairType.ed25519,
        );
      }
      return SignedSubscriptionVerifier._(Map.unmodifiable(keys));
    } on Object {
      return SignedSubscriptionVerifier();
    }
  }

  @visibleForTesting
  SignedSubscriptionVerifier.testOnlyRfc8032(List<int> publicKey)
    : _keys = publicKey.length == 32
          ? Map<String, SimplePublicKey>.unmodifiable({
              'rfc8032-test': SimplePublicKey(
                Uint8List.fromList(publicKey),
                type: KeyPairType.ed25519,
              ),
            })
          : const {};

  final Map<String, SimplePublicKey> _keys;
  final Ed25519 _algorithm = Ed25519();

  bool get hasPins => _keys.isNotEmpty;

  Future<SignedSubscription> verify(
    Object? value, {
    required String accountId,
    required String deviceId,
  }) async {
    if (value is! Json ||
        !_validText(accountId) ||
        !RegExp(_deviceId).hasMatch(deviceId)) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    final signed = value['signed'];
    if (signed is! Json ||
        signed['kid'] is! String ||
        signed['payload'] is! String ||
        signed['signature'] is! String) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    final key = _keys[signed['kid']];
    final payloadBytes = _decodeBase64Url(signed['payload'] as String);
    final signature = _decodeBase64Url(signed['signature'] as String);
    if (key == null ||
        signature.length != 64 ||
        payloadBytes.length > 5 * 1024 * 1024) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    _rejectDuplicateJsonKeys(payloadBytes);
    final decoded = utf8.decode(payloadBytes, allowMalformed: false);
    final payload = jsonDecode(decoded);
    if (payload is! Json ||
        !await _algorithm.verify(
          Uint8List.fromList(
            utf8.encode(signedSubscriptionPrefix) + payloadBytes,
          ),
          signature: Signature(signature, publicKey: key),
        )) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    final kind = payload['kind'];
    final serial = payload['serial'];
    final issued = payload['issued_at'];
    final expiry = payload['expires_at'];
    if (!const {'bundle', 'revoked', 'state'}.contains(kind) ||
        payload['schema_version'] != 2 ||
        payload['issuer'] != _issuer ||
        payload['audience'] != _audience ||
        payload['account_id'] != accountId ||
        payload['device_id'] != deviceId ||
        !_validPositiveInteger(serial) ||
        !_validTimestamp(issued) ||
        !(expiry == null || (_validTimestamp(expiry) && expiry > issued)) ||
        !_validText(payload['bundle_id'])) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    for (final field in [
      'schema_version',
      'kind',
      'account_id',
      'device_id',
      'serial',
      'issued_at',
      'expires_at',
      'bundle_id',
    ]) {
      if (!_jsonEqual(value[field], payload[field])) {
        throw const ClientFailure('invalid_signed_subscription');
      }
    }
    if (kind == 'bundle' &&
        (payload['connection'] is! Json ||
            payload['outbounds'] is! List ||
            payload['routing'] is! Json)) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    if (kind == 'revoked' && payload['reason'] is! String) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    if (kind == 'state' &&
        (payload['current_bundle_id'] is! String ||
            payload['needs_refresh'] is! bool)) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    return SignedSubscription._(
      kind: kind as String,
      accountId: accountId,
      deviceId: deviceId,
      serial: serial as int,
      issuedAt: issued as int,
      expiresAt: expiry as int?,
      bundleId: payload['bundle_id'] as String,
      payload: Map<String, dynamic>.unmodifiable(payload),
      digest: sha256.convert(payloadBytes).toString(),
    );
  }
}

bool _validText(Object? value) =>
    value is String &&
    value.isNotEmpty &&
    value.length <= 256 &&
    value.trim() == value;
bool _validPositiveInteger(Object? value) =>
    value is int && value > 0 && value <= _maxSafeInteger;
bool _validTimestamp(Object? value) =>
    value is int && value > 0 && value <= _maxSafeInteger;
bool _jsonEqual(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

List<int> _decodeBase64Url(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const ClientFailure('invalid_signed_subscription');
  }
  final bytes = base64Url.decode(base64Url.normalize(value));
  if (base64UrlEncode(bytes).replaceAll('=', '') != value) {
    throw const ClientFailure('invalid_signed_subscription');
  }
  return bytes;
}

void _rejectDuplicateJsonKeys(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: false);
  final cursor = _JsonKeyCursor(text);
  cursor.value();
  cursor.space();
  if (!cursor.done) throw const ClientFailure('invalid_signed_subscription');
}

class _JsonKeyCursor {
  _JsonKeyCursor(this.source);
  final String source;
  int index = 0;
  bool get done => index == source.length;
  void space() {
    while (index < source.length && source.codeUnitAt(index) <= 0x20) {
      index++;
    }
  }

  void value() {
    space();
    if (index >= source.length) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    switch (source[index]) {
      case '{':
        object();
      case '[':
        array();
      case '"':
        string();
      default:
        scalar();
    }
  }

  void object() {
    index++;
    space();
    final keys = <String>{};
    if (take('}')) return;
    while (true) {
      space();
      final key = string();
      if (!keys.add(key)) {
        throw const ClientFailure('invalid_signed_subscription');
      }
      space();
      if (!take(':')) throw const ClientFailure('invalid_signed_subscription');
      value();
      space();
      if (take('}')) return;
      if (!take(',')) throw const ClientFailure('invalid_signed_subscription');
    }
  }

  void array() {
    index++;
    space();
    if (take(']')) return;
    while (true) {
      value();
      space();
      if (take(']')) return;
      if (!take(',')) throw const ClientFailure('invalid_signed_subscription');
    }
  }

  String string() {
    if (!take('"')) throw const ClientFailure('invalid_signed_subscription');
    final start = index - 1;
    var escaped = false;
    while (index < source.length) {
      final c = source[index++];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        final raw = source.substring(start, index);
        try {
          final value = jsonDecode(raw);
          if (value is String) return value;
        } catch (_) {}
        break;
      }
    }
    throw const ClientFailure('invalid_signed_subscription');
  }

  void scalar() {
    final start = index;
    while (index < source.length && !' \t\r\n,]}'.contains(source[index])) {
      index++;
    }
    if (start == index) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    final token = source.substring(start, index);
    try {
      jsonDecode(token);
    } catch (_) {
      throw const ClientFailure('invalid_signed_subscription');
    }
  }

  bool take(String token) {
    if (index < source.length && source[index] == token) {
      index++;
      return true;
    }
    return false;
  }
}
