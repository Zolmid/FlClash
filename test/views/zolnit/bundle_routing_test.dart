import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_routing.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/bundle_routing.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../packages/zolnit_client/test/client_bundle_fixture.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _Recording extends ProxiesAction {
  final selections = <(String, String)>[];
  @override
  void build() {}
  @override
  void changeProxyDebounce(String groupName, String proxyName) =>
      selections.add((groupName, proxyName));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClientBundleSessionFixture fixture;
  late ProviderContainer container;
  late DateTime now;
  late Profile profile;

  setUp(() async {
    fixture = ClientBundleSessionFixture();
    now = bundleTime(1001);
    await fixture.login();
    await fixture.session.refreshClientBundle(
      coreVersion: 'v1.19.32',
      clock: () => now,
    );
    profile = Profile(
      id: 1,
      label: 'arbitrary display label',
      autoUpdateDuration: Duration.zero,
      zolnitAccountId: 'account-1',
      zolnitBundleId: fixture.session.clientBundle!.bundleId,
      zolnitOrigin: fixture.api.origin.origin,
    );
    container = ProviderContainer(
      overrides: [
        zolnitClientBundleTransportProvider.overrideWithValue(true),
        zolnitCoreLeaseReadyProvider.overrideWithBuild((_, _) => true),
        zolnitClientBundleAutomaticProvider.overrideWithValue(true),
        zolnitBundleClockProvider.overrideWithValue(() => now),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        safeModeProvider.overrideWithValue(false),
        proxiesActionProvider.overrideWith(_Recording.new),
      ],
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container
        .read(zolnitBundleStatusProvider.notifier)
        .set(ZolnitBundleStatus.ready);
    container.read(groupsProvider.notifier).value = const [
      Group(
        name: 'zn.service.ai',
        type: GroupType.Selector,
        now: 'zn.service.ai.auto',
        all: [
          Proxy(name: 'zn.service.ai.auto', type: 'Selector'),
          Proxy(name: 'zn.service.ai.manual', type: 'Selector'),
          Proxy(name: 'DIRECT', type: 'Direct'),
        ],
      ),
      Group(
        name: 'zn.service.ai.auto',
        type: GroupType.Selector,
        now: 'zn.node.vless.7',
        all: [
          Proxy(name: 'REJECT', type: 'Reject'),
          Proxy(name: 'zn.node.vless.7', type: 'Vless'),
        ],
      ),
      Group(
        name: 'zn.service.ai.manual',
        type: GroupType.Selector,
        now: 'zn.node.trojan.9',
        all: [
          Proxy(name: 'zn.node.trojan.9', type: 'Trojan'),
          Proxy(name: 'DIRECT', type: 'Direct'),
        ],
      ),
    ];
  });
  tearDown(() {
    container.dispose();
    fixture.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    ZolnitSkin skin = ZolnitSkin.macos,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          locale: const Locale('en'),
          theme: ThemeData().withAppShapes.withAppTypography.withAppSurfaces,
          child: Material(
            child: ZolnitSkinScope(
              skin: skin,
              child: ZolnitBundleRoutingPanel(
                session: fixture.session,
                selectedServiceId: 'ai',
                onServiceChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'current display follows Core data rather than a display-name guess',
    (tester) async {
      await mount(tester);
      expect(find.text('Current route: 美国 原名'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bundle-routing-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual').last);
      await tester.pumpAndSettle();
      final owner =
          container.read(proxiesActionProvider.notifier) as _Recording;
      expect(owner.selections, [('zn.service.ai', 'zn.service.ai.manual')]);
    },
  );

  testWidgets(
    'expired failed refresh disables auto but keeps manual and direct controls',
    (tester) async {
      now = bundleTime(1301);
      container
          .read(zolnitBundleStatusProvider.notifier)
          .set(ZolnitBundleStatus.unavailable);
      await mount(tester);
      final status = tester
          .widget<Text>(find.byKey(const ValueKey('bundle-status')))
          .data!;
      expect(status, contains('expired'));
      expect(status, contains('temporarily unavailable'));
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('bundle-routing-mode')),
      );
      expect(dropdown.onChanged, isNotNull);
      expect(dropdown.items!.first.enabled, isFalse);
      expect(dropdown.items![1].enabled, isTrue);
      expect(dropdown.items![2].enabled, isTrue);
    },
  );

  testWidgets('no qualified nodes never makes auto selectable', (tester) async {
    fixture.onBundle = (_) async {
      final raw = clientBundleFixture(bundleId: 'without-qualification');
      (raw['routing'] as Map)['nodes'] = <Object>[];
      return clientBundleResponse(raw);
    };
    await tester.runAsync(
      () => fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => now,
      ),
    );
    await mount(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('bundle-status'))).data,
      contains('No exit is confirmed eligible'),
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('bundle-routing-mode')),
          )
          .items!
          .first
          .enabled,
      isFalse,
    );
  });

  testWidgets('a foreign account profile exposes no service controls', (
    tester,
  ) async {
    container
        .read(profilesProvider.notifier)
        .put(profile.copyWith(zolnitAccountId: 'different-account'));
    await mount(tester);
    expect(find.byKey(const ValueKey('bundle-routing-mode')), findsNothing);
    expect(find.byKey(const ValueKey('bundle-current-route')), findsNothing);
  });

  testWidgets('a disconnected Core is never displayed as a live choice', (
    tester,
  ) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await mount(tester);
    expect(find.text('Current route: 美国 原名'), findsNothing);
  });

  for (final skin in ZolnitSkin.values) {
    testWidgets('bundle controls render without overflow on ${skin.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, skin: skin);
      expect(find.byKey(const ValueKey('bundle-routing-mode')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
