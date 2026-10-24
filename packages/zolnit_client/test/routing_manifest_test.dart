import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'routing_fixture.dart';

void main() {
  SmartRoutingManifest? parse(Map<String, dynamic> config) =>
      SmartRoutingManifest.parse(
        config[routingManifestKey],
        proxyNames: (config['proxies'] as List)
            .map((p) => p['name'] as String)
            .toSet(),
        groupNames: (config['proxy-groups'] as List)
            .map((p) => p['name'] as String)
            .toSet(),
      );

  test('product policies intersect declarations and exclude HK for all AI', () {
    expect(routingProviderCountries['gemini_web'], contains('HK'));
    expect(routingProviderCountries['gemini_api'], isNot(contains('HK')));
    expect(
      supportedRoutingCountries(['gemini_web'], {'HK', 'US'}, isAi: true),
      {'US'},
    );
    expect(
      supportedRoutingCountries(
        ['chatgpt', 'claude'],
        {'HK', 'US', 'JP', 'SG', 'TW', 'CN'},
        isAi: true,
      ),
      {'US', 'JP', 'SG', 'TW'},
    );
    expect(
      supportedRoutingCountries(['operator'], {'HK'}, isAi: true),
      isEmpty,
    );
    expect(supportedRoutingCountries(['netflix'], {'HK'}, isAi: true), isEmpty);
    expect(
      supportedRoutingCountries(['unknown'], {'US'}, isAi: false),
      isEmpty,
    );
    expect(
      supportedRoutingCountries(['operator'], {'US', 'ZZ', 'XX'}, isAi: false),
      {'US'},
    );
    expect(
      supportedRoutingCountries(
        ['netflix'],
        {'CN', 'KP', 'RU', 'SY', 'UA', 'HK', 'US'},
        isAi: false,
      ),
      {'HK', 'US'},
    );
  });

  test(
    'snapshots use current ISO codes and exclude unresolved territorial exceptions',
    () {
      expect(routingCountryCodes.length, 249);
      for (final codes in routingProviderCountries.values) {
        expect(codes.difference(routingCountryCodes), isEmpty);
      }
      expect(
        routingProviderCountries['chatgpt'],
        containsAll(['GB', 'FR', 'BF', 'BJ', 'RS', 'CZ', 'MM']),
      );
      expect(routingProviderCountries['chatgpt'], isNot(contains('UA')));
      expect(routingProviderCountries['claude'], contains('UA'));
      expect(routingProviderCountries['operator'], isNot(contains('UK')));
    },
  );

  test(
    'manifest binds exact outbound names and filters eligibility per service',
    () {
      final manifest = parse(routingFixture())!;
      final engine = SmartRoutingEngine()
        ..configure(
          generation: 1,
          nodes: manifest.nodes,
          services: manifest.services.map((s) => s.route).toList(),
        );
      expect(engine.candidates('ai').map((n) => n.id), ['us', 'jp']);
      expect(engine.candidates('media').map((n) => n.id), ['hk', 'us', 'jp']);
      expect(manifest.services.first.probeUrls.length, 3);
      expect(manifest.revision, 'inventory-v1');
    },
  );

  test(
    'missing, wrong version or wrong authority disables the whole manifest',
    () {
      final source = routingFixture();
      expect(parse({...source, routingManifestKey: null}), isNull);
      for (final patch in [
        {'version': 2},
        {'authority': 'untrusted'},
        {'revision': ''},
      ]) {
        final config = routingFixture();
        (config[routingManifestKey] as Map).addAll(patch);
        expect(parse(config), isNull);
      }
    },
  );

  test(
    'unverified, ingress-only and unknown metadata never creates automatic candidates',
    () {
      for (final key in [
        'final_egress',
        'failure_domain',
        'services',
        'enabled',
        'revision',
      ]) {
        final config = routingFixture();
        final raw = config[routingManifestKey] as Map;
        for (final node in raw['nodes'] as List) {
          (node as Map).remove(key);
          node['country'] = 'US';
          node['name'] = 'United States fast';
        }
        expect(parse(config)!.nodes, isEmpty);
      }
      for (final patch in [
        {'country': 'ZZ'},
        {'verified': false},
        {'source': 'ingress_inventory'},
      ]) {
        final config = routingFixture();
        for (final node
            in (config[routingManifestKey] as Map)['nodes'] as List) {
          (node['final_egress'] as Map).addAll(patch);
        }
        expect(parse(config)!.nodes, isEmpty);
      }
    },
  );

  test(
    'duplicate identities, proxy aliases and group collisions fail closed',
    () {
      for (final field in ['id', 'proxy_name']) {
        final config = routingFixture();
        final nodes = (config[routingManifestKey] as Map)['nodes'] as List;
        nodes[1][field] = nodes[0][field];
        expect(parse(config), isNull);
      }
      for (final name in ['DIRECT', '节点选择', 'us-exit', 'AI 服务']) {
        final config = routingFixture();
        final services =
            (config[routingManifestKey] as Map)['services'] as List;
        services[0]['automatic'] = name;
        expect(parse(config), isNull);
      }
    },
  );

  test(
    'unknown products and inferred node display names cannot broaden service scope',
    () {
      final config = routingFixture();
      final raw = config[routingManifestKey] as Map;
      (raw['services'] as List)[0]['providers'] = ['operator'];
      expect(parse(config), isNull);
      final renamed = routingFixture();
      ((renamed[routingManifestKey] as Map)['nodes'] as List)[0]['proxy_name'] =
          'US fast';
      expect(parse(renamed)!.nodes.map((n) => n.id), ['us', 'jp']);
    },
  );

  test('new structured nodes require no changes to the client roster', () {
    final config = routingFixture();
    (config['proxies'] as List).add({'name': 'new-sg', 'type': 'ss'});
    final raw = config[routingManifestKey] as Map;
    (raw['nodes'] as List).add({
      'id': 'new-provider-999',
      'proxy_name': 'new-sg',
      'final_egress': {
        'country': 'SG',
        'verified': true,
        'source': 'egress_probe',
      },
      'failure_domain': 'new-egress',
      'services': ['ai'],
      'enabled': true,
      'revision': 'egress-v2',
    });
    expect(parse(config)!.nodes.last.id, 'new-provider-999');
    ((raw['nodes'] as List).last as Map)['enabled'] = false;
    final manifest = parse(config)!;
    final engine = SmartRoutingEngine()
      ..configure(
        generation: 1,
        nodes: manifest.nodes,
        services: manifest.services.map((s) => s.route).toList(),
      );
    expect(
      engine.candidates('ai').map((n) => n.id),
      isNot(contains('new-provider-999')),
    );
  });
  test(
    'AI products and the known AI rule group cannot be mislabeled as general traffic',
    () {
      for (final patch in [
        {'kind': 'general'},
        {
          'kind': 'general',
          'providers': ['operator'],
        },
        {'group': '海外影音', 'kind': 'media'},
      ]) {
        final config = routingFixture();
        (((config[routingManifestKey] as Map)['services'] as List).first as Map)
            .addAll(patch);
        expect(parse(config), isNull);
      }
    },
  );
  test(
    'schema version is an integer, not a string or numerically equal float',
    () {
      for (final version in [1.0, '1', true, null]) {
        final config = routingFixture();
        (config[routingManifestKey] as Map)['version'] = version;
        expect(parse(config), isNull);
      }
    },
  );
}
