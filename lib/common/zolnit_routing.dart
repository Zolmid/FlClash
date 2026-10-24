import 'dart:io';

import 'package:fl_clash/common/yaml.dart';
import 'package:zolnit_client/zolnit_client.dart';

bool isSmartRoutingProxyType(Object? type) {
  if (type is! String) return false;
  return const {
    'ss',
    'shadowsocks',
    'ssr',
    'shadowsocksr',
    'snell',
    'socks5',
    'http',
    'vmess',
    'vless',
    'trojan',
    'hysteria',
    'hysteria2',
    'wireguard',
    'tuic',
    'ssh',
    'mieru',
    'anytls',
    'sudoku',
    'masque',
    'trusttunnel',
    'shadowquic',
    'openvpn',
    'tailscale',
    'zerotier',
    'easytier',
    'gostrelay',
  }.contains(type.toLowerCase().replaceAll('-', ''));
}

typedef PreparedZolnitRouting = ({
  Map<String, dynamic> config,
  SmartRoutingManifest? manifest,
  SmartRoutingEngine? engine,
});

Future<Map<String, dynamic>> readZolnitRoutingProfile(String path) async {
  final document = loadPlainYaml(await File(path).readAsString());
  if (document is! Map) {
    throw const FormatException('Invalid managed subscription document');
  }
  return Map<String, dynamic>.from(document);
}

PreparedZolnitRouting prepareZolnitRouting(
  Map<String, dynamic> source, {
  Object? routingMetadata,
}) {
  final config = Map<String, dynamic>.of(source);
  final rawProxies = source['proxies'];
  final rawGroups = source['proxy-groups'];
  final proxies = <String>{};
  final routable = <String>{};
  var ambiguous = false;
  if (rawProxies is List) {
    for (final raw in rawProxies) {
      if (raw is Map && raw['name'] is String) {
        if (!proxies.add(raw['name'] as String)) ambiguous = true;
        if (isSmartRoutingProxyType(raw['type'])) {
          routable.add(raw['name'] as String);
        }
      }
    }
  }
  final groups = <String, Map<String, dynamic>>{};
  if (rawGroups is List) {
    for (final raw in rawGroups) {
      if (raw is Map && raw['name'] is String) {
        final name = raw['name'] as String;
        if (groups.containsKey(name) || proxies.contains(name)) {
          ambiguous = true;
        }
        groups[name] = Map<String, dynamic>.from(raw);
      }
    }
  }
  final parsedManifest = ambiguous
      ? null
      : SmartRoutingManifest.parse(
          routingMetadata ?? source[routingManifestKey],
          proxyNames: proxies,
          groupNames: groups.keys.toSet(),
        );
  final manifest = parsedManifest == null
      ? null
      : SmartRoutingManifest(
          revision: parsedManifest.revision,
          services: parsedManifest.services,
          nodes: List.unmodifiable(
            parsedManifest.nodes.where(
              (node) => routable.contains(node.proxyName),
            ),
          ),
        );
  SmartRoutingEngine? engine;
  if (manifest?.services.any(
        (service) => service.groupName == 'AI 服务' && service.route.isAi,
      ) !=
      true) {
    // Legacy AI selectors must not inherit the shared HK-inclusive auto pool.
    final ai = groups['AI 服务'];
    if (ai != null) {
      const manual = 'AI 服务 · 手动';
      if (!groups.containsKey(manual) && !proxies.contains(manual)) {
        groups[manual] = {
          'name': manual,
          'type': 'select',
          'proxies': [...proxies, 'DIRECT'],
        };
        groups['AI 服务'] = {
          'name': 'AI 服务',
          'type': 'select',
          'proxies': ['REJECT', manual, 'DIRECT'],
        };
      } else {
        groups['AI 服务'] = {
          'name': 'AI 服务',
          'type': 'select',
          'proxies': ['REJECT', 'DIRECT'],
        };
      }
    }
  }
  if (manifest != null) {
    engine = SmartRoutingEngine()
      ..configure(
        generation: 0,
        nodes: manifest.nodes,
        services: manifest.services.map((s) => s.route).toList(),
      );
    for (final service in manifest.services) {
      final automatic = service.route.groupName;
      groups[service.groupName] = {
        'name': service.groupName,
        'type': 'select',
        'proxies': [automatic, service.manualGroup, 'DIRECT'],
      };
      groups[automatic] = {
        'name': automatic,
        'type': 'select',
        'proxies': [
          'REJECT',
          ...engine.candidates(service.route.id).map((node) => node.proxyName),
        ],
        'url': service.probeUrls.first,
      };
      groups[service.manualGroup] = {
        'name': service.manualGroup,
        'type': 'select',
        'proxies': [...proxies, 'DIRECT'],
      };
    }
  }
  config['proxy-groups'] = groups.values.toList();
  return (config: config, manifest: manifest, engine: engine);
}
