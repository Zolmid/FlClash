import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../helpers/zolnit_return_route_fixture.dart';

void main() {
  ZolnitClientBundle parse(Map<String, dynamic> raw) =>
      ZolnitClientBundle.parse(
        raw,
        now: DateTime.fromMillisecondsSinceEpoch(1001000, isUtc: true),
        expectedAccountId: 'account-1',
      );

  test(
    'explicit dispatch bindings start local and observe both Core parents',
    () {
      final raw = returnDispatchFixture();
      final bundle = parse(raw);
      final local = ZolnitReturnRoute.resolve(
        bundle,
        returnDispatchCoreGroups(raw),
      )!;
      expect(local.activationAvailable, isTrue);
      expect(local.active, isFalse);
      final enabled = returnDispatchCoreGroups(raw, active: true);
      expect(ZolnitReturnRoute.resolve(bundle, enabled)!.active, isTrue);
      expect(
        ZolnitReturnRoute.resolve(bundle, [
          for (final group in enabled)
            group.name == 'fixture.return_dispatch'
                ? group.copyWith(now: 'fixture.local')
                : group,
        ])!.active,
        isFalse,
      );
      expect(
        ZolnitReturnRoute.resolve(
          parse(returnRouteFixture()),
          returnRouteCoreGroups(),
        )!.activationAvailable,
        isFalse,
      );
    },
  );

  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'partial dispatch': (raw) =>
        (raw['routing']['ui_groups'] as List).removeLast(),
    'duplicate dispatch': (raw) =>
        raw['routing']['ui_groups'][2]['id'] = 'return_dispatch',
    'same parent': (raw) =>
        raw['routing']['ui_groups'][2]['group'] = 'fixture.return_dispatch',
    'literal local': (raw) =>
        raw['routing']['ui_groups'][1]['options'][0]['target'] = 'DIRECT',
    'wrong return parent': (raw) =>
        raw['routing']['ui_groups'][1]['options'][1]['target'] =
            'fixture.local',
    'managed service': (raw) =>
        raw['routing']['ui_groups'][1]['group'] = 'zn.service.ai',
  }.entries) {
    test(
      '${mutation.key} cannot enable dispatch but preserves return choices',
      () {
        final raw = returnDispatchFixture();
        mutation.value(raw);
        final route = ZolnitReturnRoute.resolve(
          parse(raw),
          returnDispatchCoreGroups(raw),
        )!;
        expect(route.activationAvailable, isFalse);
        expect(route.active, isFalse);
        expect(route.options, hasLength(3));
      },
    );
  }

  test('a network alias in the local wrapper cannot masquerade as local', () {
    final raw = returnDispatchFixture();
    final groups = [
      for (final group in returnDispatchCoreGroups(raw))
        group.name == 'fixture.local'
            ? group.copyWith(
                all: const [Proxy(name: 'zn.node.vless.7', type: 'Vless')],
              )
            : group,
    ];
    expect(
      ZolnitReturnRoute.resolve(parse(raw), groups)!.activationAvailable,
      isFalse,
    );
  });

  test(
    'PHP producer maps all return roles to actual Core selector members',
    () {
      final raw = returnRouteFixture();
      final bundle = parse(raw);
      final groups = returnRouteCoreGroups();
      final route = ZolnitReturnRoute.resolve(bundle, groups)!;
      expect(
        route.options.map((option) => option.id),
        ZolnitReturnRoute.optionIds,
      );
      expect(route.options.first.target, 'zn.node.vless.7');
      expect(route.options.first.target, isNot('DIRECT'));
      for (final option in route.options) {
        expect(
          groups.getGroup(route.group)!.all.map((p) => p.name),
          contains(option.target),
        );
      }
      final selected = [
        for (final group in groups)
          group.name == route.group
              ? group.copyWith(now: route.options.last.target)
              : group,
      ];
      expect(
        ZolnitReturnRoute.resolve(bundle, selected)!.selectedId,
        'hk_optimized',
      );
      expect(
        bundle.toJson()['connection']['document'],
        raw['connection']['document'],
      );
    },
  );

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing mapping': (raw) => raw['routing'].remove('ui_groups'),
    'duplicate role': (raw) =>
        raw['routing']['ui_groups'].add(raw['routing']['ui_groups'].first),
    'duplicate option': (raw) =>
        raw['routing']['ui_groups'][0]['options'][1]['id'] = 'direct',
    'foreign group': (raw) =>
        raw['routing']['ui_groups'][0]['group'] = 'missing',
    'unknown member': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['target'] = 'missing',
    'DIRECT target': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['target'] = 'DIRECT',
    'REJECT target': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['target'] = 'REJECT',
    'service selector': (raw) =>
        raw['routing']['ui_groups'][0]['group'] = 'zn.service.ai',
    'service target': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['target'] =
            'zn.service.ai.manual',
    'mixed case service selector': (raw) =>
        raw['routing']['ui_groups'][0]['group'] = 'Zn.Service.ai',
    'client service target': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['target'] =
            'ClientZn.Service.ai.manual',
    'unknown option': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0]['id'] = 'other',
    'malformed option': (raw) =>
        raw['routing']['ui_groups'][0]['options'][0] = null,
  };
  for (final entry in invalid.entries) {
    test('${entry.key} hides the complete optional group', () {
      final raw = returnRouteFixture();
      entry.value(raw);
      expect(
        ZolnitReturnRoute.resolve(parse(raw), returnRouteCoreGroups()),
        isNull,
      );
    });
  }

  test('Core type mismatch and a Direct alias hide the group', () {
    final bundle = parse(returnRouteFixture());
    final groups = returnRouteCoreGroups();
    final route = ZolnitReturnRoute.resolve(bundle, groups)!;
    expect(
      ZolnitReturnRoute.resolve(bundle, [
        for (final group in groups)
          group.name == route.group
              ? group.copyWith(type: GroupType.URLTest)
              : group,
      ]),
      isNull,
    );
    expect(
      ZolnitReturnRoute.resolve(bundle, [
        for (final group in groups)
          group.name == route.group
              ? group.copyWith(
                  all: [
                    for (final proxy in group.all)
                      proxy.name == route.options.first.target
                          ? proxy.copyWith(type: 'Direct')
                          : proxy,
                  ],
                )
              : group,
      ]),
      isNull,
    );
  });
  test(
    'authorized graph exposes one or three roles without changing the wire mapping',
    () {
      for (final restricted in [true, false]) {
        final raw = returnRouteAvailabilityFixture(restricted: restricted);
        final bundle = parse(raw);
        final route = ZolnitReturnRoute.resolve(
          bundle,
          returnRouteCoreGroups(raw),
        )!;
        expect(
          route.options.map((option) => option.id),
          restricted ? ['hk_lite'] : ['direct', 'hk_lite', 'hk_optimized'],
        );
        expect(
          (ZolnitReturnRoute.corePolicy(bundle)!['options'] as List),
          hasLength(3),
        );
        expect(bundle.routingJson['ui_groups'][0]['options'], hasLength(3));
      }
    },
  );

  test(
    'nested cycles cannot borrow siblings but a physical exit remains usable',
    () {
      final raw = returnRouteAvailabilityFixture();
      final bundle = parse(raw);
      final groups = returnRouteCoreGroups(raw);
      final initial = ZolnitReturnRoute.resolve(bundle, groups)!;
      final direct = initial.options.first.target;
      List<Group> graph(List<Proxy> edges) => [
        for (final group in groups)
          group.name == direct ? group.copyWith(all: edges) : group,
      ];
      final blocked = graph([
        Proxy(name: direct, type: 'URLTest'),
        Proxy(name: initial.group, type: 'Selector'),
        const Proxy(name: 'REJECT', type: 'Reject'),
        const Proxy(name: 'DIRECT', type: 'Direct'),
      ]);
      expect(
        ZolnitReturnRoute.resolve(bundle, blocked)!.options.map((o) => o.id),
        ['hk_lite', 'hk_optimized'],
      );
      final exiting = graph([
        Proxy(name: direct, type: 'URLTest'),
        const Proxy(name: 'zn.node.vless.7', type: 'Vless'),
      ]);
      expect(
        ZolnitReturnRoute.resolve(bundle, exiting)!.options.map((o) => o.id),
        ['direct', 'hk_lite', 'hk_optimized'],
      );
      final alias = graph([
        const Proxy(name: 'zn.node.vless.7', type: 'Direct'),
      ]);
      expect(
        ZolnitReturnRoute.resolve(bundle, alias)!.options.map((o) => o.id),
        ['hk_lite', 'hk_optimized'],
      );
    },
  );
}
