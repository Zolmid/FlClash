import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

class _ReturnActions {
  int revision = 0;
  Future<void> tail = Future<void>.value();
}

final _returnActionsProvider = Provider<_ReturnActions>((ref) {
  final actions = _ReturnActions();
  ref.onDispose(() => actions.revision++);
  return actions;
});

ZolnitReturnRoute? currentZolnitReturnRoute(
  ZolnitSessionController session,
  Profile? profile,
  List<Group> groups,
) {
  final bundle = session.clientBundle;
  if (bundle == null ||
      profile == null ||
      !isCurrentZolnitBundleProfile(profile, session) ||
      profile.zolnitBundleId != bundle.bundleId) {
    return null;
  }
  return ZolnitReturnRoute.resolve(bundle, groups);
}

Future<bool> selectZolnitReturnRoute(
  WidgetRef ref,
  ZolnitSessionController session,
  String optionId,
) {
  final route = currentZolnitReturnRoute(
    session,
    ref.read(currentProfileProvider),
    ref.read(groupsProvider),
  );
  if (route?.active != true) return Future.value(false);
  return setZolnitReturnRouting(ref, session, true, optionId: optionId);
}

Future<bool> setZolnitReturnRouting(
  WidgetRef ref,
  ZolnitSessionController session,
  bool enabled, {
  String? optionId,
}) {
  final generation = session.api.generation;
  final profile = ref.read(currentProfileProvider);
  final bundle = session.clientBundle;
  ZolnitReturnRoute? read() => currentZolnitReturnRoute(
    session,
    ref.read(currentProfileProvider),
    ref.read(groupsProvider),
  );
  final route = read();
  if (route == null || !route.activationAvailable) return Future.value(false);
  final selectedId =
      optionId ?? route.selectedId ?? route.options.firstOrNull?.id;
  final option = route.options
      .where((item) => item.id == selectedId)
      .firstOrNull;
  if (enabled && option == null) return Future.value(false);
  final actions = ref.read(_returnActionsProvider);
  final revision = ++actions.revision;
  bool current() {
    if (!ref.context.mounted ||
        !ref.read(zolnitClientBundleTransportProvider) ||
        ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected ||
        !session.authenticated ||
        actions.revision != revision ||
        session.api.generation != generation ||
        !identical(session.clientBundle, bundle) ||
        bundle?.isFresh(ref.read(zolnitBundleClockProvider)()) != true ||
        ref.read(currentProfileProvider)?.id != profile?.id) {
      return false;
    }
    final latest = read();
    return latest?.group == route.group &&
        latest!.activationAvailable &&
        latest.dispatches.every(
          (d) => route.dispatches.any(
            (before) =>
                d.id == before.id &&
                d.groupName == before.groupName &&
                d.localTarget == before.localTarget &&
                d.returnTarget == before.returnTarget,
          ),
        ) &&
        (!enabled ||
            latest.options.any(
              (item) => item.id == selectedId && item.target == option!.target,
            ));
  }

  final operation = actions.tail.then((_) async {
    if (!current()) return false;
    try {
      final context = await ref
          .read(coreHandlerProvider)
          .getClientBundleOwner();
      final raw = context?['returnRouteGuard'];
      if (!current() ||
          raw is! Map<String, dynamic> ||
          raw['accountId'] != bundle?.accountId ||
          raw['accountGeneration'] != generation ||
          raw['bundleId'] != bundle?.bundleId ||
          raw['instanceId'] is! String ||
          (raw['instanceId'] as String).isEmpty ||
          raw['token'] is! String ||
          (raw['token'] as String).isEmpty ||
          raw['configurationGeneration'] is! int) {
        return false;
      }
      final result = await ref.read(coreHandlerProvider).setClientReturnRoute({
        'routingLease': raw,
        'enabled': enabled,
        if (enabled) 'optionId': selectedId,
      });
      if (!current() || result?['enabled'] != enabled) return false;
      final selections = result?['selections'];
      if (selections is! Map<String, dynamic>) return false;
      final expected = <String, String>{
        for (final d in route.dispatches)
          d.groupName: enabled ? d.returnTarget : d.localTarget,
        if (enabled) route.group: option!.target,
      };
      if (expected.entries.any((e) => selections[e.key] != e.value) ||
          selections.entries.any(
            (e) =>
                e.value is! String ||
                (expected[e.key] != e.value &&
                    (e.key != route.group ||
                        !route.options.any((o) => o.target == e.value))),
          ) ||
          (enabled && result?['selectedId'] != selectedId)) {
        return false;
      }
      final latestProfile = ref.read(currentProfileProvider)!;
      ref
          .read(profilesProvider.notifier)
          .put(
            latestProfile.copyWith(
              selectedMap: {
                ...latestProfile.selectedMap,
                ...selections.cast<String, String>(),
              },
            ),
          );
      await ref.read(proxiesActionProvider.notifier).updateGroups();
      return current();
    } catch (_) {
      return false;
    }
  });
  actions.tail = operation.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return operation;
}
