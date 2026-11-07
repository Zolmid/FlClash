import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'api.dart';
import 'signed_subscription.dart';

/// Credential-free view of the Core's signed subscription store.
class ZolnitSignedState {
  const ZolnitSignedState({
    this.available = false,
    this.hasFloor = false,
    this.installed = false,
    this.revoked = false,
    this.expired = false,
    this.needsRefresh = false,
    this.serial,
    this.bundleId,
    this.subscriptionExpiresAt,
  });

  factory ZolnitSignedState.fromJson(Object? value) {
    if (value is! Map) throw const ClientFailure('invalid_signed_subscription');
    final expiry = value['subscriptionExpiresAt'];
    return ZolnitSignedState(
      available: value['available'] == true,
      hasFloor: value['hasFloor'] == true,
      installed: value['installed'] == true,
      revoked: value['revoked'] == true,
      expired: value['expired'] == true,
      needsRefresh: value['needsRefresh'] == true,
      serial: value['serial'] is int ? value['serial'] as int : null,
      bundleId: value['bundleId'] is String
          ? value['bundleId'] as String
          : null,
      subscriptionExpiresAt: expiry is int
          ? DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true)
          : null,
    );
  }

  final bool available;
  final bool hasFloor;
  final bool installed;
  final bool revoked;
  final bool expired;
  final bool needsRefresh;
  final int? serial;
  final String? bundleId;
  final DateTime? subscriptionExpiresAt;
}

/// The Core is the only writer of signed state; the app asks it to verify,
/// commit and project packages and never stores them itself.
abstract interface class ZolnitSignedSubscriptionOwner {
  Future<int?> available();

  Future<int> invalidate();

  Future<bool> refusesUnsigned(String accountId);

  Future<ZolnitSignedState> status({
    required String accountId,
    required String deviceId,
  });

  Future<ZolnitSignedState> apply({
    required String accountId,
    required String deviceId,
    required String envelope,
    required int intent,
  });

  /// Returns the installed package as a v1 bundle object with a short lease.
  Future<Json> project({required String accountId, required String deviceId});

  Future<void> signOut(int intent);
}

/// Secure storage for the installation secret and the device it registered.
abstract interface class ZolnitInstallationVault {
  Future<String?> readInstallationId();

  Future<void> writeInstallationId(String value);

  Future<String?> readEnrollment();

  Future<void> writeEnrollment(String value);

  Future<bool> readSignOutPending();

  Future<void> writeSignOutPending(bool value);
}

typedef _Enrollment = ({
  String origin,
  String accountId,
  String deviceId,
  String? identityScope,
});

class ZolnitSignedSubscriptions {
  ZolnitSignedSubscriptions({
    required this.owner,
    required this.vault,
    required Future<SignedSubscriptionVerifier> Function() verifier,
    required this.platform,
    this.stateInterval = const Duration(minutes: 5),
    Random? random,
    Stopwatch? monotonic,
  }) : _loadVerifier = verifier,
       _random = random ?? Random.secure(),
       _monotonic = monotonic ?? (Stopwatch()..start());

  final ZolnitSignedSubscriptionOwner owner;
  final ZolnitInstallationVault vault;
  final String platform;
  final Duration stateInterval;
  final Future<SignedSubscriptionVerifier> Function() _loadVerifier;
  final Random _random;
  final Stopwatch _monotonic;
  Future<SignedSubscriptionVerifier>? _verifier;
  ZolnitClientDevice? _registered;
  int? _registeredGeneration;
  Duration? _stateCheckedAt;
  int _revision = 0;
  Future<void> _writes = Future.value();
  Future<void> _intentTail = Future.value();
  bool _logoutUnconfirmed = false;
  ({String accountId, ZolnitClientDevice device, int serial, int intent})?
  _active;

  static final _installation = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final _deviceId = RegExp(r'^[a-f0-9]{32}$');

  /// The installation currently served from signed material, for handing to
  /// the native renewal owner of the same account.
  ({String accountId, ZolnitClientDevice device, int serial, int intent})?
  get active => _active;

  /// Returns a projected v1 bundle object, or null when signed subscriptions
  /// are not negotiated for this installation and the legacy path applies.
  Future<Json?> bundle(
    XboardClient api, {
    required String coreVersion,
    String? expectedAccountId,
    String? identityScope,
  }) async {
    final generation = api.generation;
    final revision = _revision;
    void checkCurrent() {
      if (generation != api.generation || revision != _revision) {
        throw const ClientFailure('superseded');
      }
    }

    final verifier = await (_verifier ??= _loadVerifier());
    if (await vault.readSignOutPending()) {
      throw const ClientFailure('core_unavailable');
    }
    if (!verifier.hasPins) {
      if (await _legacyFallbackSafe()) return null;
      throw const ClientFailure('signed_subscription_required');
    }
    late final int intent;
    try {
      await _intentTail;
      final currentIntent = await owner.available();
      if (currentIntent == null) {
        if (await _legacyFallbackSafe()) return null;
        throw const ClientFailure('signed_subscription_required');
      }
      intent = currentIntent;
    } catch (error) {
      if (error is! TimeoutException &&
          (error is! ClientFailure ||
              error.code != 'core_unavailable' &&
                  error.code != 'invalid_signed_subscription')) {
        rethrow;
      }
      final safe = await _legacyFallbackSafe();
      checkCurrent();
      if (safe) return null;
      rethrow;
    }
    final installation = await _installationId();
    final origin = api.origin.origin;
    final enrollment = await _enrollment(origin);
    checkCurrent();
    var device = _registeredGeneration == api.generation ? _registered : null;
    if (device == null) {
      try {
        device = await api.registerClientDevice(
          installationId: installation,
          platform: platform,
        );
        checkCurrent();
        _registered = device;
        _registeredGeneration = generation;
      } on ClientFailure {
        checkCurrent();
        if (enrollment == null ||
            identityScope == null ||
            enrollment.identityScope != identityScope ||
            (expectedAccountId != null &&
                enrollment.accountId != expectedAccountId)) {
          return null;
        }
        device = ZolnitClientDevice(
          deviceId: enrollment.deviceId,
          installationId: installation,
        );
      }
    }
    var accountId =
        expectedAccountId ??
        (enrollment?.deviceId == device.deviceId
            ? enrollment!.accountId
            : null);
    var state = accountId == null
        ? null
        : await owner.status(accountId: accountId, deviceId: device.deviceId);
    final deviceId = device.deviceId;
    final capability = SignedSubscriptionCapability(
      officialInstallation: true,
      deviceRegistered: true,
      hasProductionPin: verifier.hasPins,
      hasV2Floor: state?.hasFloor == true,
    );
    var applyStarted = false;
    if (state?.installed != true || _stateDue()) {
      try {
        final wasRevoked = state?.revoked == true;
        if (state?.installed == true) {
          applyStarted = true;
          state = await _apply(
            verifier,
            await api.fetchSignedSubscriptionState(device),
            device,
            accountId,
            checkCurrent,
            origin,
            identityScope,
            intent,
          );
        }
        if (state == null ||
            !state.installed && (!state.revoked || wasRevoked)) {
          final envelope = await api.fetchSignedClientBundle(
            coreVersion: coreVersion,
            device: device,
          );
          accountId ??= _claimedAccount(envelope);
          applyStarted = true;
          state = await _apply(
            verifier,
            envelope,
            device,
            accountId,
            checkCurrent,
            origin,
            identityScope,
            intent,
          );
        } else if (state.needsRefresh && !state.revoked) {
          applyStarted = true;
          state = await _apply(
            verifier,
            await api.fetchSignedClientBundle(
              coreVersion: coreVersion,
              device: device,
            ),
            device,
            accountId,
            checkCurrent,
            origin,
            identityScope,
            intent,
          );
        }
        checkCurrent();
        _stateCheckedAt = _monotonic.elapsed;
      } on ClientFailure {
        checkCurrent();
        if (applyStarted && state?.installed != true) rethrow;
        // A failed or rejected refresh leaves the Core's store unchanged; only
        // a signed revocation or expiry removes an installed package.
        if (accountId == null ||
            (state?.installed != true &&
                capability.permitsUnsignedReplacement())) {
          return null;
        }
      }
    }
    checkCurrent();
    if (enrollment?.accountId != accountId ||
        enrollment?.deviceId != device.deviceId ||
        enrollment?.identityScope != identityScope) {
      await _write(() async {
        checkCurrent();
        await vault.writeEnrollment(
          jsonEncode({
            'origin': origin,
            'account_id': accountId,
            'device_id': deviceId,
            'identity_scope': identityScope,
          }),
        );
      });
    }
    final projected = await owner.project(
      accountId: accountId!,
      deviceId: device.deviceId,
    );
    checkCurrent();
    final serial = state?.serial;
    if (serial == null) {
      throw const ClientFailure('signed_subscription_required');
    }
    _active = (
      accountId: accountId,
      device: device,
      serial: serial,
      intent: intent,
    );
    return projected;
  }

  /// True when this installation already holds signed material for the
  /// account, so an unsigned bundle must not replace it.
  Future<bool> refusesUnsigned(XboardClient api, String accountId) async {
    final verifier = await (_verifier ??= _loadVerifier());
    if (!verifier.hasPins) return false;
    if (await _legacyFallbackSafe()) return false;
    return owner.refusesUnsigned(accountId);
  }

  Future<bool> _legacyFallbackSafe() async =>
      await vault.readEnrollment() == null &&
      await vault.readInstallationId() == null;

  /// Explicit logout only: removes stored credentials, keeps replay floors.
  Future<void> signOut() async {
    _resetSession();
    _logoutUnconfirmed = true;
    final marker = vault.writeSignOutPending(true);
    Future<void> clear() async {
      await marker;
      try {
        final intent = await owner.invalidate();
        await owner.signOut(intent);
      } catch (error, stack) {
        if (!await _legacyFallbackSafe()) {
          Error.throwWithStackTrace(error, stack);
        }
      }
      await vault.writeSignOutPending(false);
      _logoutUnconfirmed = false;
    }

    final operation = _intentTail.then((_) => clear(), onError: (_) => clear());
    _intentTail = operation;
    await operation;
  }

  Future<void> invalidate() {
    _resetSession();
    Future<void> advance() async {
      if (_logoutUnconfirmed || await vault.readSignOutPending()) {
        throw const ClientFailure('core_unavailable');
      }
      await owner.invalidate();
    }

    final operation = _intentTail.then(
      (_) => advance(),
      onError: (_) => advance(),
    );
    _intentTail = operation;
    return operation;
  }

  void _resetSession() {
    _revision++;
    _active = null;
    _registered = null;
    _registeredGeneration = null;
    _stateCheckedAt = null;
  }

  bool _stateDue() {
    final checked = _stateCheckedAt;
    return checked == null || _monotonic.elapsed - checked >= stateInterval;
  }

  String _claimedAccount(Json envelope) {
    final account = envelope['account_id'];
    if (account is! String) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    return account;
  }

  Future<ZolnitSignedState> _apply(
    SignedSubscriptionVerifier verifier,
    Json envelope,
    ZolnitClientDevice device,
    String? accountId,
    void Function() checkCurrent,
    String origin,
    String? identityScope,
    int intent,
  ) async {
    final verified = await verifier.verify(
      envelope,
      accountId: accountId ?? _claimedAccount(envelope),
      deviceId: device.deviceId,
    );
    return _write(() async {
      checkCurrent();
      await vault.writeEnrollment(
        jsonEncode({
          'origin': origin,
          'account_id': verified.accountId,
          'device_id': device.deviceId,
          'identity_scope': identityScope,
        }),
      );
      checkCurrent();
      return owner.apply(
        accountId: verified.accountId,
        deviceId: device.deviceId,
        envelope: jsonEncode(envelope),
        intent: intent,
      );
    });
  }

  Future<T> _write<T>(Future<T> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<String> _installationId() async {
    final stored = await vault.readInstallationId();
    if (stored != null && _installation.hasMatch(stored)) return stored;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final created = base64UrlEncode(bytes).replaceAll('=', '');
    await vault.writeInstallationId(created);
    return created;
  }

  Future<_Enrollment?> _enrollment(String origin) async {
    final text = await vault.readEnrollment();
    if (text == null) return null;
    try {
      final value = jsonDecode(text);
      if (value is Json &&
          value['origin'] == origin &&
          value['account_id'] is String &&
          value['device_id'] is String &&
          _deviceId.hasMatch(value['device_id'] as String)) {
        return (
          origin: origin,
          accountId: value['account_id'] as String,
          deviceId: value['device_id'] as String,
          identityScope: value['identity_scope'] is String
              ? value['identity_scope'] as String
              : null,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
