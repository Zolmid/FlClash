import 'package:fl_clash/common/yaml.dart';
import 'package:fl_clash/common/zolnit_main_group.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';

class ZolnitRouteEntry {
  const ZolnitRouteEntry({
    required this.members,
    required this.title,
    required this.region,
    required this.flag,
  });

  final List<ZolnitNode> members;
  final String title;
  final String region;
  final String? flag;

  ZolnitNode get primary => members.first;
  String get key => primary.id;

  bool contains(String? proxyName) =>
      proxyName != null && members.any((node) => node.proxyName == proxyName);
}

String _normalizeHost(String host) {
  var value = host.trim().toLowerCase();
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }
  while (value.endsWith('.')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

class ZolnitRouteMetadata {
  const ZolnitRouteMetadata(
    this.hosts,
    this.defaultGroup, [
    this.paths = const {},
  ]);

  final Map<String, String> hosts;
  final String? defaultGroup;
  final Map<String, String> paths;
}

ZolnitRouteMetadata zolnitRouteMetadata(String document) {
  final Object? config;
  try {
    config = loadPlainYaml(document);
  } on Object {
    return const ZolnitRouteMetadata({}, null);
  }
  if (config is! Map) return const ZolnitRouteMetadata({}, null);
  final proxies = config['proxies'];
  final rules = config['rules'];
  final defaults = rules is List
      ? rules
            .whereType<String>()
            .map((rule) => rule.split(',').map((part) => part.trim()).toList())
            .where(
              (parts) =>
                  parts.length == 2 && parts.first.toUpperCase() == 'MATCH',
            )
            .map((parts) => parts[1])
            .toSet()
      : <String>{};
  return ZolnitRouteMetadata(
    {
      for (final proxy in proxies is List ? proxies : const [])
        if (proxy is Map &&
            proxy['name'] is String &&
            proxy['server'] is String &&
            _normalizeHost(proxy['server'] as String).isNotEmpty)
          proxy['name'] as String: _normalizeHost(proxy['server'] as String),
    },
    defaults.length == 1 ? defaults.single : null,
    {
      for (final proxy in proxies is List ? proxies : const [])
        if (proxy is Map &&
            proxy['name'] is String &&
            proxy['dialer-proxy'] is String)
          proxy['name'] as String: proxy['dialer-proxy'] as String,
    },
  );
}

Group? zolnitNodesGroup(
  ZolnitRouteMetadata metadata,
  List<Group> groups,
  Mode mode,
) => zolnitMainGroup(metadata.defaultGroup, groups, mode);

final _hostCache = <String, ZolnitRouteMetadata>{};

ZolnitRouteMetadata? cachedZolnitRouteMetadata(ZolnitClientBundle bundle) =>
    _hostCache[bundle.connectionSha256];

Future<ZolnitRouteMetadata> loadZolnitRouteMetadata(
  ZolnitClientBundle bundle,
) async {
  final cached = cachedZolnitRouteMetadata(bundle);
  if (cached != null) return cached;
  final hosts = await compute(zolnitRouteMetadata, bundle.document);
  _hostCache
    ..clear()
    ..[bundle.connectionSha256] = hosts;
  return hosts;
}

/// Same-named rows merge only when the bundle proves one physical endpoint:
/// identical rendered server address, and no conflicting operator exit.
List<ZolnitRouteEntry> groupZolnitRoutes(
  List<ZolnitNode> nodes, {
  Map<String, String> hosts = const {},
  Map<String, String> exitIds = const {},
  Map<String, String> paths = const {},
}) {
  final ordered = [...nodes]..sort((a, b) => a.id.compareTo(b.id));
  final buckets = <(String, String, bool, double), List<List<ZolnitNode>>>{};
  final groups = <List<ZolnitNode>>[];
  for (final node in ordered) {
    final shown = zolnitNodePresentation(node);
    final host = hosts[node.proxyName];
    final exit = exitIds[node.id];
    final bucket = buckets.putIfAbsent((
      shown.title,
      shown.region,
      node.rateKnown,
      node.rate,
    ), () => []);
    final match = host == null
        ? null
        : bucket.where((group) {
            return group.every((other) {
              final otherExit = exitIds[other.id];
              return hosts[other.proxyName] == host &&
                  paths[other.proxyName] == paths[node.proxyName] &&
                  setEquals(other.tags.toSet(), node.tags.toSet()) &&
                  (exit == null || otherExit == null || exit == otherExit);
            });
          }).firstOrNull;
    if (match != null) {
      match.add(node);
    } else {
      final group = [node];
      bucket.add(group);
      groups.add(group);
    }
  }
  final namesakes = <(String, String), int>{};
  for (final group in groups) {
    final shown = zolnitNodePresentation(group.first);
    namesakes.update(
      (shown.title, shown.region),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  final ordinals = <(String, String), int>{};
  return [
    for (final group in groups)
      () {
        final shown = zolnitNodePresentation(group.first);
        final key = (shown.title, shown.region);
        final ordinal = ordinals.update(
          key,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        return ZolnitRouteEntry(
          members: List.unmodifiable(group),
          title: namesakes[key]! > 1
              ? '${shown.title} · $ordinal'
              : shown.title,
          region: shown.region,
          flag: shown.flag,
        );
      }(),
  ];
}

int _usability(int? delay) {
  if (delay != null && delay < 0) return 2;
  return delay == null || delay == 0 ? 1 : 0;
}

int _compareMembers(
  ZolnitNode a,
  ZolnitNode b,
  int? Function(ZolnitNode) delayOf,
) {
  final da = delayOf(a);
  final db = delayOf(b);
  final rank = _usability(da).compareTo(_usability(db));
  if (rank != 0) return rank;
  if (_usability(da) == 0) return da!.compareTo(db!);
  return 0;
}

/// The active member is kept so re-opening the list never moves traffic.
ZolnitNode? zolnitPreferredMember(
  ZolnitRouteEntry entry,
  int? Function(ZolnitNode) delayOf, {
  String? active,
  bool Function(ZolnitNode)? eligible,
}) {
  final candidates = entry.members
      .where((node) => eligible == null || eligible(node))
      .toList();
  for (final node in candidates) {
    if (node.proxyName == active) return node;
  }
  ZolnitNode? best;
  for (final node in candidates) {
    if (best == null ||
        _compareMembers(node, best, delayOf) < 0 ||
        (_compareMembers(node, best, delayOf) == 0 &&
            node.id.compareTo(best.id) < 0)) {
      best = node;
    }
  }
  return best;
}

List<ZolnitRouteEntry> sortZolnitRoutesByLatency(
  List<ZolnitRouteEntry> entries,
  ZolnitNode Function(ZolnitRouteEntry) representative,
  int? Function(ZolnitNode) delayOf,
) {
  final keyed = [for (final entry in entries) (entry, representative(entry))];
  keyed.sort((a, b) {
    final byDelay = _compareMembers(a.$2, b.$2, delayOf);
    if (byDelay != 0) return byDelay;
    final byTitle = a.$1.title.compareTo(b.$1.title);
    if (byTitle != 0) return byTitle;
    return a.$1.key.compareTo(b.$1.key);
  });
  return [for (final (entry, _) in keyed) entry];
}
