import 'dart:convert';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_native_renewal.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zolnit_client/zolnit_client.dart';

const zolnitSubscriptionTrustAsset =
    'core/clientbundle/subscription_trust.json';

ZolnitSignedSubscriptions createZolnitSignedSubscriptions(
  Ref ref, {
  required String platform,
}) => ZolnitSignedSubscriptions(
  owner: CoreSignedSubscriptionOwner(ref.read(coreHandlerProvider)),
  vault: SecureInstallationVault(ref.read(zolnitSecureStorageProvider)),
  platform: platform,
  verifier: () async => SignedSubscriptionVerifier.fromTrustJson(
    await rootBundle.loadString(zolnitSubscriptionTrustAsset),
  ),
);

/// Forwards to the Core, which alone verifies, commits and projects signed
/// packages. Calls bypass argument logging: envelopes carry credentials.
class CoreSignedSubscriptionOwner implements ZolnitSignedSubscriptionOwner {
  CoreSignedSubscriptionOwner(this.core);
  final CoreController core;

  Future<Object?> _call(
    CoreMethod method,
    Map<String, Object?>? arguments,
  ) async {
    try {
      return await core.signedSubscription(method, arguments);
    } on CoreMethodException catch (error) {
      throw ClientFailure(
        error.code.startsWith('subscription_') ||
                error.code.startsWith('signed_') ||
                error.code.startsWith('invalid_')
            ? error.code
            : 'core_unavailable',
      );
    }
  }

  @override
  Future<int?> available() async {
    final value = await _call(CoreMethod.getSignedSubscription, const {});
    final state = ZolnitSignedState.fromJson(value);
    if (!state.available) return null;
    if (value is! Map || value['intent'] is! int) {
      throw const ClientFailure('core_unavailable');
    }
    return value['intent'] as int;
  }

  @override
  Future<int> invalidate() async {
    final intent = await available();
    if (intent == null) throw const ClientFailure('core_unavailable');
    final result = await _call(CoreMethod.invalidateSignedSubscription, {
      'intent': intent,
    });
    if (result is! int) throw const ClientFailure('core_unavailable');
    return result;
  }

  @override
  Future<bool> refusesUnsigned(String accountId) async {
    final state = ZolnitSignedState.fromJson(
      await _call(CoreMethod.getSignedSubscription, {'accountId': accountId}),
    );
    if (!state.available) throw const ClientFailure('core_unavailable');
    return state.hasFloor;
  }

  @override
  Future<ZolnitSignedState> status({
    required String accountId,
    required String deviceId,
  }) async => ZolnitSignedState.fromJson(
    await _call(CoreMethod.getSignedSubscription, {
      'accountId': accountId,
      'deviceId': deviceId,
    }),
  );

  @override
  Future<ZolnitSignedState> apply({
    required String accountId,
    required String deviceId,
    required String envelope,
    required int intent,
  }) async => ZolnitSignedState.fromJson(
    await _call(CoreMethod.applySignedSubscription, {
      'accountId': accountId,
      'deviceId': deviceId,
      'envelope': envelope,
      'intent': intent,
    }),
  );

  @override
  Future<Json> project({
    required String accountId,
    required String deviceId,
  }) async {
    final value = await _call(CoreMethod.projectSignedSubscription, {
      'accountId': accountId,
      'deviceId': deviceId,
    });
    final body = value is Map ? value['body'] : null;
    final decoded = body is String ? await compute(jsonDecode, body) : null;
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Json) throw const ClientFailure('invalid_signed_subscription');
    return data;
  }

  Future<({Json data, ZolnitSignedState state, int intent})> current({
    required String accountId,
    required String deviceId,
    required int intent,
    required Map<String, dynamic> lease,
  }) async {
    final Object? value;
    try {
      value = await _call(CoreMethod.projectSignedSubscription, {
        'accountId': accountId,
        'deviceId': deviceId,
        'intent': intent,
        'current': true,
        'lease': lease,
      });
    } on ClientFailure catch (error) {
      if (error.code == 'signed_projection_unavailable') {
        throw const ClientFailure('core_unavailable');
      }
      rethrow;
    }
    if (value is! Map ||
        value['body'] is! String ||
        value['lease'] is! Map ||
        value['state'] is! Map ||
        (value['state'] as Map)['intent'] != intent) {
      throw const ClientFailure('core_unavailable');
    }
    final current = value['lease'] as Map;
    for (final key in const [
      'instanceId',
      'token',
      'configurationGeneration',
      'accountId',
      'accountGeneration',
      'bundleId',
      'configurationDigest',
      'expiresAt',
    ]) {
      if (current[key] != lease[key]) throw const ClientFailure('superseded');
    }
    final decoded = await compute(jsonDecode, value['body'] as String);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Json ||
        data['bundle_id'] != lease['bundleId'] ||
        data['account_id'] != accountId ||
        data['expires_at'] is! int ||
        (data['expires_at'] as int) * 1000 != lease['expiresAt']) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    return (
      data: data,
      state: ZolnitSignedState.fromJson(value['state']),
      intent: intent,
    );
  }

  @override
  Future<void> signOut(int intent) async {
    final result = await _call(CoreMethod.signOutSignedSubscription, {
      'intent': intent,
    });
    if (result != true) throw const ClientFailure('core_unavailable');
  }
}

class SecureInstallationVault implements ZolnitInstallationVault {
  SecureInstallationVault(this.storage);
  final FlutterSecureStorage storage;
  static const _installation = 'zolnit.installation.secret.v1';
  static const _enrollment = 'zolnit.installation.enrollment.v1';
  static const _signOutPending = 'zolnit.installation.signout-pending.v1';

  @override
  Future<String?> readInstallationId() => storage.read(key: _installation);
  @override
  Future<void> writeInstallationId(String value) =>
      storage.write(key: _installation, value: value);
  @override
  Future<String?> readEnrollment() => storage.read(key: _enrollment);
  @override
  Future<void> writeEnrollment(String value) =>
      storage.write(key: _enrollment, value: value);
  @override
  Future<bool> readSignOutPending() async =>
      await storage.read(key: _signOutPending) != null;
  @override
  Future<void> writeSignOutPending(bool value) => value
      ? storage.write(key: _signOutPending, value: '1')
      : storage.delete(key: _signOutPending);
}
