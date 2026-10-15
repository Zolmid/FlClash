import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/manager/vpn_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RestartRecordingSetupAction extends SetupAction {
  int restarts = 0;

  @override
  Future<void> restartVpn() async {
    restarts++;
  }
}

void main() {
  late ProviderContainer container;
  late _RestartRecordingSetupAction setupAction;

  setUp(() {
    setupAction = _RestartRecordingSetupAction();
    container = ProviderContainer(
      overrides: [
        setupActionProvider.overrideWith(() => setupAction),
        // Bypassing private addresses computes the routes in Isolate.run, which
        // the fake clock never lets finish.
        networkSettingProvider.overrideWithBuild(
          (_, _) => const NetworkProps(bypassPrivateRoute: false),
        ),
      ],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpVpnManager(
    WidgetTester tester, {
    Service? mobileService,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (_, child) {
            return StatusManager(
              child: mobileService == null
                  ? VpnManager(child: child!)
                  : VpnManager.forTesting(
                      mobileService: mobileService,
                      isAndroid: true,
                      child: child!,
                    ),
            );
          },
          home: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> outlastTip(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> drainTimers(WidgetTester tester) async {
    await outlastTip(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  void startService() {
    container.read(runningVpnOptionsProvider.notifier).value = container
        .read(vpnOptionsProvider)
        .requireValue;
  }

  void updateVpn(VpnProps Function(VpnProps state) update) {
    container.read(vpnSettingProvider.notifier).update(update);
  }

  Finder tip() => find.text(currentAppLocalizations.vpnConfigChangeDetected);

  group('Android native run state refresh', () {
    const channel = MethodChannel('$packageName/service');
    const codec = StandardMethodCodec();
    late Service mobileService;
    late List<String> reads;
    VpnOptions? nativeActive;
    VpnOptions? nativeRequested;

    setUp(() {
      mobileService = Service.forTesting(isIOS: false);
      reads = [];
      nativeActive = null;
      nativeRequested = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            reads.add(call.method);
            final options = switch (call.method) {
              'getActiveVpnOptions' => nativeActive,
              'getRequestedVpnOptions' => nativeRequested,
              _ => throw UnimplementedError(call.method),
            };
            return options == null ? null : json.encode(options);
          });
    });

    tearDown(() {
      mobileService.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> connected() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            codec.encodeMethodCall(
              const MethodCall('tunnelState', 'connected'),
            ),
            null,
          );
    }

    testWidgets(
      'connected rereads a null startup snapshot after desired changes',
      (tester) async {
        await pumpVpnManager(tester, mobileService: mobileService);
        final startedWith = await container.read(vpnOptionsProvider.future);
        container.read(runTimeProvider.notifier).value = 1234;
        await settle(tester);
        expect(reads, contains('getActiveVpnOptions'));
        expect(container.read(runningVpnOptionsProvider), isNull);

        updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
        await settle(tester);
        expect(tip(), findsNothing);
        reads.clear();

        nativeActive = startedWith;
        nativeRequested = startedWith;
        await connected();
        await settle(tester);

        expect(reads, ['getActiveVpnOptions', 'getRequestedVpnOptions']);
        expect(container.read(runningVpnOptionsProvider), startedWith);
        expect(tip(), findsOneWidget);
        await drainTimers(tester);
      },
    );

    testWidgets(
      'records actual fallback but compares the native requested options',
      (tester) async {
        container
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(
                tun: state.tun.copyWith(stack: TunStack.mixed),
              ),
            );
        await pumpVpnManager(tester, mobileService: mobileService);
        final requested = await container.read(vpnOptionsProvider.future);
        nativeRequested = requested;
        nativeActive = requested.copyWith(stack: 'gvisor');
        container.read(runTimeProvider.notifier).value = 1234;
        await connected();
        await settle(tester);

        expect(container.read(runningVpnOptionsProvider), nativeActive);
        expect(tip(), findsNothing);

        updateVpn(
          (state) => state.copyWith(
            accessControlProps: state.accessControlProps.copyWith(
              sort: AccessSortType.name,
            ),
          ),
        );
        await settle(tester);
        expect(tip(), findsNothing);
        await drainTimers(tester);
      },
    );
  });

  testWidgets('a change the running service reads asks for a restart', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    startService();

    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);
    expect(tip(), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(currentAppLocalizations.restart));
    await tester.pump();
    expect(setupAction.restarts, 1);
    await drainTimers(tester);
  });

  testWidgets('a mixed port change asks for a restart under a system proxy', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    startService();

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mixedPort: state.mixedPort + 1));
    await settle(tester);

    expect(tip(), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('a route change asks once its routes are computed', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    startService();

    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            tun: state.tun.copyWith(routeAddress: const ['10.0.0.0/8']),
          ),
        );
    await tester.pump();
    expect(container.read(vpnOptionsProvider).isLoading, isTrue);
    expect(tip(), findsNothing);

    for (var i = 0; i < 100 && tip().evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(tip(), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('no tip while no service is running', (tester) async {
    await pumpVpnManager(tester);

    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);

    expect(tip(), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('no tip for what the service never reads', (tester) async {
    await pumpVpnManager(tester);
    startService();

    updateVpn(
      (state) => state.copyWith(
        accessControlProps: state.accessControlProps.copyWith(
          sort: AccessSortType.name,
          isFilterSystemApp: !state.accessControlProps.isFilterSystemApp,
        ),
      ),
    );
    await settle(tester);

    expect(tip(), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('changing back to what the service runs asks for nothing', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    startService();

    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);
    expect(tip(), findsOneWidget);
    await outlastTip(tester);
    expect(tip(), findsNothing);

    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);

    expect(tip(), findsNothing);
    await drainTimers(tester);
  });

  testWidgets('a restart measures later changes against the new options', (
    tester,
  ) async {
    await pumpVpnManager(tester);
    startService();
    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);
    await outlastTip(tester);
    expect(tip(), findsNothing);

    startService();
    updateVpn((state) => state.copyWith(ipv6: !state.ipv6));
    await settle(tester);

    expect(tip(), findsOneWidget);
    await drainTimers(tester);
  });
}
