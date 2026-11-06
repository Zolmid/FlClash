import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/zolnit/node_groups.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

ZolnitNode node(
  String id,
  String title, {
  double rate = 1,
  List<String> tags = const [],
}) => ZolnitNode(
  id: id,
  name: title,
  title: title,
  region: 'HK',
  coreProxyName: 'proxy-$id',
  rate: rate,
  tags: tags,
);

void main() {
  test(
    'physical server protocols share a row without changing real identities',
    () {
      final a = node('vless:7', '香港 Lite A · VLESS · 1×');
      final b = node('hysteria:8', '香港 Lite A · HY2 · 1×');
      final rows = groupZolnitRoutes(
        [a, b],
        hosts: {a.proxyName: 'hk.example', b.proxyName: 'hk.example'},
      );
      expect(rows, hasLength(1));
      expect(rows.single.title, '香港 Lite A');
      expect(rows.single.members.map((n) => n.id).toSet(), {
        'vless:7',
        'hysteria:8',
      });
      expect(rows.single.contains(a.proxyName), isTrue);
      expect(rows.single.contains(b.proxyName), isTrue);
    },
  );

  test('hosts, exit identities, tiers and lines remain distinct', () {
    final a = node('1', '香港');
    final b = node('2', '香港');
    final tier = node('3', '香港', rate: 2);
    final line = node('4', '香港', tags: ['Premium']);
    final nodes = [a, b, tier, line];
    final hosts = {for (final n in nodes) n.proxyName: 'same.example'};
    expect(
      groupZolnitRoutes(
        nodes,
        hosts: hosts,
        exitIds: {'1': 'exit-a', '2': 'exit-b'},
      ),
      hasLength(4),
    );
    expect(
      groupZolnitRoutes(
        [a, b],
        hosts: {a.proxyName: 'a.example', b.proxyName: 'b.example'},
      ),
      hasLength(2),
    );
    expect(groupZolnitRoutes([a, b]), hasLength(2));
    expect(
      groupZolnitRoutes(
        [a, b],
        hosts: hosts,
        paths: {a.proxyName: 'bridge-a', b.proxyName: 'bridge-b'},
      ),
      hasLength(2),
    );
    final forwards = groupZolnitRoutes(
      nodes,
      hosts: hosts,
    ).map((r) => (r.key, r.title)).toList();
    expect(
      groupZolnitRoutes(
        nodes.reversed.toList(),
        hosts: hosts,
      ).map((r) => (r.key, r.title)),
      forwards,
    );
  });

  test(
    'active protocol wins; otherwise best eligible measured protocol wins',
    () {
      final a = node('a', '香港');
      final b = node('b', '香港');
      final row = groupZolnitRoutes(
        [b, a],
        hosts: {a.proxyName: 'hk', b.proxyName: 'hk'},
      ).single;
      int? delay(ZolnitNode n) => n.id == 'a' ? 45 : 41;
      expect(zolnitPreferredMember(row, delay), b);
      expect(zolnitPreferredMember(row, delay, active: a.proxyName), a);
      expect(
        zolnitPreferredMember(row, delay, eligible: (n) => n.id == 'a'),
        a,
      );
      expect(zolnitPreferredMember(row, delay, eligible: (_) => false), isNull);
      expect(zolnitPreferredMember(row, (_) => null), a);
      expect(zolnitPreferredMember(row, (_) => 41), a);
      expect(zolnitPreferredMember(row, (n) => n.id == 'a' ? -1 : null), b);
    },
  );

  test('latency order is deterministic, unknown zero and failures last', () {
    final nodes = [
      node('us', '美国'),
      node('hk', '香港 Lite A'),
      node('sg', '新加坡'),
      node('z', 'Unknown'),
      node('a', 'Unknown'),
      node('failed', 'Failed'),
    ];
    final rows = groupZolnitRoutes(nodes);
    final delays = <String, int?>{
      'us': 286,
      'hk': 45,
      'sg': 41,
      'z': 0,
      'a': null,
      'failed': -1,
    };
    List<String> sorted(List<ZolnitRouteEntry> input) =>
        sortZolnitRoutesByLatency(
          input,
          (r) => r.primary,
          (n) => delays[n.id],
        ).map((r) => r.key).toList();
    expect(sorted(rows).take(3), ['sg', 'hk', 'us']);
    expect(sorted(rows.reversed.toList()), sorted(rows));
    expect(nodes.first.id, 'us');
  });

  test(
    'bundle metadata normalizes hosts and follows MATCH rather than largest group',
    () {
      final metadata = zolnitRouteMetadata('''
proxies:
  - {name: a, server: 'EDGE.EXAMPLE.'}
  - {name: b, server: '[2001:db8::1]'}
rules:
  - 'DOMAIN,example.com,service'
  - 'MATCH,default'
''');
      expect(metadata.hosts, {'a': 'edge.example', 'b': '2001:db8::1'});
      const groups = [
        Group(
          name: 'return',
          type: GroupType.Selector,
          all: [
            Proxy(name: 'a', type: 'ss'),
            Proxy(name: 'b', type: 'ss'),
          ],
        ),
        Group(
          name: 'default',
          type: GroupType.Selector,
          all: [Proxy(name: 'a', type: 'ss')],
        ),
        Group(name: 'GLOBAL', type: GroupType.Selector),
      ];
      expect(zolnitNodesGroup(metadata, groups, Mode.rule)?.name, 'default');
      expect(zolnitNodesGroup(metadata, groups, Mode.direct)?.name, 'default');
      expect(zolnitNodesGroup(metadata, groups, Mode.global)?.name, 'GLOBAL');
      expect(
        zolnitNodesGroup(zolnitRouteMetadata('rules: []'), groups, Mode.rule),
        isNull,
      );
      expect(zolnitRouteMetadata('[').hosts, isEmpty);
      expect(
        zolnitRouteMetadata('rules: ["MATCH,a", "MATCH,b"]').defaultGroup,
        isNull,
      );
    },
  );
}
