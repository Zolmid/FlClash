import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

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

typedef _RoutingPlan = ({
  int profileId,
  int accountGeneration,
  String digest,
  SmartRoutingManifest? manifest,
  SmartRoutingEngine? engine,
  DateTime? expiresAt,
  String? metadataIdentity,
});

class ZolnitRouting {
  ZolnitRouting(this.ref);

  final Ref ref;
  var _engine = SmartRoutingEngine();
  final _pool = TaskPool(4);
  final _positions = <String, int>{};
  ZolnitSessionController? _session;
  _RoutingPlan? _staged;
  final _preparedPlans = <(int, String), _RoutingPlan>{};
  _RoutingPlan? _active;
  Object? _configuration;
  Timer? _timer;
  Timer? _expiryTimer;
  Timer? _refreshTimer;
  Object? _invalidLeaseToken;
  bool _refreshing = false;
  var _epoch = 0;
  var _intent = 0;
  var _busy = false;
  Completer<void>? _cycleDone;
  var _disposed = false;

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
  }) {
    if (!manages(profileId)) return;
    final session = ref.read(zolnitSessionProvider);
    if (session.api.generation != accountGeneration) return;
    if (!identical(_session, session)) {
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

  bool acceptsPrepared(int profileId, String digest) {
    final plan = _preparedPlans[(profileId, digest)];
    return plan != null &&
        plan.profileId == profileId &&
        plan.digest == digest &&
        _session?.authenticated == true &&
        _session?.api.generation == plan.accountGeneration &&
        ref.read(currentProfileIdProvider) == profileId &&
        manages(profileId);
  }

  DateTime get _now => ref.read(zolnitBundleClockProvider)();

  void _leaseTimers() {
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    final expiry = _active?.expiresAt;
    if (expiry == null) return;
    _invalidLeaseToken = null;
    final remaining = expiry.difference(_now);
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      unawaited(_invalidateAutomatic(ZolnitBundleStatus.expired));
    });
    if (!ref.read(safeModeProvider)) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        unawaited(refreshBundle());
      });
    }
  }

  Future<void> refreshBundle() async {
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
          bundleFailureStatus(_session?.clientBundleFailure),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _invalidateAutomatic(ZolnitBundleStatus status) async {
    if (_disposed || _active?.expiresAt == null || _invalidLeaseToken != null) {
      return;
    }
    final token = Object();
    _invalidLeaseToken = token;
    _engine.resetGeneration(++_epoch);
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
      return;
    }
    _active = plan;
    _configuration = configuration;
    _positions.clear();
    _engine = plan.engine ?? SmartRoutingEngine();
    _engine.resetGeneration(++_epoch);
    _leaseTimers();
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
    _epoch++;
    _active = null;
    _timer?.cancel();
    _timer = null;
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _invalidLeaseToken = null;
  }

  void clear() {
    _epoch++;
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
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();
    _session?.removeListener(_accountChanged);
  }

  void manualSelection(String group, String proxy) {
    final manifest = _active?.manifest;
    if (manifest == null) return;
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
        plan != null &&
        epoch == _epoch &&
        intent == _intent &&
        _session?.authenticated == true &&
        _session?.api.generation == plan.accountGeneration &&
        (allowExpired ||
            plan.expiresAt == null ||
            (plan.expiresAt!.isAfter(_now) && _invalidLeaseToken == null)) &&
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
    if (_busy || _disposed || _active?.manifest == null) return;
    unawaited(run());
  }

  Future<void> run() async {
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
    try {
      final owner = ref.read(proxiesActionProvider.notifier);
      await owner.updateGroups();
      for (final service in manifest.services) {
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
        final probes = <SmartRouteNode>{};
        if (current != null) probes.add(current);
        if (candidates.isNotEmpty) {
          final offset = (_positions[id] ?? 0) % candidates.length;
          for (var i = 0; i < math.min(8, candidates.length); i++) {
            probes.add(candidates[(offset + i) % candidates.length]);
          }
          _positions[id] = (offset + 8) % candidates.length;
        }
        await Future.wait(
          probes.map(
            (node) => _pool.run(() async {
              if (!_current(epoch, intent)) return;
              final now = _now;
              if (_engine.nextProbeAt(id, node.id)?.isAfter(now) == true) {
                return;
              }
              final latencies = <int>[];
              var failed = false;
              for (final url in service.probeUrls) {
                if (!_current(epoch, intent)) return;
                final delay = await ref
                    .read(coreHandlerProvider)
                    .getDelay(url, node.proxyName);
                if (!_current(epoch, intent)) return;
                // No Core reply is a channel failure, not a node measurement.
                if (delay?.value == null) return;
                if (delay!.value! < 0) {
                  failed = true;
                } else {
                  latencies.add(delay.value!);
                }
              }
              _engine.observe(
                serviceId: id,
                nodeId: node.id,
                generation: epoch,
                sample: SmartProbeSample(
                  at: _now,
                  success: !failed,
                  latencyMs: failed
                      ? null
                      : latencies.reduce(math.max).toDouble(),
                ),
              );
            }),
          ),
        );
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
          availableNodeIds: {
            for (final node in candidates)
              if (liveMembers.contains(node.proxyName)) node.id,
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
      _busy = false;
      _cycleDone?.complete();
      _cycleDone = null;
    }
  }
}
