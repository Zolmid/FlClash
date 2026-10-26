import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

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
) async {
  final generation = session.api.generation;
  final profile = ref.read(currentProfileProvider);
  final bundle = session.clientBundle;
  ZolnitReturnRoute? read() => currentZolnitReturnRoute(
    session,
    ref.read(currentProfileProvider),
    ref.read(groupsProvider),
  );
  final route = read();
  final option = route?.options
      .where((item) => item.id == optionId)
      .firstOrNull;
  if (route == null || option == null) return false;
  bool current() {
    if (!ref.context.mounted ||
        !ref.read(zolnitClientBundleTransportProvider) ||
        ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected ||
        !session.authenticated ||
        session.api.generation != generation ||
        !identical(session.clientBundle, bundle) ||
        ref.read(currentProfileProvider)?.id != profile?.id) {
      return false;
    }
    final latest = read();
    return latest?.group == route.group &&
        latest!.options.any(
          (item) => item.id == optionId && item.target == option.target,
        );
  }

  if (!current()) return false;
  Map<String, dynamic> guard;
  try {
    final context = await ref.read(coreHandlerProvider).getClientBundleOwner();
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
    guard = raw;
  } catch (_) {
    return false;
  }
  return ref
      .read(proxiesActionProvider.notifier)
      .changeProxyIfCurrent(
        groupName: route.group,
        proxyName: option.target,
        isCurrent: current,
        routingLease: guard,
      );
}
