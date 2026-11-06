import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/yaml.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/nodes.dart';
import 'package:fl_clash/views/zolnit/node_groups.dart';
import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';
import '../../../packages/zolnit_client/test/client_bundle_fixture.dart';
import '../../helpers/test_profiles.dart';

class _RecordingProxies extends ProxiesAction {
  final selections = <(String, String)>[];
  final measurements = <(List<String>, String)>[];

  @override
  void build() {}

  @override
  Future<void> delayTestPageGroup(
    String groupName, {
    bool matchSearch = true,
  }) async {}

  @override
  Future<void> delayTestNodes(List<Proxy> proxies, String testUrl) async {
    measurements.add((proxies.map((proxy) => proxy.name).toList(), testUrl));
  }

  @override
  void changeProxyDebounce(String groupName, String proxyName) {
    selections.add((groupName, proxyName));
  }
}

void main() {
  final harness = ZolnitHarness.register(
    clientPlatform: 'macos',
    distribution: 'direct',
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      proxiesActionProvider.overrideWith(_RecordingProxies.new),
    ],
  );

  var bundleNow = bundleTime(1001);

  Future<String> preparePrivateBundle(
    WidgetTester tester, {
    Mode mode = Mode.rule,
    bool automatic = false,
    bool merged = false,
    ZolnitSkin skin = ZolnitSkin.macos,
  }) async {
    bundleNow = bundleTime(1001);
    final fixture = ClientBundleSessionFixture();
    if (merged) {
      final raw = clientBundleFixture();
      final document =
          loadPlainYaml(raw['connection']['document'] as String) as Map;
      final proxies = document['proxies'] as List;
      proxies.first['server'] = 'hk.example';
      proxies.first.remove('dialer-proxy');
      final encoded = jsonEncode(document);
      raw['connection']['document'] = encoded;
      raw['connection']['sha256'] = sha256
          .convert(utf8.encode(encoded))
          .toString();
      for (final outbound in raw['outbounds'] as List) {
        if (outbound['id'] == 'vless:7') {
          outbound['display_name'] = '香港 Lite A · VLESS · 1×';
        }
        if (outbound['id'] == 'hysteria:8') {
          outbound['display_name'] = '香港 Lite A · HY2 · 1×';
        }
      }
      for (final node in raw['routing']['nodes'] as List) {
        if (node['id'] == 'vless:7') {
          node['final_egress']['country'] = 'HK';
          node['exit_id'] = 'exit-hk-1';
        }
      }
      fixture.onBundle = (_) async => clientBundleResponse(raw);
    }
    addTearDown(fixture.session.dispose);
    await tester.runAsync(() async {
      await fixture.login();
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
    });
    final bundle = fixture.session.clientBundle!;
    await tester.runAsync(() => loadZolnitRouteMetadata(bundle));
    final group = cachedZolnitRouteMetadata(bundle)!.defaultGroup!;
    final nodes = fixture.session.nodeList;
    final profile = Profile.normal(label: 'private').copyWith(
      zolnitAccountId: bundle.accountId,
      zolnitBundleId: bundle.bundleId,
      zolnitOrigin: fixture.api.origin.origin,
      selectedMap: {group: nodes.last.proxyName},
    );
    harness.container.dispose();
    harness.container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(fixture.session),
        zolnitClientBundleTransportProvider.overrideWithValue(true),
        zolnitBundleClockProvider.overrideWithValue(() => bundleNow),
        safeModeProvider.overrideWithValue(false),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        proxiesActionProvider.overrideWith(_RecordingProxies.new),
      ],
    );
    globalState.container = harness.container;
    harness.container.read(patchClashConfigProvider.notifier).value = harness
        .container
        .read(patchClashConfigProvider)
        .copyWith(mode: mode);
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.connected;
    harness.container.read(groupsProvider.notifier).value = [
      Group(
        name: 'unrelated-return',
        type: GroupType.Selector,
        all: [for (final n in nodes) Proxy(name: n.proxyName, type: 'ss')],
      ),
      Group(
        name: 'zn.service.ai',
        type: GroupType.URLTest,
        now: nodes.last.proxyName,
        all: [for (final n in nodes) Proxy(name: n.proxyName, type: 'ss')],
      ),
      Group(
        name: group,
        type: automatic ? GroupType.URLTest : GroupType.Selector,
        now: merged ? nodes[1].proxyName : nodes.last.proxyName,
        all: [
          for (final n in nodes.take(2)) Proxy(name: n.proxyName, type: 'ss'),
          Proxy(name: nodes.last.proxyName, type: 'ss'),
        ],
      ),
      Group(
        name: 'GLOBAL',
        type: GroupType.Selector,
        now: nodes.first.proxyName,
        all: [for (final n in nodes) Proxy(name: n.proxyName, type: 'ss')],
      ),
    ];
    for (final (i, delay) in [(0, 45), (2, 286)]) {
      harness.container
          .read(delayDataSourceProvider.notifier)
          .setDelay(
            Delay(
              name: nodes[i].proxyName,
              url: harness.container.read(realTestUrlProvider()),
              value: delay,
            ),
          );
    }
    await harness.mount(
      tester,
      skin,
      child: ZolnitNodesPage(session: fixture.session, sync: () async => null),
    );
    return group;
  }

  for (final skin in [ZolnitSkin.macos, ZolnitSkin.ios]) {
    testWidgets(
      'merged physical server on ${skin.name} chooses a real protocol internally',
      (tester) async {
        final group = await preparePrivateBundle(
          tester,
          merged: true,
          skin: skin,
        );
        expect(find.text('香港 Lite A'), findsOneWidget);
        expect(find.textContaining('VLESS'), findsNothing);
        expect(find.textContaining('HY2'), findsNothing);
        expect(find.text('线路：2'), findsOneWidget);
        expect(find.text('45 ms'), findsOneWidget);
        final action =
            harness.container.read(proxiesActionProvider.notifier)
                as _RecordingProxies;
        await tester.tap(find.text('香港 Lite A'));
        expect(action.selections, [(group, 'zn.node.hysteria.8')]);
        harness.container.read(groupsProvider.notifier).value = [
          for (final g in harness.container.read(groupsProvider))
            g.name == group ? g.copyWith(now: 'zn.node.vless.7') : g,
        ];
        await tester.pump();
        expect(find.text('286 ms'), findsOneWidget);
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where((widget) => widget.properties.selected == true),
          hasLength(1),
        );
        await tester.tap(find.text('香港 Lite A'));
        expect(action.selections, hasLength(1));
        expect(tester.takeException(), isNull);
        await harness.capture(tester, 'nodes-grouped-${skin.name}');
      },
    );
  }

  for (final mode in [Mode.rule, Mode.global, Mode.direct]) {
    testWidgets(
      'private $mode selects the actual default or global group only',
      (tester) async {
        final group = await preparePrivateBundle(tester, mode: mode);
        final expected = mode == Mode.global ? 'GLOBAL' : group;
        final action =
            harness.container.read(proxiesActionProvider.notifier)
                as _RecordingProxies;
        expect(
          tester.getTopLeft(find.text('45 ms')).dy,
          lessThan(tester.getTopLeft(find.text('286 ms')).dy),
        );
        await tester.tap(find.text(mode == Mode.global ? '美国 原名' : '香港').first);
        await tester.pump();
        expect(action.selections.single.$1, expected);
        expect(
          action.selections.single.$2,
          mode == Mode.global ? 'zn.node.vless.7' : 'zn.node.hysteria.8',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'automatic default is read-only and does not claim manual selection',
    (tester) async {
      await preparePrivateBundle(tester, automatic: true);
      final action =
          harness.container.read(proxiesActionProvider.notifier)
              as _RecordingProxies;
      await tester.tap(find.text('香港').first);
      expect(action.selections, isEmpty);
      expect(find.textContaining('自动选路在此只读'), findsOneWidget);
    },
  );

  testWidgets(
    'measures every physical server without following an automatic default',
    (tester) async {
      await preparePrivateBundle(tester, automatic: true);
      final action =
          harness.container.read(proxiesActionProvider.notifier)
              as _RecordingProxies;
      await tester.pump();

      expect(action.measurements, hasLength(1));
      expect(
        action.measurements.single.$1,
        orderedEquals(
          harness.container
              .read(zolnitSessionProvider)
              .nodeList
              .map((node) => node.proxyName)
              .toList(),
        ),
      );
      expect(action.measurements.single.$2, defaultTestUrl);
      await tester.tap(find.text('延迟测试'));
      await tester.pump();
      expect(action.measurements, hasLength(2));
    },
  );

  testWidgets('stale taps recheck connection, profile and bundle freshness', (
    tester,
  ) async {
    await preparePrivateBundle(tester);
    final action =
        harness.container.read(proxiesActionProvider.notifier)
            as _RecordingProxies;
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.disconnected;
    await tester.tap(find.text('香港').first);
    expect(action.selections, isEmpty);
    await tester.pump();
    expect(find.textContaining('已保存偏好'), findsOneWidget);
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.connected;
    await tester.pump();
    bundleNow = bundleTime(9999);
    await tester.tap(find.text('香港').first);
    expect(action.selections, isEmpty);
    bundleNow = bundleTime(1001);
    (harness.container.read(profilesProvider.notifier) as TestProfiles).replace(
      [],
    );
    await tester.tap(find.text('香港').first);
    expect(action.selections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final (status, message) in [
    (ZolnitBundleStatus.unloaded, '加载中'),
    (ZolnitBundleStatus.loading, '加载中'),
    (ZolnitBundleStatus.unavailable, '连接配置暂时不可用。'),
    (ZolnitBundleStatus.forbidden, '当前账号暂时无法获取连接配置，请检查套餐与流量。'),
    (ZolnitBundleStatus.refreshFailed, '连接配置暂时不可用。'),
    (ZolnitBundleStatus.ready, '加载中'),
  ]) {
    testWidgets('missing bundle $status does not claim empty entitlement', (
      tester,
    ) async {
      harness.container.dispose();
      harness.container = ProviderContainer(
        overrides: [
          zolnitSessionProvider.overrideWithValue(harness.session),
          zolnitClientBundleTransportProvider.overrideWithValue(true),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      globalState.container = harness.container;
      if (status != ZolnitBundleStatus.loading) {
        harness.container.read(zolnitBundleStatusProvider.notifier).set(status);
      }
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: ZolnitNodesPage(
          session: harness.session,
          sync: () async => null,
        ),
      );
      if (status == ZolnitBundleStatus.loading) {
        harness.container.read(zolnitBundleStatusProvider.notifier).set(status);
        await tester.pump();
      }
      expect(find.textContaining(message), findsWidgets);
      expect(find.text('当前套餐暂无可用线路。'), findsNothing);
      expect(find.text('线路：0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final code in [
    'client_api_unavailable',
    'bundle_unavailable',
    'entitlement_unavailable',
  ]) {
    testWidgets(
      'bundle API $code shows the specific failure without requiring a configuration action',
      (tester) async {
        harness.panel = (request) => request.url.path.endsWith('/client/bundle')
            ? http.Response(
                '{"error":{"code":"$code"}}',
                code == 'entitlement_unavailable' ? 403 : 503,
              )
            : zolnitPanelFixture(request);
        await harness.session.refreshClientBundle(coreVersion: 'v1.19.32');
        expect(harness.session.clientBundleFailure, code);
        harness.container.dispose();
        harness.container = ProviderContainer(
          overrides: [
            zolnitSessionProvider.overrideWithValue(harness.session),
            zolnitClientBundleTransportProvider.overrideWithValue(true),
            safeModeProvider.overrideWithValue(true),
          ],
        );
        globalState.container = harness.container;
        var retries = 0;
        await harness.mount(
          tester,
          ZolnitSkin.macos,
          child: ZolnitNodesPage(
            session: harness.session,
            sync: () async {
              retries++;
              return null;
            },
          ),
        );
        expect(
          find.text(
            code == 'entitlement_unavailable'
                ? '当前账号暂时无法获取连接配置，请检查套餐与流量。'
                : '连接配置暂时不可用。',
          ),
          findsWidgets,
        );
        expect(find.text('当前套餐暂无可用线路。'), findsNothing);
        expect(find.text('获取连接配置'), findsNothing);
        expect(retries, 0);
        expect(harness.session.authenticated, isTrue);
      },
    );
  }

  testWidgets('selection skips URL tests and checks selector membership', (
    tester,
  ) async {
    harness.container.updateOverrides([
      zolnitSessionProvider.overrideWithValue(harness.session),
      zolnitSyncProfileProvider.overrideWithValue(() async => null),
      safeModeProvider.overrideWithValue(false),
      profilesProvider.overrideWith(TestProfiles.new),
      proxiesActionProvider.overrideWith(_RecordingProxies.new),
    ]);
    final nodes = harness.session.nodeList;
    final profile = Profile.normal(
      label: zolnitProfileLabel(harness.session),
    ).copyWith(selectedMap: {'Airport': nodes[0].name});
    harness.container.read(profilesProvider.notifier).put(profile);
    harness.container.read(currentProfileIdProvider.notifier).value =
        profile.id;
    harness.container.read(groupsProvider.notifier).value = [
      Group(
        name: 'Automatic',
        type: GroupType.URLTest,
        all: [Proxy(name: nodes[0].name, type: 'ss')],
      ),
      const Group(
        name: 'Unrelated',
        type: GroupType.Selector,
        all: [Proxy(name: 'DIRECT', type: 'Direct')],
      ),
      Group(
        name: 'Airport',
        type: GroupType.Selector,
        all: [
          Proxy(name: nodes[0].name, type: 'ss'),
          Proxy(name: nodes[1].name, type: 'ss'),
        ],
      ),
    ];
    harness.container
        .read(delayDataSourceProvider.notifier)
        .setDelay(
          Delay(
            name: nodes[0].name,
            url: harness.container.read(realTestUrlProvider()),
            value: 42,
          ),
        );
    await harness.mount(tester, ZolnitSkin.macos);
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.connected;
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('已选择'), findsNothing);
    expect(find.text('42 ms'), findsOneWidget);
    final action =
        harness.container.read(proxiesActionProvider.notifier)
            as _RecordingProxies;
    await tester.tap(find.text(nodes[1].title));
    await tester.pump();
    expect(action.selections, [('Airport', nodes[1].name)]);
    await tester.tap(find.text(nodes[2].title));
    await tester.pump();
    expect(action.selections, hasLength(1));
  });

  testWidgets(
    'a foreign profile exposes neither selection nor cached latency',
    (tester) async {
      final node = harness.session.nodeList.first;
      final profile = Profile.normal(
        label: 'Another account',
      ).copyWith(selectedMap: {'Airport': node.name});
      harness.container.read(profilesProvider.notifier).put(profile);
      harness.container.read(currentProfileIdProvider.notifier).value =
          profile.id;
      harness.container.read(groupsProvider.notifier).value = [
        Group(
          name: 'Airport',
          type: GroupType.Selector,
          all: [Proxy(name: node.name, type: 'ss')],
        ),
      ];
      harness.container
          .read(delayDataSourceProvider.notifier)
          .setDelay(
            Delay(
              name: node.name,
              url: harness.container.read(realTestUrlProvider()),
              value: 42,
            ),
          );
      await harness.mount(tester, ZolnitSkin.macos);
      await tester.tap(find.text('全部线路').first);
      await tester.pumpAndSettle();
      expect(find.text('42 ms'), findsNothing);
      expect(find.text('已选择'), findsNothing);
      await tester.tap(find.text(node.title));
      final action =
          harness.container.read(proxiesActionProvider.notifier)
              as _RecordingProxies;
      expect(action.selections, isEmpty);
    },
  );

  testWidgets(
    'entering an initialized client with no profile automatically requests data',
    (tester) async {
      var syncs = 0;
      harness.container.read(initProvider.notifier).value = true;
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: ZolnitNodesPage(
          session: harness.session,
          sync: () async {
            syncs++;
            return null;
          },
        ),
      );
      expect(syncs, 1);
      expect(find.text('获取连接配置'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final skin in ZolnitSkin.values) {
    testWidgets('nodes page renders on ${skin.name}', (tester) async {
      await harness.mount(tester, skin);
      await tester.tap(find.text('全部线路').first);
      await tester.pumpAndSettle();
      expect(find.byType(ZolnitNodesPage), findsOneWidget);
      expect(find.text('全部线路'), findsWidgets);
      expect(find.text('线路'), findsNothing);
      expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsWidgets);
      expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsWidgets);
      await harness.capture(tester, 'nodes-${skin.name}');
    });
  }

  testWidgets('region chip filters to a single region', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('线路：3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zolnit-region-香港')));
    await tester.pumpAndSettle();
    expect(find.text('线路：1'), findsOneWidget);
    expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsWidgets);
    expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsNothing);
  });

  testWidgets('search filters nodes by text', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '\u4e1c\u4eac');
    await tester.pumpAndSettle();
    expect(find.text('线路：1'), findsOneWidget);
    expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsWidgets);
    expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsNothing);
  });

  testWidgets('empty panel shows the no-nodes message', (tester) async {
    harness.panel = zolnitEmptyPanelFixture;
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('当前套餐暂无可用线路。'), findsOneWidget);
    expect(find.text('线路：0'), findsOneWidget);
  });

  testWidgets('no matching nodes message on empty search result', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzznomatch');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的线路。'), findsOneWidget);
    expect(find.text('线路：0'), findsOneWidget);
  });

  testWidgets('dark mode renders without overflow on macOS', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos, dark: true);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('全部线路'), findsWidgets);
    expect(find.text('线路'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.capture(tester, 'nodes-macos-dark');
  });

  testWidgets('320 dp phone with large text scale has no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.mount(tester, ZolnitSkin.ios, size: const Size(320, 640));
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('全部线路'), findsWidgets);
    expect(find.text('线路'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.capture(tester, 'nodes-ios-320-text-scale');
  });

  testWidgets('unknown latency displays em dash', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('\u2014'), findsWidgets);
    expect(find.text('0 ms'), findsNothing);
  });

  testWidgets('card tap without Selector group does not select', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    final selected = find.text('\u5df2\u9009\u62e9');
    expect(selected, findsNothing);
    await tester.tap(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01').first);
    await tester.pumpAndSettle();
    expect(selected, findsNothing);
  });

  testWidgets('delay test button hidden in safe mode', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('\u5ef6\u8fdf\u6d4b\u8bd5'), findsNothing);
  });

  testWidgets('rate multiplier pill renders on cards', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('全部线路').first);
    await tester.pumpAndSettle();
    expect(find.text('1\u00d7 \u8ba1\u91cf'), findsNothing);
    expect(find.text('1.5\u00d7 \u8ba1\u91cf'), findsOneWidget);
  });

  testWidgets(
    'an unmatched profile does not require a manual configuration action',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.macos);
      await tester.tap(find.text('全部线路').first);
      await tester.pumpAndSettle();
      expect(find.text('可用线路会随套餐自动更新。'), findsNothing);
    },
  );

  test('display title strips protocol suffix from real node names', () {
    expect(zolnitDisplayTitle('香港 Lite A · HY2 · 1×'), '香港 Lite A');
    expect(zolnitDisplayTitle('美国 · HY2 · 1×'), '美国');
    expect(zolnitDisplayTitle('香港 · 轻风 01'), '香港 · 轻风 01');
  });

  test('display title strips leading flag when badge renders it', () {
    expect(zolnitDisplayTitle('🇭🇰 香港 Lite A · HY2 · 1×'), '香港 Lite A');
    expect(zolnitDisplayTitle('🇺🇸 美国 · HY2 · 1×'), '美国');
  });

  test('ZolnitNode resolves HK flag and region from explicit emoji', () {
    final node = ZolnitNode.fromJson({
      'id': 1,
      'name': '🇭🇰 香港 Lite A · HY2 · 1×',
    });
    expect(node.countryCode, 'HK');
    expect(node.region, '香港');
    expect(node.flag, isNotNull);
    expect(zolnitDisplayTitle(node.title), '香港 Lite A');
  });

  test('ZolnitNode resolves US flag and region from explicit emoji', () {
    final node = ZolnitNode.fromJson({'id': 2, 'name': '🇺🇸 美国 · HY2 · 1×'});
    expect(node.countryCode, 'US');
    expect(node.region, '美国');
    expect(node.flag, isNotNull);
    expect(zolnitDisplayTitle(node.title), '美国');
  });
}
