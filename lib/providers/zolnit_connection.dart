import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:zolnit_client/zolnit_client.dart';

enum ZolnitConnectionPhase { disconnected, connecting, connected, unavailable }

class _ZolnitSessionRevision extends Notifier<int> {
  ZolnitSessionController? _session;

  @override
  int build() {
    final session = ref.watch(zolnitSessionProvider);
    if (!identical(session, _session)) {
      _session?.removeListener(_changed);
      _session = session;
      session.addListener(_changed);
    }
    ref.onDispose(() => _session?.removeListener(_changed));
    return 0;
  }

  void _changed() => state++;
}

final _zolnitSessionRevisionProvider =
    NotifierProvider<_ZolnitSessionRevision, int>(_ZolnitSessionRevision.new);

final _connectionBundleProvider = Provider<ZolnitClientBundle?>((ref) {
  ref.watch(_zolnitSessionRevisionProvider);
  final session = ref.watch(zolnitSessionProvider);
  final id = ref.watch(currentProfileProvider.select((p) => p?.zolnitBundleId));
  final activity = ref.watch(zolnitBundleActivityProvider);
  final retained = activity.retained;
  if (activity.refreshing &&
      session.authenticated &&
      activity.generation == session.api.generation &&
      retained?.bundleId == id &&
      retained?.accountId == session.clientBundleAccountId &&
      retained?.isFresh(ref.read(zolnitBundleClockProvider)()) == true) {
    return retained;
  }
  return session.clientBundle;
});

final zolnitStoredBundleProvider = FutureProvider<bool>((ref) async {
  ref.watch(isStartProvider);
  final identity = ref.watch(
    currentProfileProvider.select(
      (profile) => profile == null
          ? null
          : (
              profile.id,
              profile.zolnitAccountId,
              profile.zolnitBundleId,
              profile.zolnitOrigin,
            ),
    ),
  );
  final profile = ref.read(currentProfileProvider);
  final session = ref.watch(zolnitSessionProvider);
  ref.watch(_connectionBundleProvider.select((bundle) => bundle?.bundleId));
  final bundle = ref.read(_connectionBundleProvider);
  if (identity == null ||
      profile == null ||
      !isCurrentZolnitBundleProfile(profile, session) ||
      profile.zolnitBundleId != bundle?.bundleId) {
    return false;
  }
  final stored = await readZolnitClientBundle(
    profile,
    ref.read(zolnitBundleClockProvider)(),
  );
  return stored.bundleId == bundle?.bundleId;
});

bool zolnitConnectionConfigReady(
  T Function<T>(ProviderListenable<T> provider) read,
) {
  read(_zolnitSessionRevisionProvider);
  final profile = read(currentProfileProvider);
  if (profile == null) return false;
  if (!isZolnitBundleProfile(profile)) return true;
  final session = read(zolnitSessionProvider);
  final bundle = read(_connectionBundleProvider);
  return session.authenticated &&
      read(zolnitBundleStatusProvider) == ZolnitBundleStatus.ready &&
      bundle != null &&
      bundle.isFresh(read(zolnitBundleClockProvider)()) &&
      isCurrentZolnitBundleProfile(profile, session) &&
      profile.zolnitBundleId == bundle.bundleId;
}

final zolnitConnectionPhaseProvider = Provider<ZolnitConnectionPhase>((ref) {
  ref.watch(_zolnitSessionRevisionProvider);
  final profile = ref.watch(currentProfileProvider);
  if (profile == null || !isZolnitBundleProfile(profile)) {
    return ZolnitConnectionPhase.disconnected;
  }

  if (!ref.watch(zolnitSessionProvider).authenticated) {
    return ZolnitConnectionPhase.unavailable;
  }
  if (!ref.watch(isStartProvider)) return ZolnitConnectionPhase.disconnected;
  if (!zolnitConnectionConfigReady(ref.watch)) {
    return ref.watch(zolnitBundleStatusProvider) == ZolnitBundleStatus.loading
        ? ZolnitConnectionPhase.connecting
        : ZolnitConnectionPhase.unavailable;
  }

  final storedBundle = ref.watch(zolnitStoredBundleProvider);
  if (storedBundle.hasError) {
    return ZolnitConnectionPhase.unavailable;
  }
  if (storedBundle.isLoading || storedBundle.isRefreshing) {
    return ZolnitConnectionPhase.connecting;
  }
  if (!storedBundle.hasValue || storedBundle.value != true) {
    return ZolnitConnectionPhase.unavailable;
  }

  switch (ref.watch(coreStatusProvider)) {
    case CoreStatus.disconnected:
      return ZolnitConnectionPhase.disconnected;
    case CoreStatus.connecting:
      return ZolnitConnectionPhase.connecting;
    case CoreStatus.connected:
      break;
  }

  switch (ref.watch(tunnelStateProvider)) {
    case null:
    case TunnelState.connected:
      return ZolnitConnectionPhase.connected;
    case TunnelState.pending:
      return ZolnitConnectionPhase.connecting;
    case TunnelState.disconnected:
      return ZolnitConnectionPhase.unavailable;
  }
});
