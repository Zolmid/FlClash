import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:zolnit_client/zolnit_client.dart';

class ZolnitReturnRouteOption {
  const ZolnitReturnRouteOption(this.id, this.target);

  final String id;
  final String target;

  String label(AppLocalizations text) => switch (id) {
    'direct' => text.zolnitReturnDirect,
    'hk_lite' => text.zolnitReturnHkLite,
    'hk_optimized' => text.zolnitReturnHkOptimized,
    _ => text.unknown,
  };
}

class ZolnitReturnRoute {
  const ZolnitReturnRoute._(this.group, this.options, this.selectedId);

  final String group;
  final List<ZolnitReturnRouteOption> options;
  final String? selectedId;

  static const optionIds = {'direct', 'hk_lite', 'hk_optimized'};
  static final _controls = RegExp(r'[\x00-\x1f\x7f]');

  static bool _safe(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 256 &&
      value.trim() == value &&
      !_controls.hasMatch(value) &&
      !{'DIRECT', 'REJECT'}.contains(value.toUpperCase()) &&
      !value.startsWith('zn.service.');

  static ZolnitReturnRoute? resolve(
    ZolnitClientBundle bundle,
    List<Group> groups,
  ) {
    final raw = bundle.routingJson['ui_groups'];
    if (raw is! List || raw.length > 16) return null;
    final matches = raw.whereType<Map>().where(
      (entry) => entry['id'] == 'return_route',
    );
    if (matches.length != 1) return null;
    final role = matches.single;
    final groupName = role['group'];
    if (!_safe(groupName)) return null;
    final group = groups.getGroup(groupName as String);
    if (group?.type != GroupType.Selector) return null;
    final rawOptions = role['options'];
    if (rawOptions is! List || rawOptions.length != optionIds.length) {
      return null;
    }
    final options = <ZolnitReturnRouteOption>[];
    final ids = <String>{};
    final targets = <String>{};
    for (final item in rawOptions) {
      if (item is! Map ||
          !optionIds.contains(item['id']) ||
          !ids.add(item['id'] as String) ||
          !_safe(item['target'])) {
        return null;
      }
      final target = item['target'] as String;
      final member = group!.all.where((proxy) => proxy.name == target);
      if (target == groupName ||
          !targets.add(target) ||
          member.length != 1 ||
          {'direct', 'reject'}.contains(member.single.type.toLowerCase()) ||
          (groups.getGroup(target) == null &&
              !bundle.outbounds.any(
                (outbound) => outbound.proxyName == target,
              ))) {
        return null;
      }
      options.add(ZolnitReturnRouteOption(item['id'] as String, target));
    }
    options.sort(
      (a, b) => optionIds
          .toList()
          .indexOf(a.id)
          .compareTo(optionIds.toList().indexOf(b.id)),
    );
    return ZolnitReturnRoute._(
      groupName,
      List.unmodifiable(options),
      options
          .where((option) => option.target == group!.realNow)
          .firstOrNull
          ?.id,
    );
  }
}
