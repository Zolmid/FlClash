import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_native_renewal.dart';
import 'package:fl_clash/providers/zolnit_vault.dart';
import 'package:zolnit_client/zolnit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iosSetupHandoffEnabledProvider = Provider<bool>((ref) => system.isIOS);

final iosOwnedDNSRequiredProvider = Provider<bool>(
  (ref) => ownedDnsBinding != null,
);

final iosSetupHandoffProvider = NotifierProvider<IOSSetupHandoff, SetupParams?>(
  IOSSetupHandoff.new,
);

class IOSSetupHandoff extends Notifier<SetupParams?> {
  @override
  SetupParams? build() {
    ref.watch(
      currentProfileProvider.select(
        (profile) => (
          profile?.id,
          profile?.zolnitAccountId,
          profile?.zolnitBundleId,
          profile?.zolnitOrigin,
          profile?.lastUpdateDate,
        ),
      ),
    );
    final session = ref.watch(zolnitSessionProvider);
    Object identity() => (
      session.authenticated,
      session.api.generation,
      session.signedSubscriptions?.active?.accountId,
      session.signedSubscriptions?.active?.device.deviceId,
      session.signedSubscriptions?.active?.intent,
    );
    var binding = identity();
    void changed() {
      final next = identity();
      if (binding == next) return;
      binding = next;
      state = null;
    }

    session.addListener(changed);
    ref.onDispose(() => session.removeListener(changed));
    return null;
  }

  bool prepare(SetupParams params, {required int? profileId}) {
    final profile = ref.read(currentProfileProvider);
    if (profile?.id != profileId) return false;
    final lease = params.routingLease;
    if (profile != null && isZolnitBundleProfile(profile) && lease == null) {
      return false;
    }
    if (lease != null) {
      final session = ref.read(zolnitSessionProvider);
      if (!session.authenticated ||
          lease['accountGeneration'] != session.api.generation ||
          lease['accountId'] != profile?.zolnitAccountId ||
          lease['bundleId'] != profile?.zolnitBundleId) {
        return false;
      }
      final signed = session.signedSubscriptions?.active;
      if (signed?.accountId == lease['accountId'] &&
          lease['signedDeviceId'] == null) {
        return false;
      }
      if (lease['signedDeviceId'] != null) {
        if (signed == null ||
            signed.accountId != lease['accountId'] ||
            signed.device.deviceId != lease['signedDeviceId'] ||
            lease['signedSerial'] is! int ||
            (lease['signedSerial'] as int) <= 0 ||
            signed.intent != lease['signedIntent']) {
          return false;
        }
      }
    }
    state = params;
    return true;
  }

  Future<bool> startAuthorized({
    required SetupParams? params,
    required bool Function() isCurrent,
    required Future<bool> Function() dispatch,
  }) async {
    if (!isCurrent()) return false;
    final lease = params?.routingLease;
    if (lease == null || !ref.read(iosOwnedDNSRequiredProvider)) {
      return isCurrent() ? dispatch() : false;
    }
    bool current() => ref.mounted && isCurrent() && identical(state, params);
    if (!current()) return false;
    final session = ref.read(zolnitSessionProvider);
    final generation = session.api.generation;
    final signed = session.signedSubscriptions?.active;
    if (!session.authenticated ||
        lease['accountGeneration'] != generation ||
        (lease['signedDeviceId'] != null &&
            (signed?.accountId != lease['accountId'] ||
                signed?.device.deviceId != lease['signedDeviceId'] ||
                signed?.intent != lease['signedIntent']))) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    final authorization = await ref
        .read(zolnitSessionVaultProvider)
        .readAuthorization();
    if (!current() || session.api.generation != generation) return false;
    if (authorization == null) {
      throw const ClientFailure('native_renewal_unavailable');
    }
    final receipt = await ref
        .read(zolnitNativeRenewalClientProvider)
        .configure(
          accountId: lease['accountId'] as String,
          accountGeneration: generation,
          authorization: authorization,
          distribution: session.api.distribution ?? 'direct',
          signedDevice: lease['signedDeviceId'] == null ? null : signed?.device,
        );
    if (!current() || session.api.generation != generation) return false;
    if (receipt.sessionEpoch == null || receipt.ownerId == null) {
      throw const ClientFailure('native_renewal_unavailable');
    }
    return dispatch();
  }

  void clear(SetupParams? expected) {
    if (identical(state, expected)) state = null;
  }
}
