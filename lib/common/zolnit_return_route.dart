import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/common/zolnit_routing.dart'
    show isSmartRoutingProxyType;
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
  const ZolnitReturnRoute._(
    this.group,
    this.options,
    this.selectedId,
    this.dispatches,
    this.active,
  );

  final String group;
  final List<ZolnitReturnRouteOption> options;
  final String? selectedId;
  final List<ZolnitReturnDispatch> dispatches;
  final bool active;

  bool get activationAvailable => dispatches.length == 2;

  static const optionIds = {'direct', 'hk_lite', 'hk_optimized'};
  static final _controls = RegExp(r'[\x00-\x1f\x7f]');

  static bool _safe(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 256 &&
      value.trim() == value &&
      !_controls.hasMatch(value) &&
      !{'DIRECT', 'REJECT'}.contains(value.toUpperCase()) &&
      !value.toLowerCase().startsWith('zn.service.') &&
      !value.toLowerCase().startsWith('clientzn.service.');

  static final _cache = Expando<_ReturnRouteResolution>();

  static Json? corePolicy(ZolnitClientBundle bundle) {
    final raw = bundle.routingJson['ui_groups'];
    if (raw is! List || raw.length > 16) return null;
    final matches = raw.whereType<Map>().where(
      (entry) => entry['id'] == 'return_route',
    );
    if (matches.length != 1) return null;
    final role = matches.single;
    if (!_safe(role['group'])) {
      return null;
    }
    final rawOptions = role['options'];
    if (rawOptions is! List || rawOptions.length != optionIds.length) {
      return null;
    }
    final ids = <String>{};
    final targets = <String>{};
    final options = <Json>[];
    for (final item in rawOptions) {
      if (item is! Map ||
          !optionIds.contains(item['id']) ||
          !ids.add(item['id'] as String) ||
          !_safe(item['target']) ||
          item['target'] == role['group'] ||
          !targets.add(item['target'] as String)) {
        return null;
      }
      options.add({'id': item['id'], 'target': item['target']});
    }
    final order = optionIds.toList();
    options.sort(
      (a, b) => order
          .indexOf(a['id'] as String)
          .compareTo(order.indexOf(b['id'] as String)),
    );
    return {
      'groupName': role['group'],
      'options': options,
      'outbounds': bundle.outbounds
          .map((outbound) => outbound.proxyName)
          .toList(),
      'dispatches': ?_dispatchPolicy(raw, role['group'] as String),
    };
  }

  static List<Json>? _dispatchPolicy(List raw, String returnGroup) {
    const ids = {'return_dispatch', 'return_media_dispatch'};
    final roles = raw.whereType<Map>().where((r) => ids.contains(r['id']));
    if (roles.length != 2) return null;
    final found = <String>{};
    final groups = <String>{returnGroup};
    final result = <Json>[];
    for (final role in roles) {
      if (!found.add(role['id'] as String) ||
          !_safe(role['group']) ||
          !groups.add(role['group'] as String)) {
        return null;
      }
      final options = role['options'];
      if (options is! List || options.length != 2) return null;
      final targets = <String, String>{};
      for (final option in options) {
        if (option is! Map ||
            !{'local', 'return'}.contains(option['id']) ||
            targets.containsKey(option['id']) ||
            !_safe(option['target'])) {
          return null;
        }
        targets[option['id'] as String] = option['target'] as String;
      }
      if (targets['return'] != returnGroup ||
          targets['local'] == returnGroup ||
          targets['local'] == role['group']) {
        return null;
      }
      result.add({
        'id': role['id'],
        'groupName': role['group'],
        'localTarget': targets['local'],
        'returnTarget': returnGroup,
      });
    }
    if (result.any((d) => groups.contains(d['localTarget']))) return null;
    result.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return result;
  }

  static ZolnitReturnRoute? resolve(
    ZolnitClientBundle bundle,
    List<Group> groups,
  ) {
    final cached = _cache[groups];
    if (cached != null && identical(cached.bundle, bundle)) return cached.route;
    final route = _resolve(bundle, groups);
    _cache[groups] = _ReturnRouteResolution(bundle, route);
    return route;
  }

  static ZolnitReturnRoute? _resolve(
    ZolnitClientBundle bundle,
    List<Group> groups,
  ) {
    final policy = corePolicy(bundle);
    if (policy == null) return null;
    final groupName = policy['groupName'] as String;
    final group = groups.getGroup(groupName);
    if (group?.type != GroupType.Selector) return null;
    final delivered = (policy['outbounds'] as List).cast<String>().toSet();
    bool reachable(Proxy start) {
      final seen = <String>{groupName};
      final pending = <Proxy>[start];
      while (pending.isNotEmpty) {
        final proxy = pending.removeLast();
        if (!seen.add(proxy.name) || !_safe(proxy.name)) {
          continue;
        }
        final nested = groups.getGroup(proxy.name);
        if (nested != null) {
          pending.addAll(nested.all);
        } else if (delivered.contains(proxy.name) &&
            isSmartRoutingProxyType(proxy.type)) {
          return true;
        }
      }
      return false;
    }

    final options = <ZolnitReturnRouteOption>[];
    for (final item in (policy['options'] as List).cast<Json>()) {
      final target = item['target'] as String;
      final members = group!.all.where((proxy) => proxy.name == target);
      if (members.length != 1 ||
          {'direct', 'reject'}.contains(members.single.type.toLowerCase()) ||
          (groups.getGroup(target) == null && !delivered.contains(target))) {
        return null;
      }
      if (reachable(members.single)) {
        options.add(ZolnitReturnRouteOption(item['id'] as String, target));
      }
    }
    final dispatches = <ZolnitReturnDispatch>[];
    bool localOnly(String start) {
      final visited = <String, int>{};
      final pending = [(start, false)];
      while (pending.isNotEmpty) {
        final (name, leaving) = pending.removeLast();
        if (leaving) {
          visited[name] = 2;
          continue;
        }
        if (visited[name] == 1) return false;
        if (visited[name] == 2) continue;
        final local = groups.getGroup(name);
        if (local?.type != GroupType.Selector || local!.all.isEmpty) {
          return false;
        }
        visited[name] = 1;
        pending.add((name, true));
        for (final proxy in local.all) {
          if (proxy.name == 'DIRECT') {
            if (proxy.type.toLowerCase() != 'direct') return false;
          } else {
            pending.add((proxy.name, false));
          }
        }
      }
      return true;
    }

    for (final binding in (policy['dispatches'] as List? ?? const [])) {
      final parent = groups.getGroup(binding['groupName'] as String);
      final local = binding['localTarget'] as String;
      if (parent?.type != GroupType.Selector ||
          !localOnly(local) ||
          [local, groupName].any(
            (target) => parent!.all.where((p) => p.name == target).length != 1,
          ) ||
          parent!.all
              .where((p) => p.name == local || p.name == groupName)
              .any((p) => p.type.toLowerCase() != 'selector')) {
        dispatches.clear();
        break;
      }
      dispatches.add(
        ZolnitReturnDispatch(
          binding['id'] as String,
          parent.name,
          local,
          groupName,
        ),
      );
    }
    if (options.isEmpty && dispatches.length != 2) return null;
    return ZolnitReturnRoute._(
      groupName,
      List.unmodifiable(options),
      options
          .where((option) => option.target == group!.realNow)
          .firstOrNull
          ?.id,
      List.unmodifiable(dispatches),
      dispatches.length == 2 &&
          dispatches.every(
            (d) => groups.getGroup(d.groupName)?.realNow == d.returnTarget,
          ),
    );
  }
}

class ZolnitReturnDispatch {
  const ZolnitReturnDispatch(
    this.id,
    this.groupName,
    this.localTarget,
    this.returnTarget,
  );

  final String id;
  final String groupName;
  final String localTarget;
  final String returnTarget;
}

class _ReturnRouteResolution {
  const _ReturnRouteResolution(this.bundle, this.route);
  final ZolnitClientBundle bundle;
  final ZolnitReturnRoute? route;
}
