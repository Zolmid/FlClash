import 'package:fl_clash/common/zolnit_main_group.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../packages/zolnit_client/test/client_bundle_fixture.dart';

void main() {
  test('ordinary server selection is independent of AI automatic groups', () {
    final bundle = ZolnitClientBundle.parse(
      clientBundleFixture(),
      now: bundleTime(1001),
    );
    final nodes = bundle.outbounds
        .map((node) => Proxy(name: node.proxyName, type: 'Vless'))
        .toList();
    final service = bundle.routingManifest.services.first;
    final groups = [
      Group(name: service.groupName, type: GroupType.Selector, all: nodes),
      Group(name: service.manualGroup, type: GroupType.Selector, all: nodes),
      Group(name: 'GLOBAL', type: GroupType.Selector, all: nodes),
      Group(name: 'automatic', type: GroupType.URLTest, all: nodes),
      Group(name: 'ordinary', type: GroupType.Selector, all: nodes),
    ];
    expect(zolnitMainGroup(bundle, groups, Mode.rule)?.name, 'ordinary');
    expect(zolnitMainGroup(bundle, groups, Mode.global)?.name, 'GLOBAL');
    expect(zolnitMainGroup(bundle, groups.take(4), Mode.rule), isNull);
  });
}
