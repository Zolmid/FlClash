import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/nodes.dart';
import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';
import '../../helpers/test_profiles.dart';

class _RecordingProxies extends ProxiesAction {
  final selections = <(String, String)>[];

  @override
  void build() {}

  @override
  Future<void> delayTestPageGroup(
    String groupName, {
    bool matchSearch = true,
  }) async {}

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
