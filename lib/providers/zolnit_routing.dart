import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_native_renewal.dart';
import 'package:fl_clash/providers/zolnit_vault.dart';
import 'package:fl_clash/common/zolnit_native_renewal.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

final zolnitRoutingProbeSchedulerProvider = Provider<RoutingProbeScheduler>((
  ref,
) {
  final scheduler = RoutingProbeScheduler(
    wallClock: ref.read(zolnitBundleClockProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final zolnitRoutingProvider = Provider<ZolnitRouting>((ref) {
  final routing = ZolnitRouting(ref);
  ref.onDispose(routing.dispose);
  ref.listen(currentProfileIdProvider, (_, _) => routing.clear());
  ref.listen(coreStatusProvider, (_, next) {
    if (next == CoreStatus.connected) routing.kick();
  });
  ref.listen(zolnitBundleStatusProvider, (_, next) {
    if (const {
      ZolnitBundleStatus.expired,
      ZolnitBundleStatus.forbidden,
      ZolnitBundleStatus.invalid,
    }.contains(next)) {
      unawaited(routing._invalidateAutomatic(next));
    }
  });
  return routing;
});

class ZolnitCoreLeaseReady extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final zolnitCoreLeaseReadyProvider =
    NotifierProvider<ZolnitCoreLeaseReady, bool>(ZolnitCoreLeaseReady.new);

typedef _RoutingPlan = ({
  int profileId,
  int accountGeneration,
  String digest,
  SmartRoutingManifest? manifest,
  SmartRoutingEngine? engine,
  DateTime? expiresAt,
  String? metadataIdentity,
  String? accountId,
  String? bundleId,
  String? renewalOverlay,
  String? connectionDigest,
  Map<String, dynamic>? returnRoute,
});

typedef _LeaseIdentity = (int, int, DateTime, String?);

class ZolnitRouting with WidgetsBindingObserver {
  ZolnitRouting(this.ref)
    : _probeScheduler = ref.read(zolnitRoutingProbeSchedulerProvider),
      _nativeClient = ref.read(zolnitNativeRenewalClientProvider),
      _nativeSupported = ref.read(zolnitNativeRenewalSupportedProvider) {
    _providerHealth.resetGeneration(_epoch);
    if (_nativeSupported) {
      _nativeClient.addListener(_nativeChanged);
      WidgetsBinding.instance.addObserver(this);
    }
  }

  final Ref ref;
  var _engine = SmartRoutingEngine();
  final RoutingProbeScheduler _probeScheduler;
  final ZolnitNativeRenewalClient _nativeClient;
  final bool _nativeSupported;
  bool _nativeOwned = false;
  bool _nativeConfiguring = false;
  bool _nativePolling = false;
  bool _resuming = false;
  int? _nativeGeneration;
  String? _nativeDigest;
  Timer? _nativePollTimer;
  Timer? _nativeStaleTimer;
  final _providerHealth = RoutingProviderHealthStore();
  Object _probeScope = Object();
  num? _previousTraffic;
  var _servicePosition = 0;
  final _positions = <String, int>{};
  ZolnitSessionController? _session;
  _RoutingPlan? _staged;
  final _preparedPlans = <(int, String), _RoutingPlan>{};
  _RoutingPlan? _active;
  Object? _configuration;
  Map<String, dynamic>? _coreLease;
  Timer? _timer;
  Timer? _expiryTimer;
  Timer? _refreshTimer;
  Object? _invalidLeaseToken;
  final _invalidatedLeases = <_LeaseIdentity, ZolnitBundleStatus>{};

  bool _refreshing = false;
  var _epoch = 0;
  var _intent = 0;
  var _busy = false;
  Completer<void>? _cycleDone;
  var _disposed = false;

  _LeaseIdentity? _leaseIdentity(_RoutingPlan plan) => plan.expiresAt == null
      ? null
      : (
          plan.profileId,
          plan.accountGeneration,
          plan.expiresAt!,
          plan.metadataIdentity,
        );

  bool manages(int profileId) {
    final profile = ref.read(profilesProvider).getProfile(profileId);
    if (profile == null) return false;
    if (isZolnitBundleProfile(profile)) {
      return ref.read(zolnitClientBundleTransportProvider) &&
          isCurrentZolnitBundleProfile(
            profile,
            ref.read(zolnitSessionProvider),
          );
    }
    if (ref.read(zolnitClientBundleTransportProvider) ||
        !profile.label.startsWith('ZolNit · ')) {
      return false;
    }
    final session = ref.read(zolnitSessionProvider);
    return session.authenticated &&
        profile.label == zolnitProfileLabel(session);
  }

  void stage({
    required int profileId,
    required int accountGeneration,
    required String digest,
    required SmartRoutingManifest? manifest,
    SmartRoutingEngine? engine,
    DateTime? expiresAt,
    String? metadataIdentity,
    String? accountId,
    String? bundleId,
    String? renewalOverlay,
    String? connectionDigest,
    Map<String, dynamic>? returnRoute,
  }) {
    if (!manages(profileId)) return;
    final session = ref.read(zolnitSessionProvider);
    if (session.api.generation != accountGeneration) return;
    if (!identical(_session, session)) {
      _invalidatedLeases.clear();
      _session?.removeListener(_accountChanged);
      _session = session..addListener(_accountChanged);
    }
    _staged = (
      profileId: profileId,
      accountGeneration: accountGeneration,
      digest: digest,
      manifest: manifest,
      engine: engine,
      expiresAt: expiresAt,
      metadataIdentity: metadataIdentity,
      accountId: accountId,
      bundleId: bundleId,
      renewalOverlay: renewalOverlay,
      connectionDigest: connectionDigest,
      returnRoute: returnRoute,
    );
    _preparedPlans[(profileId, digest)] = _staged!;
    while (_preparedPlans.length > 8) {
      _preparedPlans.remove(_preparedPlans.keys.first);
    }
  }

  Map<String, String> preparedSelections(
    int profileId,
    String digest,
    Map<String, String> selected,
  ) {
    final plan = _preparedPlans[(profileId, digest)];
    if (plan == null || plan.profileId != profileId || plan.expiresAt == null) {
      return selected;
    }
    return {
      ...selected,
      for (final service
          in plan.manifest?.services ?? const <ManagedRouteService>[])
        service.route.groupName: 'REJECT',
    };
  }

  Map<String, dynamic>? preparedLease(int profileId, String digest) {
    final plan = _preparedPlans[(profileId, digest)];
    if (plan == null ||
        plan.expiresAt == null ||
        !plan.expiresAt!.isAfter(_now) ||
        plan.accountId == null ||
        plan.bundleId == null ||
        _invalidatedLeases.containsKey(_leaseIdentity(plan))) {
      return null;
    }
    return {
      'accountId': plan.accountId,
      'accountGeneration': plan.accountGeneration,
      'bundleId': plan.bundleId,
      'configurationDigest': plan.digest,
      if (plan.connectionDigest != null)
        'connectionDigest': plan.connectionDigest,
      if (plan.metadataIdentity != null)
        'metadataDigest': plan.metadataIdentity,
      if (plan.renewalOverlay != null) 'renewalOverlay': plan.renewalOverlay,
      if (plan.returnRoute != null) 'returnRoute': plan.returnRoute,
      'expiresAt': plan.expiresAt!.millisecondsSinceEpoch,
      'services': [
        for (final service
            in plan.manifest?.services ?? const <ManagedRouteService>[])
          {
            'groupName': service.groupName,
            'automaticGroup': service.route.groupName,
            'manualGroup': service.manualGroup,
            'allowedProxies':
                plan.engine
                    ?.candidates(service.route.id)
                    .map((n) => n.proxyName)
                    .toList() ??
                <String>[],
          },
      ],
    };
  }

  bool _matchesCoreLease(Map<String, dynamic>? guard, _RoutingPlan plan) =>
      guard != null &&
      guard['instanceId'] is String &&
      (guard['instanceId'] as String).isNotEmpty &&
      guard['token'] is String &&
      (guard['token'] as String).isNotEmpty &&
      guard['configurationGeneration'] is int &&
      guard['accountId'] == plan.accountId &&
      guard['accountGeneration'] == plan.accountGeneration &&
      guard['bundleId'] == plan.bundleId &&
      guard['configurationDigest'] == plan.digest &&
      guard['expiresAt'] == plan.expiresAt?.millisecondsSinceEpoch;

  void _leaseReady(bool ready) {
    if (!_disposed) ref.read(zolnitCoreLeaseReadyProvider.notifier).set(ready);
  }

  void _revokeCoreLease() {
    final guard = _coreLease;
    _coreLease = null;
    _leaseReady(false);
    if (guard != null && !ref.read(safeModeProvider)) {
      unawaited(
        ref
            .read(coreHandlerProvider)
            .invalidateRoutingLease(guard)
            .catchError((Object _) => false),
      );
    }
  }

  bool acceptsPrepared(int profileId, String digest) {
    final plan = _preparedPlans[(profileId, digest)];
    return plan != null &&
        plan.profileId == profileId &&
        plan.digest == digest &&
        _session?.authenticated == true &&
        _session?.api.generation == plan.accountGeneration &&
        ref.read(currentProfileIdProvider) == profileId &&
        manages(profileId) &&
        (plan.bundleId == null ||
            ref.read(profilesProvider).getProfile(profileId)?.zolnitBundleId ==
                plan.bundleId);
  }

  DateTime get _now => ref.read(zolnitBundleClockProvider)();

  void _leaseTimers() {
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    final expiry = _active?.expiresAt;
    if (expiry == null) return;
    if (_nativeOwned) return;
    _invalidLeaseToken = null;
    final remaining = expiry.difference(_now);
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      unawaited(_invalidateAutomatic(ZolnitBundleStatus.expired));
    });
    final invalidated = _invalidatedLeases[_leaseIdentity(_active!)];
    if (invalidated != null) {
      unawaited(_invalidateAutomatic(invalidated));
    }
    if (!ref.read(safeModeProvider)) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        unawaited(refreshBundle());
      });
    }
  }

  Future<void> refreshBundle() async {
    if (_nativeOwned) return;
    if (_refreshing || _disposed || _active?.expiresAt == null) return;
    final profileId = _active!.profileId;
    final generation = _active!.accountGeneration;
    _refreshing = true;
    try {
      await ref.read(zolnitSyncClientBundleProvider)();
      if (!_disposed &&
          _session?.authenticated == true &&
          _session?.api.generation == generation &&
          ref.read(currentProfileIdProvider) == profileId) {
        await ref
            .read(setupActionProvider.notifier)
            .applyProfile(silence: true);
      }
    } catch (_) {
      if (!_disposed &&
          _active?.expiresAt != null &&
          (!_active!.expiresAt!.isAfter(_now) ||
              _session?.clientBundleFailure == 'entitlement_unavailable' ||
              _session?.clientBundleFailure == 'invalid_client_bundle' ||
              _session?.clientBundleFailure ==
                  'client_bundle_binding_mismatch')) {
        await _invalidateAutomatic(
          !_active!.expiresAt!.isAfter(_now)
              ? ZolnitBundleStatus.expired
              : bundleFailureStatus(_session?.clientBundleFailure),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _invalidateAutomatic(ZolnitBundleStatus status) async {
    if (_nativeOwned) {
      final plan = _active;
      final generation = _session?.api.generation;
      final guard = await ref.read(coreHandlerProvider).getRoutingLease();
      if (_disposed ||
          !_nativeOwned ||
          !identical(plan, _active) ||
          generation != _session?.api.generation ||
          plan == null) {
        return;
      }
      if (guard != null && guard['accountId'] == plan.accountId) {
        await ref.read(coreHandlerProvider).invalidateRoutingLease(guard);
      }
      _leaseReady(false);
      ref.read(zolnitBundleStatusProvider.notifier).set(status);
      return;
    }
    if (_disposed || _active?.expiresAt == null || _invalidLeaseToken != null) {
      return;
    }
    _revokeCoreLease();
    final token = Object();
    _invalidLeaseToken = token;
    _invalidatedLeases[_leaseIdentity(_active!)!] = status;
    _engine.resetGeneration(++_epoch);
    _providerHealth.resetGeneration(_epoch);
    _probeScope = Object();
    final epoch = _epoch;
    ref.read(zolnitBundleStatusProvider.notifier).set(status);
    final manifest = _active?.manifest;
    if (manifest == null || ref.read(safeModeProvider)) return;
    bool current() =>
        identical(token, _invalidLeaseToken) &&
        _current(epoch, _intent, allowExpired: true);
    try {
      final owner = ref.read(proxiesActionProvider.notifier);
      await owner.updateGroups();
      for (final service in manifest.services) {
        if (!current()) return;
        if (!_automatic(service)) continue;
        final group = ref
            .read(groupsProvider)
            .getGroup(service.route.groupName);
        if (group?.realNow == 'REJECT') continue;
        final applied = await owner.changeAutomaticProxy(
          groupName: service.route.groupName,
          proxyName: 'REJECT',
          isCurrent: () => current() && _automatic(service),
        );
        if (!current()) return;
        await owner.updateGroups();
        if (_automatic(service) &&
            (!applied ||
                ref
                        .read(groupsProvider)
                        .getGroup(service.route.groupName)
                        ?.realNow !=
                    'REJECT')) {
          await ref.read(setupActionProvider.notifier).setRunning(false);
          return;
        }
      }
    } catch (_) {
      if (current()) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    }
  }

  void activate(int? profileId, String digest) {
    final plan = _preparedPlans[(profileId, digest)];
    if (plan == null ||
        profileId != plan.profileId ||
        !manages(plan.profileId) ||
        _session?.api.generation != plan.accountGeneration) {
      clear();
      return;
    }
    final configuration = ref
        .read(coreHandlerProvider)
        .configurationChanges
        .value;
    if (_active?.digest == plan.digest &&
        _active?.profileId == plan.profileId &&
        _active?.accountGeneration == plan.accountGeneration &&
        _active?.metadataIdentity == plan.metadataIdentity &&
        identical(configuration, _configuration)) {
      _active = plan;
      _leaseTimers();
      unawaited(_configureNative());
      return;
    }
    _revokeCoreLease();
    _active = plan;
    _nativeOwned = false;
    _configuration = configuration;
    _positions.clear();
    _engine = plan.engine ?? SmartRoutingEngine();
    _engine.resetGeneration(++_epoch);
    _providerHealth.resetGeneration(_epoch);
    _probeScope = Object();
    _leaseTimers();
    unawaited(_configureNative());
    _timer?.cancel();
    if (!ref.read(safeModeProvider) && plan.manifest != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => kick());
      kick();
    }
  }

  void _accountChanged() {
    final generation = _active?.accountGeneration ?? _staged?.accountGeneration;
    if (_session?.authenticated != true ||
        (generation != null && generation != _session?.api.generation)) {
      if (_nativeSupported) {
        unawaited(_nativeClient.logout().catchError((Object _) {}));
      }
      clear();
      if (!_disposed) {
        ref
            .read(zolnitBundleStatusProvider.notifier)
            .set(ZolnitBundleStatus.unloaded);
      }
    } else if (_active?.expiresAt != null &&
        const {
          'entitlement_unavailable',
          'invalid_client_bundle',
          'client_bundle_binding_mismatch',
        }.contains(_session?.clientBundleFailure)) {
      unawaited(
        _invalidateAutomatic(
          bundleFailureStatus(_session?.clientBundleFailure),
        ),
      );
    }
  }

  void suspend() {
    _revokeCoreLease();
    _epoch++;
    _providerHealth.resetGeneration(_epoch);
    _probeScope = Object();
    _active = null;
    _timer?.cancel();
    _timer = null;
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _invalidLeaseToken = null;
  }

  void clear() {
    _revokeCoreLease();
    _epoch++;
    _providerHealth.resetGeneration(_epoch);
    _probeScope = Object();
    _active = null;
    _staged = null;
    _preparedPlans.clear();
    _configuration = null;
    _positions.clear();
    _timer?.cancel();
    _timer = null;
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _invalidLeaseToken = null;
    _engine = SmartRoutingEngine()..resetGeneration(_epoch);
    _nativeOwned = false;
    _nativeGeneration = null;
    _nativeDigest = null;
    _nativePollTimer?.cancel();
    _nativeStaleTimer?.cancel();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _session?.removeListener(_accountChanged);
    _nativePollTimer?.cancel();
    _nativeStaleTimer?.cancel();
    if (_nativeSupported) {
      _nativeClient.removeListener(_nativeChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  Future<void> _configureNative() async {
    final plan = _active;
    if (!_nativeSupported ||
        _disposed ||
        _nativeConfiguring ||
        ref.read(safeModeProvider) ||
        plan?.accountId == null ||
        _nativeDigest == plan!.digest ||
        _session?.authenticated != true) {
      return;
    }
    _nativeConfiguring = true;
    _nativeDigest = plan.digest;
    _nativeGeneration = plan.accountGeneration;
    try {
      final authorization = await ref
          .read(zolnitSessionVaultProvider)
          .readAuthorization();
      if (authorization == null ||
          _disposed ||
          !identical(plan, _active) ||
          _session?.api.generation != plan.accountGeneration) {
        return;
      }
      final status = await _nativeClient.configure(
        accountId: plan.accountId!,
        accountGeneration: plan.accountGeneration,
        authorization: authorization,
        distribution: _session!.api.distribution ?? 'direct',
      );
      if (_disposed ||
          !identical(plan, _active) ||
          _session?.api.generation != plan.accountGeneration) {
        return;
      }
      _nativePollTimer?.cancel();
      if (status.sessionEpoch != null) {
        _nativePollTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => unawaited(_pollNative()),
        );
      }
      _nativeChanged();
    } catch (_) {
      if (!_disposed) _nativeChanged();
    } finally {
      _nativeConfiguring = false;
      if (!_disposed && _active != null && _active!.digest != _nativeDigest) {
        unawaited(_configureNative());
      }
    }
  }

  Future<void> _pollNative() async {
    if (_disposed || _nativePolling || _active == null) return;
    _nativePolling = true;
    try {
      await _nativeClient.poll();
    } catch (_) {
      if (!_disposed && _nativeOwned) _leaseReady(false);
    } finally {
      _nativePolling = false;
    }
  }

  void _nativeChanged() {
    if (_disposed ||
        _active == null ||
        _nativeGeneration != _session?.api.generation) {
      return;
    }
    final status = _nativeClient.snapshot;
    if (status.state == 'logged_out' && _session?.authenticated == true) {
      unawaited(_invalidateNativeSession());
      return;
    }
    if (status.ownsRenewal) {
      if (!_nativeOwned) {
        _nativeOwned = true;
        _epoch++;
        _providerHealth.resetGeneration(_epoch);
        _probeScope = Object();
        _timer?.cancel();
        _expiryTimer?.cancel();
        _refreshTimer?.cancel();
      }
      _leaseReady(status.ready);
      if (status.ready) {
        ref
            .read(zolnitBundleStatusProvider.notifier)
            .set(ZolnitBundleStatus.ready);
      }
      _nativeStaleTimer?.cancel();
      _nativeStaleTimer = Timer(const Duration(seconds: 5), () {
        if (!_disposed && _nativeOwned) _leaseReady(false);
      });
    } else if (_nativeOwned) {
      _nativeOwned = false;
      _leaseReady(false);
      _leaseTimers();
    }
  }

  Future<void> _invalidateNativeSession() async {
    final session = _session;
    if (session == null || !session.authenticated) return;
    final deletion = session.logout();
    try {
      if (!ref.read(safeModeProvider)) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
      await deletion;
    } catch (_) {
      if (!_disposed) _leaseReady(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        _disposed ||
        !_nativeSupported ||
        _resuming ||
        _session?.authenticated != true ||
        _active == null) {
      return;
    }
    unawaited(_resumeNativeMirror());
  }

  Future<void> _resumeNativeMirror() async {
    _resuming = true;
    final generation = _session?.api.generation;
    try {
      await _pollNative();
      await ref.read(zolnitSyncClientBundleProvider)();
      if (!_disposed &&
          _session?.authenticated == true &&
          generation == _session?.api.generation) {
        await ref
            .read(setupActionProvider.notifier)
            .applyProfile(silence: true);
      }
    } catch (_) {
    } finally {
      _resuming = false;
    }
  }

  void manualSelection(String group, String proxy) {
    final manifest = _active?.manifest;
    if (manifest == null) return;
    if (!manifest.services.any(
      (service) =>
          group == service.groupName ||
          group == service.manualGroup ||
          group == service.route.groupName,
    )) {
      _intent++;
      _providerHealth.resetGeneration(_epoch);
      _probeScope = Object();
      return;
    }
    for (final service in manifest.services) {
      if (group == service.manualGroup) {
        final selected = ref
            .read(currentProfileProvider)
            ?.selectedMap[service.groupName];
        final actual = ref
            .read(groupsProvider)
            .getGroup(service.groupName)
            ?.realNow;
        if (selected != service.manualGroup && actual != service.manualGroup) {
          continue;
        }
      }
      if (group != service.groupName &&
          group != service.manualGroup &&
          group != service.route.groupName) {
        continue;
      }
      _intent++;
      if (group == service.groupName && proxy == service.route.groupName) {
        _engine.resumeAutomatic(service.route.id);
      } else {
        _engine.setManual(
          serviceId: service.route.id,
          nodeId: proxy == 'DIRECT'
              ? 'DIRECT'
              : manifest.nodes
                    .where((n) => n.proxyName == proxy)
                    .firstOrNull
                    ?.id,
        );
      }
    }
  }

  bool _current(int epoch, int intent, {bool allowExpired = false}) {
    final plan = _active;
    return !_disposed &&
        !_nativeOwned &&
        plan != null &&
        epoch == _epoch &&
        intent == _intent &&
        _session?.authenticated == true &&
        _session?.api.generation == plan.accountGeneration &&
        (allowExpired ||
            plan.expiresAt == null ||
            (plan.expiresAt!.isAfter(_now) &&
                _invalidLeaseToken == null &&
                !_invalidatedLeases.containsKey(_leaseIdentity(plan)))) &&
        ref.read(currentProfileIdProvider) == plan.profileId &&
        manages(plan.profileId) &&
        !ref.read(safeModeProvider) &&
        ref.read(coreStatusProvider) == CoreStatus.connected &&
        !ref.read(coreHandlerProvider).isApplyingConfiguration &&
        ref.read(patchClashConfigProvider).mode == Mode.rule &&
        identical(
          ref.read(coreHandlerProvider).configurationChanges.value,
          _configuration,
        );
  }

  bool _automatic(ManagedRouteService service) {
    final groups = ref.read(groupsProvider);
    final policy = groups.getGroup(service.groupName);
    final automatic = groups.getGroup(service.route.groupName);
    final selected = ref
        .read(currentProfileProvider)
        ?.selectedMap[service.groupName];
    return policy?.type == GroupType.Selector &&
        automatic?.type == GroupType.Selector &&
        policy?.realNow == service.route.groupName &&
        (selected == null || selected == service.route.groupName);
  }

  void kick() {
    if (_nativeOwned || _busy || _disposed || _active?.manifest == null) return;
    unawaited(run());
  }

  bool _probeDemand() {
    final traffic = ref.read(totalTrafficProvider);
    final total = traffic.up + traffic.down;
    final changed = _previousTraffic != null && total > _previousTraffic!;
    _previousTraffic = total;
    return ref.read(appVisibleProvider) || changed;
  }

  String _semantics(ManagedRouteService service) =>
      'http-transport-v2:${service.route.isAi}:${(service.route.allowedCountries.toList()..sort()).join(',')}:${(service.providers.toList()..sort()).join(',')}';

  Future<void> run() async {
    if (_nativeOwned) return;
    if (_active?.expiresAt != null && !_active!.expiresAt!.isAfter(_now)) {
      await _invalidateAutomatic(ZolnitBundleStatus.expired);
      return;
    }
    if (_active?.expiresAt != null &&
        !ref.read(zolnitClientBundleAutomaticProvider)) {
      return;
    }
    if (_busy) {
      await _cycleDone?.future;
      return;
    }
    final manifest = _active?.manifest;
    final epoch = _epoch;
    final intent = _intent;
    if (manifest == null || !_current(epoch, intent)) return;
    _busy = true;
    _cycleDone = Completer<void>();
    var completedProbeCycle = false;
    var usableObservation = false;
    var attemptedObservation = false;
    try {
      Map<String, dynamic>? guard;
      if (_active!.expiresAt != null) {
        guard = await ref.read(coreHandlerProvider).getRoutingLease();
        if (!_current(epoch, intent) || !_matchesCoreLease(guard, _active!)) {
          _leaseReady(false);
          return;
        }
        _coreLease = Map<String, dynamic>.unmodifiable(guard!);
        _leaseReady(true);
      }
      final owner = ref.read(proxiesActionProvider.notifier);
      await owner.updateGroups();
      final activeDemand = _probeDemand();
      final probeAllowed =
          manifest.services.any(
            (service) =>
                _automatic(service) &&
                _engine.candidates(service.route.id).isNotEmpty,
          ) &&
          _probeScheduler.beginCycle(activeDemand: activeDemand);
      completedProbeCycle = probeAllowed;
      final start = manifest.services.isEmpty
          ? 0
          : _servicePosition++ % manifest.services.length;
      for (
        var serviceIndex = 0;
        serviceIndex < manifest.services.length;
        serviceIndex++
      ) {
        final service = manifest
            .services[(start + serviceIndex) % manifest.services.length];
        if (!_current(epoch, intent)) return;
        if (!_automatic(service)) continue;
        final id = service.route.id;
        final group = ref
            .read(groupsProvider)
            .getGroup(service.route.groupName)!;
        final memberNames = group.all
            .where((proxy) => isSmartRoutingProxyType(proxy.type))
            .map((proxy) => proxy.name)
            .toSet();
        final candidates = _engine
            .candidates(id)
            .where((node) => memberNames.contains(node.proxyName))
            .toList();
        final current = candidates
            .where((node) => node.proxyName == group.realNow)
            .firstOrNull;
        if (current != null) {
          _engine.confirm(
            serviceId: id,
            nodeId: current.id,
            now: _now,
            generation: epoch,
          );
        }
        final semantics = _semantics(service);
        final probes = <SmartRouteNode>{};
        if (current != null) probes.add(current);
        if (candidates.isNotEmpty) {
          var offset = (_positions[id] ?? 0) % candidates.length;
          final targetCount = activeDemand ? 2 : 1;
          for (
            var attempted = 0;
            attempted < candidates.length && probes.length < targetCount;
            attempted++
          ) {
            probes.add(candidates[offset]);
            offset = (offset + 1) % candidates.length;
          }
          _positions[id] = offset;
        }
        if (probeAllowed) {
          final scope = (_probeScope, intent);
          await Future.wait(
            probes.map((node) async {
              if (_engine.nextProbeAt(id, node.id)?.isAfter(_now) == true) {
                return;
              }
              for (final provider in service.providers) {
                if (!_current(epoch, intent)) return;
                final url = routingProviderProbeUrls[provider]!;
                final observation = await _probeScheduler.request(
                  scope: scope,
                  nodeId: '${node.id}:${node.proxyName}',
                  provider: provider,
                  semantics: semantics,
                  isCurrent: () => _current(epoch, intent),
                  send: () async {
                    final result = await ref
                        .read(coreHandlerProvider)
                        .probe(
                          ProbeParams(
                            automaticRouting: true,
                            url: url,
                            proxyName: node.proxyName,
                            timeout: 5000,
                            maxBody: 4096,
                            followRedirects: false,
                          ),
                        );
                    if (result == null || result.url != url) return null;
                    return RoutingProbeReply(
                      statusCode: result.statusCode,
                      latencyMs: result.delay,
                      body: result.body,
                      error: result.error ?? '',
                      retryAfter: result.retryAfter ?? '',
                    );
                  },
                );
                if (!_current(epoch, intent)) return;
                if (observation == null) continue;
                attemptedObservation = true;
                usableObservation =
                    usableObservation ||
                    observation.health.usableTransportSample;
                _providerHealth.observe(
                  generation: epoch,
                  nodeId: node.id,
                  provider: provider,
                  sequence: observation.sequence,
                  observedAt: observation.observedAt,
                  health: observation.health,
                  semantics: semantics,
                );
              }
              if (!_current(epoch, intent)) return;
              final evidence = _providerHealth.assess(
                nodeId: node.id,
                providers: service.providers,
                now: _now,
                semantics: semantics,
              );
              if (!evidence.usableTransportSample &&
                  !evidence.transportFailure) {
                return;
              }
              _engine.observe(
                serviceId: id,
                nodeId: node.id,
                generation: epoch,
                sample: SmartProbeSample(
                  at: evidence.observedAt!,
                  success: evidence.usableTransportSample,
                  validUntil: evidence.usableTransportSample
                      ? evidence.validUntil
                      : null,
                  latencyMs: evidence.latencyMs?.toDouble(),
                ),
              );
            }),
          );
        }
        if (!_current(epoch, intent)) return;
        await owner.updateGroups();
        if (!_current(epoch, intent) || !_automatic(service)) continue;
        final refreshed = ref
            .read(groupsProvider)
            .getGroup(service.route.groupName);
        final liveMembers =
            refreshed?.all
                .where((proxy) => isSmartRoutingProxyType(proxy.type))
                .map((proxy) => proxy.name)
                .toSet() ??
            const <String>{};
        final decision = _engine.decide(
          serviceId: id,
          now: _now,
          qualifiedCurrentNodeId: candidates
              .where((node) => node.proxyName == refreshed?.realNow)
              .firstOrNull
              ?.id,
          availableNodeIds: {
            for (final node in candidates)
              if (liveMembers.contains(node.proxyName) &&
                  _providerHealth
                      .assess(
                        nodeId: node.id,
                        providers: service.providers,
                        now: _now,
                        semantics: semantics,
                      )
                      .usableTransportSample)
                node.id,
          },
        );
        if (decision.manual) continue;
        final node = manifest.nodes
            .where((node) => node.id == decision.nodeId)
            .firstOrNull;
        final proxy = node?.proxyName ?? 'REJECT';
        if (refreshed?.all.any((p) => p.name == proxy) != true ||
            refreshed?.realNow == proxy) {
          continue;
        }
        final applied = await owner.changeAutomaticProxy(
          groupName: service.route.groupName,
          proxyName: proxy,
          routingLease: guard,
          isCurrent: () => _current(epoch, intent) && _automatic(service),
        );
        if (!applied || !_current(epoch, intent)) continue;
        await owner.updateGroups();
        if (_current(epoch, intent) &&
            ref
                    .read(groupsProvider)
                    .getGroup(service.route.groupName)
                    ?.realNow ==
                proxy) {
          _engine.confirm(
            serviceId: id,
            nodeId: node?.id,
            now: _now,
            generation: epoch,
          );
        }
      }
    } catch (error) {
      if (!_disposed) {
        commonPrint.log(
          'Smart routing cycle stopped: ${error.runtimeType}',
          logLevel: LogLevel.warning,
        );
      }
    } finally {
      if (completedProbeCycle) {
        _probeScheduler.finishCycle(
          usableObservation: usableObservation,
          attemptedObservation: attemptedObservation,
        );
      }
      _busy = false;
      _cycleDone?.complete();
      _cycleDone = null;
    }
  }
}
