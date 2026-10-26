import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:yaml/yaml.dart';

Map<String, dynamic> returnRouteFixture() {
  final raw =
      jsonDecode(
            File(
              'packages/zolnit_client/test/fixtures/ui-groups-bundle-producer-v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return (raw['data'] ?? raw) as Map<String, dynamic>;
}

Map<String, dynamic> returnRouteAvailabilityFixture({
  bool restricted = false,
  String bundleId = 'return-route-three',
}) {
  final raw = returnRouteFixture()..['bundle_id'] = bundleId;
  final document =
      jsonDecode(jsonEncode(loadYaml(raw['connection']['document'] as String)))
          as Map<String, dynamic>;
  final role = (raw['routing']['ui_groups'] as List).single as Map;
  final options = role['options'] as List;
  options[0]['target'] = 'fixture.return.direct';
  final group = (document['proxy-groups'] as List).singleWhere(
    (g) => g['name'] == role['group'],
  );
  group['proxies'] = [...options.map((o) => o['target']), 'DIRECT'];
  final delivered = restricted
      ? <String>{'zn.node.hysteria.8'}
      : <String>{'zn.node.vless.7', 'zn.node.hysteria.8', 'zn.node.trojan.9'};
  (document['proxies'] as List).removeWhere(
    (p) => !delivered.contains(p['name']),
  );
  (raw['outbounds'] as List).removeWhere(
    (p) => !delivered.contains(p['proxy_name']),
  );
  (raw['routing']['nodes'] as List).removeWhere(
    (p) => !delivered.contains(p['proxy_name']),
  );
  (document['proxy-groups'] as List).add({
    'name': 'fixture.return.direct',
    'type': 'url-test',
    'proxies': restricted ? ['REJECT'] : ['zn.node.vless.7', 'REJECT'],
    'url': 'https://example.test/check',
    'interval': 300,
  });
  for (final item in document['proxy-groups'] as List) {
    if (item['name'] == options[1]['target']) {
      item['proxies'] = ['zn.node.hysteria.8', 'REJECT'];
    }
    if (item['name'] == options[2]['target']) {
      item['proxies'] = restricted
          ? ['REJECT']
          : ['zn.node.trojan.9', 'REJECT'];
    }
    item['proxies'] = [
      for (final name in item['proxies'] as List)
        if (!name.toString().startsWith('zn.node.') || delivered.contains(name))
          name,
    ];
    if ((item['proxies'] as List).isEmpty) item['proxies'] = ['REJECT'];
  }
  document['rules'] = [
    for (final rule in document['rules'] as List)
      restricted
          ? rule
                .toString()
                .replaceAll('zn.node.vless.7', 'REJECT')
                .replaceAll('zn.node.trojan.9', 'REJECT')
          : rule,
  ];
  final encoded = jsonEncode(document);
  raw['connection']['document'] = encoded;
  raw['connection']['sha256'] = sha256.convert(utf8.encode(encoded)).toString();
  return raw;
}

List<Group> returnRouteCoreGroups([Map<String, dynamic>? fixture]) {
  final raw = fixture ?? returnRouteFixture();
  final document = loadYaml(raw['connection']['document'] as String) as YamlMap;
  final types = <String, String>{
    'DIRECT': 'Direct',
    'REJECT': 'Reject',
    for (final node in document['proxies'] as List)
      node['name'] as String: node['type'] as String,
    for (final group in document['proxy-groups'] as List)
      group['name'] as String: group['type'] == 'select'
          ? 'Selector'
          : 'URLTest',
  };
  return [
    for (final group in document['proxy-groups'] as List)
      Group(
        name: group['name'] as String,
        type: group['type'] == 'select'
            ? GroupType.Selector
            : GroupType.URLTest,
        now: (group['proxies'] as List).first as String,
        all: [
          for (final name in group['proxies'] as List)
            Proxy(name: name as String, type: types[name]!),
        ],
      ),
  ];
}
