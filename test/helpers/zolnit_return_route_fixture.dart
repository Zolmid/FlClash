import 'dart:convert';
import 'dart:io';

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

List<Group> returnRouteCoreGroups() {
  final raw = returnRouteFixture();
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
