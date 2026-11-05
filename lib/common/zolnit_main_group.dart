import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:zolnit_client/zolnit_client.dart';

Group? zolnitMainGroup(
  ZolnitClientBundle bundle,
  Iterable<Group> groups,
  Mode mode,
) {
  final allowed = bundle.outbounds.map((node) => node.proxyName).toSet();
  final managed = {
    for (final service in bundle.routingManifest.services) ...[
      service.groupName,
      service.route.groupName,
      service.manualGroup,
    ],
  };
  Group? best;
  var count = 0;
  for (final group in groups) {
    if (group.type != GroupType.Selector) continue;
    if (mode == Mode.global) {
      if (group.name == GroupName.GLOBAL.name) return group;
      continue;
    }
    if (group.name == GroupName.GLOBAL.name || managed.contains(group.name)) {
      continue;
    }
    final matches = group.all
        .where((proxy) => allowed.contains(proxy.name))
        .length;
    if (matches > count) {
      best = group;
      count = matches;
    }
  }
  return best;
}
