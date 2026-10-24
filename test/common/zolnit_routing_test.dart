import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../packages/zolnit_client/test/routing_fixture.dart';

void main() {
  Map group(Map config, String name) => (config['proxy-groups'] as List)
      .cast<Map>()
      .singleWhere((g) => g['name'] == name);

  test(
    'managed groups preserve rule targets and separate automatic from manual candidates',
    () {
      final source = routingFixture();
      final prepared = prepareZolnitRouting(source);
      final config = prepared.config;
      expect(config['rules'], source['rules']);
      expect(config['mode'], 'rule');
      expect(group(config, 'AI 服务')['proxies'], ['AI 自动', 'AI 手动', 'DIRECT']);
      expect(group(config, 'AI 自动')['type'], 'select');
      expect(group(config, 'AI 自动')['proxies'], [
        'REJECT',
        'us-exit',
        'jp-exit',
      ]);
      expect(group(config, 'AI 手动')['proxies'], [
        'hk-exit',
        'us-exit',
        'jp-exit',
        'DIRECT',
      ]);
      expect(group(config, '影音自动')['proxies'], [
        'REJECT',
        'hk-exit',
        'us-exit',
        'jp-exit',
      ]);
      expect(group(config, '节点选择')['type'], 'url-test');
      expect(group(config, '节点选择')['proxies'], contains('hk-exit'));
      expect(group(source, 'AI 服务')['proxies'], ['节点选择', 'DIRECT']);
    },
  );

  test(
    'legacy and invalid manifests cannot inherit AI from the shared pool',
    () {
      for (final metadata in [
        null,
        {'version': 99},
      ]) {
        final source = routingFixture()..[routingManifestKey] = metadata;
        final prepared = prepareZolnitRouting(source);
        expect(prepared.manifest, isNull);
        expect(group(prepared.config, 'AI 服务')['proxies'], [
          'REJECT',
          'AI 服务 · 手动',
          'DIRECT',
        ]);
        expect(group(prepared.config, 'AI 服务 · 手动')['type'], 'select');
        expect(group(prepared.config, '海外影音')['proxies'], ['节点选择', 'DIRECT']);
        expect(prepared.config['rules'], source['rules']);
      }
    },
  );

  test('ambiguous outbound names disable automatic processing', () {
    final source = routingFixture();
    (source['proxies'] as List).add({'name': 'us-exit', 'type': 'ss'});
    final prepared = prepareZolnitRouting(source);
    expect(prepared.manifest, isNull);
    expect(group(prepared.config, 'AI 服务')['proxies'], isNot(contains('节点选择')));
  });

  test(
    'an existing fallback-name group is never trusted as a manual-only path',
    () {
      final source = routingFixture()..remove(routingManifestKey);
      (source['proxy-groups'] as List).add({
        'name': 'AI 服务 · 手动',
        'type': 'url-test',
        'proxies': ['hk-exit'],
      });
      expect(group(prepareZolnitRouting(source).config, 'AI 服务')['proxies'], [
        'REJECT',
        'DIRECT',
      ]);
    },
  );
  test(
    'a manifest covering only media cannot leave the legacy AI inheritance active',
    () {
      final source = routingFixture();
      final raw = source[routingManifestKey] as Map;
      (raw['services'] as List).removeAt(0);
      for (final node in raw['nodes'] as List) {
        node['services'] = ['media'];
      }
      final prepared = prepareZolnitRouting(source);
      expect(prepared.manifest, isNotNull);
      expect(group(prepared.config, 'AI 服务')['proxies'], [
        'REJECT',
        'AI 服务 · 手动',
        'DIRECT',
      ]);
      expect(group(prepared.config, '海外影音')['proxies'], [
        '影音自动',
        '影音手动',
        'DIRECT',
      ]);
    },
  );
}
