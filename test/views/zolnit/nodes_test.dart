import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/views/zolnit/nodes.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';
import '../../helpers/test_profiles.dart';

class _RecordingProxies extends ProxiesAction {
  final selections = <(String, String)>[];

  @override
  void build() {}

  @override
  void changeProxyDebounce(String groupName, String proxyName) {
    selections.add((groupName, proxyName));
  }
}

void main() {
  final harness = ZolnitHarness.register(
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      proxiesActionProvider.overrideWith(_RecordingProxies.new),
    ],
  );

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
    await tester.tap(find.text('节点').first);
    await tester.pumpAndSettle();
    expect(find.text('已选择'), findsOneWidget);
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
      await tester.tap(find.text('节点').first);
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
    'sync failures release the single-flight action and show a retryable error',
    (tester) async {
      final pending = Completer<int?>();
      var syncs = 0;
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: ZolnitNodesPage(
          session: harness.session,
          sync: () {
            syncs++;
            return pending.future;
          },
        ),
      );
      final hint = find.text('同步订阅后，选择配置中的节点。');
      await tester.tap(hint);
      await tester.pump();
      await tester.tap(hint);
      expect(syncs, 1);
      pending.completeError(StateError('failed fixture'));
      await tester.pumpAndSettle();
      expect(find.text('操作未完成，请检查输入或网络后重试。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final skin in ZolnitSkin.values) {
    testWidgets('nodes page renders on ${skin.name}', (tester) async {
      await harness.mount(tester, skin);
      await tester.tap(find.text('\u8282\u70b9').first);
      await tester.pumpAndSettle();
      expect(find.byType(ZolnitNodesPage), findsOneWidget);
      expect(
        find.text(
          '\u4f60\u7684\u4e16\u754c\uff0c\u4ece\u8fd9\u91cc\u51fa\u53d1\u3002',
        ),
        findsOneWidget,
      );
      expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsWidgets);
      expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsWidgets);
      await harness.capture(tester, 'nodes-${skin.name}');
    });
  }

  testWidgets('region chip filters to a single region', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(find.text('3 \u4e2a\u8282\u70b9'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zolnit-region-香港')));
    await tester.pumpAndSettle();
    expect(find.text('1 \u4e2a\u8282\u70b9'), findsOneWidget);
    expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsWidgets);
    expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsNothing);
  });

  testWidgets('search filters nodes by text', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '\u4e1c\u4eac');
    await tester.pumpAndSettle();
    expect(find.text('1 \u4e2a\u8282\u70b9'), findsOneWidget);
    expect(find.text('\u65e5\u672c \u00b7 \u4e1c\u4eac 01'), findsWidgets);
    expect(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01'), findsNothing);
  });

  testWidgets('empty panel shows the no-nodes message', (tester) async {
    harness.panel = zolnitEmptyPanelFixture;
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u5f53\u524d\u8ba2\u9605\u6682\u65e0\u53ef\u7528\u8282\u70b9\u3002',
      ),
      findsOneWidget,
    );
    expect(find.text('0 \u4e2a\u8282\u70b9'), findsOneWidget);
  });

  testWidgets('no matching nodes message on empty search result', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzznomatch');
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u6ca1\u6709\u5339\u914d\u7684\u8282\u70b9\uff0c\u8bd5\u8bd5\u5176\u4ed6\u5173\u952e\u8bcd\u6216\u5730\u533a\u3002',
      ),
      findsOneWidget,
    );
    expect(find.text('0 \u4e2a\u8282\u70b9'), findsOneWidget);
  });

  testWidgets('dark mode renders without overflow on macOS', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos, dark: true);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u4f60\u7684\u4e16\u754c\uff0c\u4ece\u8fd9\u91cc\u51fa\u53d1\u3002',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.capture(tester, 'nodes-macos-dark');
  });

  testWidgets('320 dp phone with large text scale has no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await harness.mount(tester, ZolnitSkin.ios, size: const Size(320, 640));
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u4f60\u7684\u4e16\u754c\uff0c\u4ece\u8fd9\u91cc\u51fa\u53d1\u3002',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.capture(tester, 'nodes-ios-320-text-scale');
  });

  testWidgets('unknown latency displays em dash', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(find.text('\u2014'), findsWidgets);
    expect(find.text('0 ms'), findsNothing);
  });

  testWidgets('card tap without Selector group does not select', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    final selected = find.text('\u5df2\u9009\u62e9');
    expect(selected, findsNothing);
    await tester.tap(find.text('\u9999\u6e2f \u00b7 \u8f7b\u98ce 01').first);
    await tester.pumpAndSettle();
    expect(selected, findsNothing);
  });

  testWidgets('delay test button hidden in safe mode', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(find.text('\u5ef6\u8fdf\u6d4b\u8bd5'), findsNothing);
  });

  testWidgets('rate multiplier pill renders on cards', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(find.text('1\u00d7 \u8ba1\u91cf'), findsWidgets);
    expect(find.text('1.5\u00d7 \u8ba1\u91cf'), findsOneWidget);
  });

  testWidgets('sync hint visible when profile not matched', (tester) async {
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('\u8282\u70b9').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u540c\u6b65\u8ba2\u9605\u540e\uff0c\u9009\u62e9\u914d\u7f6e\u4e2d\u7684\u8282\u70b9\u3002',
      ),
      findsOneWidget,
    );
  });
}
