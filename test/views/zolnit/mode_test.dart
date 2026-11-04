import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/core_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_connection.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/connect.dart';
import 'package:fl_clash/views/zolnit/connect_art.dart';
import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_profiles.dart';
import 'harness.dart';

class _ModeCore extends Mock implements CoreHandlerInterface {}

void main() {
  final harness = ZolnitHarness.register();
  late _ModeCore core;
  late Completer<String> reply;
  late ProviderContainer container;
  final calls = <UpdateParams>[];
  var openedNodes = 0;
  var connectionRequests = 0;
  var phase = ZolnitConnectionPhase.disconnected;

  setUpAll(() {
    registerFallbackValue(
      const PatchClashConfig().toUpdateParams(
        authentication: [],
        skipCertVerify: false,
      ),
    );
  });

  setUp(() {
    core = _ModeCore();
    calls.clear();
    openedNodes = 0;
    connectionRequests = 0;
    phase = ZolnitConnectionPhase.disconnected;
    when(core.startLog).thenAnswer((_) {});
    when(core.stopLog).thenAnswer((_) {});
    when(() => core.updateConfig(any())).thenAnswer((invocation) {
      calls.add(invocation.positionalArguments.single as UpdateParams);
      return reply.future;
    });
    final profile = Profile.normal(label: zolnitProfileLabel(harness.session));
    harness.container.dispose();
    container = harness.container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(harness.session),
        zolnitSyncProfileProvider.overrideWithValue(() async => null),
        zolnitClientBundleTransportProvider.overrideWithValue(false),
        zolnitConnectionPhaseProvider.overrideWith((ref) => phase),
        safeModeProvider.overrideWithValue(false),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
      ],
    );
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(groupsProvider.notifier).value = [
      Group(
        name: 'Airport',
        type: GroupType.Selector,
        all: [Proxy(name: harness.session.nodeList.first.name, type: 'ss')],
      ),
    ];
  });

  tearDown(() {
    if (!reply.isCompleted) reply.complete('config is not applied');
  });

  Future<void> mount(WidgetTester tester, {bool syncing = false}) async {
    reply = Completer<String>();
    await harness.mount(
      tester,
      ZolnitSkin.macos,
      child: CoreManager(
        child: ZolnitConnectPage(
          session: harness.session,
          compact: false,
          syncing: syncing,
          syncFailed: false,
          connect: () async {
            connectionRequests++;
          },
          openNodes: () => openedNodes++,
          openPlans: () {},
        ),
      ),
    );
  }

  Mode? displayed(WidgetTester tester) => tester
      .widget<ZolnitSegmented<Mode>>(find.byType(ZolnitSegmented<Mode>))
      .value;

  for (final state in [
    ZolnitConnectionPhase.unavailable,
    ZolnitConnectionPhase.connecting,
  ]) {
    testWidgets(
      'active VPN can disconnect during $state without a connected claim',
      (tester) async {
        phase = state;
        container.read(runTimeProvider.notifier).value = 1;
        await mount(tester, syncing: state == ZolnitConnectionPhase.connecting);
        expect(find.text('已连接'), findsNothing);
        final power = tester.widget<ZolnitPowerButton>(
          find.byType(ZolnitPowerButton),
        );
        expect(power.onPressed, isNotNull);
        expect(power.label, '断开连接');
        await tester.tap(find.byType(ZolnitPowerButton));
        await tester.pump();
        expect(connectionRequests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('confirmed connection has one status and a disconnect action', (
    tester,
  ) async {
    phase = ZolnitConnectionPhase.connected;
    container.read(runTimeProvider.notifier).value = 1;
    await mount(tester);
    expect(find.text('已连接'), findsOneWidget);
    expect(
      tester.widget<ZolnitPowerButton>(find.byType(ZolnitPowerButton)).label,
      '断开连接',
    );
  });

  for (final throwsError in [false, true]) {
    testWidgets(
      'failed mode tap retains selection and gives recovery (throw=$throwsError)',
      (tester) async {
        await mount(tester);
        await tester.tap(find.text('全局模式'));
        await tester.pump();
        expect(calls, hasLength(1));
        expect(displayed(tester), Mode.rule);
        if (throwsError) {
          reply.completeError(StateError('config is not applied'));
        } else {
          reply.complete('config is not applied');
        }
        await tester.pumpAndSettle();
        expect(displayed(tester), Mode.rule);
        expect(find.text('无法应用连接模式。请刷新连接配置后重试。'), findsOneWidget);
        expect(find.textContaining('config is not applied'), findsNothing);
        await tester.tap(find.text('获取连接配置'));
        expect(openedNodes, 1);
        expect(tester.takeException(), isNull);
        expect(calls, hasLength(1));
      },
    );
  }

  testWidgets('accepted mode is committed once with CoreManager mounted', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('全局模式'));
    await tester.pump();
    expect(displayed(tester), Mode.rule);
    reply.complete('');
    await tester.pumpAndSettle();
    expect(displayed(tester), Mode.global);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, hasLength(1));
    expect(calls.single.mode, Mode.global);
    expect(find.byKey(const ValueKey('zolnit-mode-failure')), findsNothing);
  });

  testWidgets('failed mode does not roll back another setting', (tester) async {
    await mount(tester);
    await tester.tap(find.text('全局模式'));
    await tester.pump();
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(ipv6: !state.ipv6));
    final ipv6 = container.read(patchClashConfigProvider).ipv6;
    reply.complete('config is not applied');
    await tester.pump();
    expect(displayed(tester), Mode.rule);
    expect(container.read(patchClashConfigProvider).ipv6, ipv6);
    when(() => core.updateConfig(any())).thenAnswer((_) async => '');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  for (final race in ['restart', 'profile', 'logout', 'dispose']) {
    testWidgets('late mode success cannot cross $race', (tester) async {
      await mount(tester);
      await tester.tap(find.text('全局模式'));
      await tester.pump();
      switch (race) {
        case 'restart':
          container.read(coreStatusProvider.notifier).value =
              CoreStatus.connecting;
          container.read(coreStatusProvider.notifier).value =
              CoreStatus.connected;
        case 'profile':
          await tester.pumpWidget(const SizedBox.shrink());
          container.read(currentProfileIdProvider.notifier).value = null;
        case 'logout':
          await harness.session.logout();
        case 'dispose':
          await tester.pumpWidget(const SizedBox.shrink());
      }
      reply.complete('');
      await tester.pumpAndSettle();
      expect(container.read(patchClashConfigProvider).mode, Mode.rule);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'stale enabled callback rechecks readiness before issuing a command',
    (tester) async {
      await mount(tester);
      final callback = tester
          .widget<ZolnitSegmented<Mode>>(find.byType(ZolnitSegmented<Mode>))
          .onChanged!;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      callback(Mode.global);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(displayed(tester), isNull);
      expect(container.read(patchClashConfigProvider).mode, Mode.rule);
      expect(find.byKey(const ValueKey('zolnit-mode-failure')), findsOneWidget);
    },
  );

  testWidgets('syncing mode control cannot change preferences', (tester) async {
    await mount(tester, syncing: true);
    final control = tester.widget<ZolnitSegmented<Mode>>(
      find.byType(ZolnitSegmented<Mode>),
    );
    expect(control.onChanged, isNull);
    expect(control.value, isNull);
    await tester.tap(find.text('全局模式'));
    await tester.pump();
    expect(calls, isEmpty);
    expect(container.read(patchClashConfigProvider).mode, Mode.rule);
  });
}
