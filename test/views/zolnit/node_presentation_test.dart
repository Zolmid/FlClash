import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  for (final (name, title, flag) in [
    ('🇭🇰 香港 Lite A · HY2 · 1×', 'HK · Lite A', '🇭🇰'),
    ('🇺🇸 美国 · HY2 · 1×', 'US', '🇺🇸'),
  ]) {
    test(
      'private bundle presentation normalizes $name without changing routing',
      () {
        final node = ZolnitNode(
          id: 'node:1',
          name: name,
          title: name,
          region: '',
          coreProxyName: 'zn.node.node.1',
        );
        final shown = zolnitNodePresentation(node);
        expect(shown.title, title);
        expect(shown.flag, flag);
        expect(shown.region, isNotEmpty);
        expect(node.region, isEmpty);
        expect(node.proxyName, 'zn.node.node.1');
      },
    );
  }

  test('unknown locations stay unknown and metadata retains priority', () {
    const unknown = ZolnitNode(
      id: '1',
      name: 'Edge A',
      title: 'Edge A',
      region: '',
    );
    expect(zolnitNodePresentation(unknown).flag, isNull);
    expect(zolnitNodePresentation(unknown).region, isEmpty);
    const explicit = ZolnitNode(
      id: '2',
      name: '🇭🇰 Edge B',
      title: 'Edge B',
      region: 'SG',
      countryCode: 'SG',
    );
    expect(zolnitNodePresentation(explicit).region, 'SG');
    expect(zolnitNodePresentation(explicit).flag, '🇸🇬');
  });

  test(
    'region labels use ISO codes independently of localized server text',
    () {
      for (final (name, code) in [
        ('香港 · Edge', 'HK'),
        ('United States · Edge', 'US'),
        ('Singapore · Edge', 'SG'),
        ('日本 · Edge', 'JP'),
        ('台湾 · Edge', 'TW'),
      ]) {
        final node = ZolnitNode.fromJson({'id': name, 'name': name});
        expect(node.region, code);
        expect(zolnitNodePresentation(node).region, code);
      }
    },
  );
}
