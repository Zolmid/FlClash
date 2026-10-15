import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/on_demand.dart';
import 'package:fl_clash/views/dashboard/widgets/start_button.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'com.follow.clash',
      version: '0.0.0',
      buildNumber: '1',
    );
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpView(WidgetTester tester, Widget child) async {
    const size = Size(1400, 3200);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'iOS keeps startup and SSID controls and hides unavailable settings',
    (tester) async {
      await pumpView(tester, const GeneralView(platform: SupportPlatform.IOS));
      final l = currentAppLocalizations;

      expect(find.text(l.autoRun), findsOneWidget);
      expect(find.text(l.onDemand), findsOneWidget);
      for (final title in [
        l.autoLaunch,
        l.silentLaunch,
        l.minimizeOnExit,
        l.findProcessMode,
        l.autoCheckUpdate,
        l.appendSystemDns,
        l.showNotificationStopAction,
      ]) {
        expect(find.text(title), findsNothing);
      }

      await tester.tap(find.text(l.onDemand));
      await tester.pumpAndSettle();
      expect(find.byType(OnDemandView), findsOneWidget);
      expect(find.text(l.excludeSsids), findsOneWidget);
      expect(find.text(l.ignoreBatteryOptimization), findsNothing);
      expect(find.text(l.locationPermission), findsNothing);
    },
  );

  testWidgets('Android retains its existing general settings', (tester) async {
    await pumpView(
      tester,
      const GeneralView(platform: SupportPlatform.Android),
    );
    final l = currentAppLocalizations;

    expect(find.text(l.minimizeOnExit), findsOneWidget);
    expect(find.text(l.findProcessMode), findsOneWidget);
    expect(find.text(l.autoCheckUpdate), findsOneWidget);
    expect(find.text(l.appendSystemDns), findsOneWidget);
    expect(find.text(l.showNotificationStopAction), findsOneWidget);
  });

  testWidgets(
    'iOS VPN settings change the native options without a VPN toggle',
    (tester) async {
      await pumpView(
        tester,
        const Scaffold(body: VpnSections(isAndroid: false)),
      );

      expect(find.byType(VPNItem), findsNothing);
      expect(find.byType(AllowBypassItem), findsNothing);
      expect(find.byType(VpnSystemProxyItem), findsOneWidget);
      expect(find.byType(BypassDomainItem), findsOneWidget);
      for (final (type, read) in <(Type, bool Function())>[
        (Ipv6Item, () => container.read(vpnSettingProvider).ipv6),
        (
          DNSHijackingItem,
          () => container.read(vpnSettingProvider).dnsHijacking,
        ),
      ]) {
        final initial = read();
        final toggle = find.descendant(
          of: find.byType(type),
          matching: find.byType(Switch),
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(read(), !initial);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(read(), initial);
      }
    },
  );

  testWidgets('Android keeps the optional VPN and allow bypass controls', (
    tester,
  ) async {
    await pumpView(tester, const Scaffold(body: VpnSections(isAndroid: true)));

    expect(find.byType(VPNItem), findsOneWidget);
    expect(find.byType(AllowBypassItem), findsOneWidget);
  });

  testWidgets('iOS about shows its version without an unsupported updater', (
    tester,
  ) async {
    await pumpView(tester, const AboutView(platform: SupportPlatform.IOS));

    expect(find.text('v0.0.0'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text(currentAppLocalizations.checkUpdate), findsNothing);
  });

  for (final result in [TunnelState.connected, TunnelState.disconnected]) {
    testWidgets('tunnel pending prevents repeat starts and clears on $result', (
      tester,
    ) async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWithValue([
            const Profile(id: 1, autoUpdateDuration: Duration.zero),
          ]),
          suspendProvider.overrideWithValue(false),
          tunnelStateProvider.overrideWithValue(TunnelState.pending),
        ],
      );
      globalState.container = container;
      await pumpView(
        tester,
        const Scaffold(floatingActionButton: StartButton()),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final button = find.byType(FloatingActionButton);
      expect(tester.widget<FloatingActionButton>(button).onPressed, isNull);
      expect(find.byType(CommonCircleLoading), findsOneWidget);
      expect(
        find.byTooltip(currentAppLocalizations.connecting),
        findsOneWidget,
      );

      container.updateOverrides([
        profilesProvider.overrideWithValue([
          const Profile(id: 1, autoUpdateDuration: Duration.zero),
        ]),
        suspendProvider.overrideWithValue(false),
        tunnelStateProvider.overrideWithValue(result),
      ]);
      await tester.pumpAndSettle();

      expect(tester.widget<FloatingActionButton>(button).onPressed, isNotNull);
      expect(find.byType(CommonCircleLoading), findsNothing);
    });
  }
}
