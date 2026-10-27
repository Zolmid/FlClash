import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/shell.dart';
import 'package:fl_clash/views/zolnit/native_home.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_native_ui/zolnit_native_ui.dart';

import 'harness.dart';
import '../../helpers/test_profiles.dart';
import '../../helpers/zolnit_return_route_fixture.dart';

class _ReturnCore extends Mock implements CoreHandlerInterface {}

class _ReturnRouteAction extends ProxiesAction {
  final selections = <(String, String)>[];
  @override
  void build() {}
  @override
  Future<void> updateGroups() async {}
  @override
  Future<bool> changeProxyIfCurrent({
    required String groupName,
    required String proxyName,
    required bool Function() isCurrent,
    Map<String, dynamic>? routingLease,
  }) async {
    if (!isCurrent()) return false;
    selections.add((groupName, proxyName));
    return true;
  }
}

Future<Object?> _fromPlatform(String method, [Object? arguments]) {
  const codec = StandardMethodCodec();
  final result = Completer<Object?>();
  ui.channelBuffers.push(
    nativeUiChannelName,
    codec.encodeMethodCall(MethodCall(method, arguments)),
    (data) {
      try {
        result.complete(data == null ? null : codec.decodeEnvelope(data));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    },
  );
  return result.future;
}

void main() {
  registerFallbackValue(<String, dynamic>{});
  const enabled = bool.fromEnvironment('ZOLNIT_NATIVE_UI');
  final harness = ZolnitHarness.register(
    clientPlatform: 'macos',
    distribution: 'direct',
  );
  const macos = TargetPlatformVariant({TargetPlatform.macOS});
  const channel = MethodChannel(nativeUiChannelName);
  var availabilityChecks = 0;
  var navigations = 0;
  var nativeAvailable = false;

  setUp(() {
    availabilityChecks = 0;
    navigations = 0;
    nativeAvailable = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') {
            availabilityChecks++;
            return nativeAvailable;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void allowConnection() {
    harness.container.updateOverrides([
      zolnitSessionProvider.overrideWithValue(harness.session),
      zolnitSyncProfileProvider.overrideWithValue(() async => null),
      safeModeProvider.overrideWithValue(false),
    ]);
  }

  Widget host({
    int destination = 0,
    Future<bool> Function(bool)? onConnection,
  }) => ZolnitNativeHome(
    session: harness.session,
    destination: destination,
    preferencesVisible: false,
    onConnection: onConnection ?? (_) async => true,
    onNavigate: (_) => navigations++,
    onRefresh: () async {},
    onPreferences: () {},
    onHelp: () async {},
    child: const Text('existing destination'),
  );

  Future<(NativeUiSnapshot, Profile)> mountReturnFixture(
    WidgetTester tester,
    Map<String, dynamic> raw,
  ) async {
    final effective = returnDispatchFixture(source: raw);
    harness.panel = (request) => request.url.path.endsWith('/client/bundle')
        ? zolnitJson(effective)
        : zolnitPanelFixture(request);
    await tester.runAsync(
      () => harness.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => DateTime.fromMillisecondsSinceEpoch(1001000, isUtc: true),
      ),
    );
    final profile = Profile(
      id: 1,
      autoUpdateDuration: Duration.zero,
      zolnitAccountId: 'account-1',
      zolnitBundleId: harness.session.clientBundle!.bundleId,
      zolnitOrigin: harness.session.api.origin.origin,
    );
    final core = _ReturnCore();
    when(core.getClientBundleOwner).thenAnswer(
      (_) async => {
        'returnRouteGuard': {
          'instanceId': 'fixture-core',
          'token': 'fixture-return',
          'configurationGeneration': 1,
          'accountId': harness.session.clientBundle!.accountId,
          'accountGeneration': harness.session.api.generation,
          'bundleId': harness.session.clientBundle!.bundleId,
        },
      },
    );
    harness.container.dispose();
    harness.container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        zolnitSessionProvider.overrideWithValue(harness.session),
        zolnitSyncProfileProvider.overrideWithValue(() async => null),
        safeModeProvider.overrideWithValue(false),
        zolnitClientBundleTransportProvider.overrideWithValue(true),
        zolnitBundleClockProvider.overrideWithValue(
          () => DateTime.fromMillisecondsSinceEpoch(1001000, isUtc: true),
        ),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        proxiesActionProvider.overrideWith(_ReturnRouteAction.new),
      ],
    );
    globalState.container = harness.container;
    harness.container.read(groupsProvider.notifier).value =
        returnDispatchCoreGroups(effective, active: true);
    when(() => core.setClientReturnRoute(any())).thenAnswer((invocation) async {
      final args =
          invocation.positionalArguments.single as Map<String, dynamic>;
      final route = ZolnitReturnRoute.resolve(
        harness.session.clientBundle!,
        harness.container.read(groupsProvider),
      )!;
      final enabled = args['enabled'] as bool;
      final option = route.options
          .where((o) => o.id == args['optionId'])
          .firstOrNull;
      final selections = <String, String>{
        for (final d in route.dispatches)
          d.groupName: enabled ? d.returnTarget : d.localTarget,
        if (enabled) route.group: option!.target,
      };
      final action =
          harness.container.read(proxiesActionProvider.notifier)
              as _ReturnRouteAction;
      action.selections.addAll(selections.entries.map((e) => (e.key, e.value)));
      harness.container.read(groupsProvider.notifier).value = [
        for (final group in harness.container.read(groupsProvider))
          group.copyWith(now: selections[group.name] ?? group.now),
      ];
      return {
        'enabled': enabled,
        'selectedId': option?.id,
        'selections': selections,
      };
    });
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.connected;
    await harness.mount(tester, ZolnitSkin.macos, child: host());
    final snapshot = NativeUiSnapshot.decode(
      await _fromPlatform('getSnapshot') as String,
    );
    return (snapshot, profile);
  }

  testWidgets(
    'native return roles dispatch exact Core aliases and hide aliases from snapshots',
    (tester) async {
      final raw = returnRouteFixture();
      final (snapshot, _) = await mountReturnFixture(tester, raw);
      expect(
        jsonEncode(snapshot.toJson()['returnRoute']),
        isNot(contains('zn.group.')),
      );
      expect(snapshot.toJson()['returnRoute']['options'], hasLength(3));
      final mapping = (raw['routing']['ui_groups'] as List).single;
      for (final option in mapping['options'] as List) {
        final response =
            jsonDecode(
                  await _fromPlatform(
                        'performCommand',
                        jsonEncode({
                          'schemaVersion': 1,
                          'id': 'route-${option['id']}',
                          'accountGeneration': snapshot.accountGeneration,
                          'action': 'selectReturnRoute',
                          'payload': {'optionId': option['id']},
                        }),
                      )
                      as String,
                )
                as Map;
        expect(response['accepted'], isTrue);
        final owner =
            harness.container.read(proxiesActionProvider.notifier)
                as _ReturnRouteAction;
        expect(owner.selections.last, (mapping['group'], option['target']));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'native restricted graph hides unusable roles and rejects a pre-downgrade command',
    (tester) async {
      final raw = returnRouteAvailabilityFixture();
      final (snapshot, profile) = await mountReturnFixture(tester, raw);
      expect(
        jsonEncode(snapshot.toJson()['returnRoute']),
        isNot(contains('zn.group.')),
      );
      expect(snapshot.toJson()['returnRoute']['options'], hasLength(3));
      final restricted = returnRouteAvailabilityFixture(
        restricted: true,
        bundleId: 'downgraded',
      );
      harness.panel = (request) => request.url.path.endsWith('/client/bundle')
          ? zolnitJson(restricted)
          : zolnitPanelFixture(request);
      await tester.runAsync(
        () => harness.session.refreshClientBundle(
          coreVersion: 'v1.19.32',
          clock: () =>
              DateTime.fromMillisecondsSinceEpoch(1001000, isUtc: true),
        ),
      );
      harness.container
          .read(profilesProvider.notifier)
          .put(
            profile.copyWith(
              zolnitBundleId: harness.session.clientBundle!.bundleId,
            ),
          );
      final mapping = (restricted['routing']['ui_groups'] as List).single;
      final usableTarget = mapping['options'][1]['target'] as String;
      harness.container.read(groupsProvider.notifier).value = [
        for (final group in returnRouteCoreGroups(restricted))
          group.name == mapping['group']
              ? group.copyWith(now: usableTarget)
              : group,
      ];
      final response =
          jsonDecode(
                await _fromPlatform(
                      'performCommand',
                      jsonEncode({
                        'schemaVersion': 1,
                        'id': 'old-return-menu',
                        'accountGeneration': snapshot.accountGeneration,
                        'action': 'selectReturnRoute',
                        'payload': {'optionId': 'hk_optimized'},
                      }),
                    )
                    as String,
              )
              as Map;
      expect(response['accepted'], isFalse);
      expect(
        (harness.container.read(proxiesActionProvider.notifier)
                as _ReturnRouteAction)
            .selections,
        isEmpty,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      final updated = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      );
      expect(updated.toJson()['returnRoute']['selectedId'], 'hk_lite');
      expect(
        (updated.toJson()['returnRoute']['options'] as List).map(
          (item) => item['id'],
        ),
        ['hk_lite'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'safe mode keeps unknown data and never reports a connection',
    (tester) async {
      harness.panel = (request) => request.url.path.endsWith('/getSubscribe')
          ? zolnitJson({'plan_id': 1, 'u': null, 'd': 0})
          : zolnitPanelFixture(request);
      await harness.relogin();
      harness.container.read(coreStatusProvider.notifier).value =
          CoreStatus.connecting;
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      final snapshot = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      ).toJson();
      expect(snapshot['usage']['usedBytes'], isNull);
      expect(snapshot['usage']['totalBytes'], isNull);
      expect(snapshot['traffic']['uploadBps'], isNull);
      expect(snapshot['traffic']['downloadBps'], isNull);
      expect(snapshot['connectionState'], 'disconnected');
      expect(snapshot['safeMode'], isTrue);
      expect(snapshot['labels']['safeMode'], '安全模式不会修改系统网络。');
      expect(find.text('existing destination'), findsNothing);
      expect(find.text('连接页面暂时无法显示，请重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'native status follows run lifecycle rather than the core process',
    (tester) async {
      allowConnection();
      final coreHold = harness.container.listen(coreStatusProvider, (_, _) {});
      final runHold = harness.container.listen(runTimeProvider, (_, _) {});
      addTearDown(coreHold.close);
      addTearDown(runHold.close);
      harness.container.read(coreStatusProvider.notifier).value =
          CoreStatus.connected;
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      Future<Map<String, dynamic>> snapshot() async => NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      ).toJson();
      expect((await snapshot())['connectionState'], 'disconnected');
      harness.container.read(runTimeProvider.notifier).value = 1;
      await tester.pumpAndSettle();
      expect((await snapshot())['connectionState'], 'connected');
      harness.container.read(runTimeProvider.notifier).value = null;
      harness.container.read(coreStatusProvider.notifier).value =
          CoreStatus.connecting;
      await tester.pumpAndSettle();
      expect((await snapshot())['connectionState'], 'disconnected');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'normal disconnect retains transition state until its receipt',
    (tester) async {
      allowConnection();
      final runHold = harness.container.listen(runTimeProvider, (_, _) {});
      addTearDown(runHold.close);
      harness.container.read(runTimeProvider.notifier).value = 1;
      final completed = Completer<bool>();
      bool? desired;
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: host(
          onConnection: (value) {
            desired = value;
            return completed.future;
          },
        ),
      );
      final snapshot = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      );
      final reply = _fromPlatform(
        'performCommand',
        jsonEncode({
          'schemaVersion': 1,
          'id': 'normal-disconnect',
          'accountGeneration': snapshot.accountGeneration,
          'action': 'disconnect',
          'payload': <String, String>{},
        }),
      );
      await tester.pump();
      expect(desired, isFalse);
      final pending = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      ).toJson();
      expect(pending['connectionState'], 'disconnecting');
      harness.container.read(runTimeProvider.notifier).value = null;
      completed.complete(true);
      await tester.pumpAndSettle();
      expect((jsonDecode(await reply as String) as Map)['accepted'], isTrue);
      final stopped = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      ).toJson();
      expect(stopped['connectionState'], 'disconnected');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'Mac native content stays inside one shared shell across navigation',
    (tester) async {
      nativeAvailable = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform_views,
            (_) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
      await harness.mount(tester, ZolnitSkin.macos);
      final sidebar = find.byType(ZolnitSidebar);
      expect(sidebar, findsOneWidget);
      expect(find.byType(ZolnitTopBar), findsOneWidget);
      expect(find.byType(AppKitView), findsOneWidget);
      final nativeBounds = tester.getRect(find.byType(AppKitView));
      expect(
        nativeBounds.left,
        greaterThanOrEqualTo(tester.getRect(sidebar).right),
      );
      expect(
        nativeBounds.top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ZolnitTopBar)).bottom),
      );
      for (final label in ['全部线路', '套餐', '账号', '连接']) {
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        expect(sidebar, findsOneWidget);
        expect(find.byType(ZolnitTopBar), findsOneWidget);
        expect(
          find.byType(AppKitView),
          label == '连接' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(
        find.descendant(of: sidebar, matching: find.text('偏好设置')),
      );
      await tester.pumpAndSettle();
      expect(sidebar, findsOneWidget);
      expect(find.byType(ZolnitTopBar), findsOneWidget);
      expect(find.byType(AppKitView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'native command cannot cross logout before the next frame',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      final snapshot = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      );
      await harness.session.logout();
      final reply =
          jsonDecode(
                await _fromPlatform(
                      'performCommand',
                      jsonEncode({
                        'schemaVersion': 1,
                        'id': 'preceding-account',
                        'accountGeneration': snapshot.accountGeneration,
                        'action': 'navigate',
                        'payload': {'destination': 'account'},
                      }),
                    )
                    as String,
              )
              as Map;
      expect(reply['errorCode'], 'stale_account');
      expect(navigations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'unavailable native connection page retries explicitly',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      expect(availabilityChecks, 1);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(availabilityChecks, 2);
      expect(find.text('existing destination'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'other destinations keep their existing content',
    (tester) async {
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: host(destination: 1),
      );
      expect(find.text('existing destination'), findsOneWidget);
      expect(find.text('连接页面暂时无法显示，请重试。'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );
}
