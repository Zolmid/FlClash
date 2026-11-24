import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_routing.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/bundle_routing.dart';
import 'package:fl_clash/views/zolnit/data.dart';
import 'package:fl_clash/views/zolnit/node_groups.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../packages/zolnit_client/test/client_bundle_fixture.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';
import '../../helpers/zolnit_return_route_fixture.dart';

class _ReturnCore extends Mock implements CoreHandlerInterface {}

class _Recording extends ProxiesAction {
  final selections = <(String, String)>[];
  Future<bool> Function()? selectionResult;
  @override
  void build() {}
  @override
  Future<void> updateGroups({bool Function()? isCurrent}) async {}
  @override
  void changeProxyDebounce(String groupName, String proxyName) =>
      selections.add((groupName, proxyName));
  @override
  Future<bool> changeProxyIfCurrent({
    required String groupName,
    required String proxyName,
    required bool Function() isCurrent,
    Map<String, dynamic>? routingLease,
  }) async {
    if (!isCurrent()) return false;
    selections.add((groupName, proxyName));
    final applied = await (selectionResult?.call() ?? Future.value(true));
    if (!applied || !isCurrent()) return false;
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, proxyName);
    ref.read(groupsProvider.notifier).value = [
      for (final group in ref.read(groupsProvider))
        group.name == groupName ? group.copyWith(now: proxyName) : group,
    ];
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<String, dynamic>{});
  late ClientBundleSessionFixture fixture;
  late ProviderContainer container;
  late DateTime now;
  late Profile profile;
  late _ReturnCore core;

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
    core = _ReturnCore();
    when(() => core.watchRoute(any())).thenAnswer((_) async => null);
    when(core.getClientBundleOwner).thenAnswer(
      (_) async => {
        'returnRouteGuard': {
          'instanceId': 'fixture-core',
          'token': 'fixture-return',
          'configurationGeneration': 1,
          'accountId': fixture.session.clientBundle!.accountId,
          'accountGeneration': fixture.api.generation,
          'bundleId': fixture.session.clientBundle!.bundleId,
        },
      },
    );
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
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
    when(() => core.setClientReturnRoute(any())).thenAnswer((invocation) async {
      final parameters =
          invocation.positionalArguments.single as Map<String, dynamic>;
      final route = ZolnitReturnRoute.resolve(
        fixture.session.clientBundle!,
        container.read(groupsProvider),
      )!;
      final enabled = parameters['enabled'] as bool;
      final option = route.options
          .where((o) => o.id == parameters['optionId'])
          .firstOrNull;
      final selections = <String, String>{
        for (final d in route.dispatches)
          d.groupName: enabled ? d.returnTarget : d.localTarget,
        if (enabled) route.group: option!.target,
      };
      final action =
          container.read(proxiesActionProvider.notifier) as _Recording;
      action.selections.addAll(selections.entries.map((e) => (e.key, e.value)));
      container.read(groupsProvider.notifier).value = [
        for (final group in container.read(groupsProvider))
          group.copyWith(now: selections[group.name] ?? group.now),
      ];
      return {
        'enabled': enabled,
        'selectedId': option?.id,
        'selections': selections,
      };
    });
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
    final bundle = fixture.session.clientBundle;
    if (bundle != null) {
      await tester.runAsync(() => loadZolnitRouteMetadata(bundle));
    }
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

  Future<Map<String, dynamic>> mountDispatch(
    WidgetTester tester, {
    Map<String, dynamic>? source,
  }) async {
    final raw = source ?? returnDispatchFixture();
    fixture.onBundle = (_) async => clientBundleResponse(raw);
    await tester.runAsync(
      () => fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => now,
      ),
    );
    profile = profile.copyWith(
      zolnitBundleId: fixture.session.clientBundle!.bundleId,
    );
    container.read(profilesProvider.notifier).put(profile);
    container.read(groupsProvider.notifier).value = returnDispatchCoreGroups(
      raw,
    );
    await mount(tester);
    return raw;
  }

  testWidgets(
    'explicit activation switches both parents and disabling restores local',
    (tester) async {
      await mountDispatch(tester);
      final toggle = find.byKey(const ValueKey('bundle-return-enabled'));
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(find.text('Local direct connection'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('bundle-return-route')),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
      final route = ZolnitReturnRoute.resolve(
        fixture.session.clientBundle!,
        container.read(groupsProvider),
      )!;
      final activeMap = container.read(currentProfileProvider)!.selectedMap;
      for (final d in route.dispatches) {
        expect(activeMap[d.groupName], route.group);
      }
      expect(activeMap[route.group], route.options.first.target);
      expect(activeMap[route.group], isNot('DIRECT'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      for (final d in route.dispatches) {
        expect(
          container.read(currentProfileProvider)!.selectedMap[d.groupName],
          d.localTarget,
        );
      }
    },
  );

  testWidgets('loss of every return role still allows explicit local disable', (
    tester,
  ) async {
    final raw = returnDispatchFixture(
      source: returnRouteAvailabilityFixture(restricted: true),
    );
    await mountDispatch(tester, source: raw);
    final targets =
        ((raw['routing']['ui_groups'] as List).first['options'] as List)
            .map((o) => o['target'])
            .toSet();
    container.read(groupsProvider.notifier).value = [
      for (final group in returnDispatchCoreGroups(raw, active: true))
        targets.contains(group.name)
            ? group.copyWith(
                all: const [Proxy(name: 'REJECT', type: 'Reject')],
              )
            : group,
    ];
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('bundle-return-enabled'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('bundle-return-route')),
          )
          .items,
      isEmpty,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
    expect(find.byKey(const ValueKey('bundle-return-error')), findsNothing);
  });

  testWidgets('a failed activation preserves local state and reports failure', (
    tester,
  ) async {
    await mountDispatch(tester);
    when(
      () => core.setClientReturnRoute(any()),
    ).thenThrow(StateError('synthetic failure'));
    final toggle = find.byKey(const ValueKey('bundle-return-enabled'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(container.read(currentProfileProvider)!.selectedMap, isEmpty);
    expect(find.byKey(const ValueKey('bundle-return-error')), findsOneWidget);
    expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
  });

  testWidgets('an incomplete parent ACK is not persisted as enabled', (
    tester,
  ) async {
    await mountDispatch(tester);
    when(() => core.setClientReturnRoute(any())).thenAnswer(
      (_) async => {
        'enabled': true,
        'selectedId': 'direct',
        'selections': <String, dynamic>{'fixture.return_dispatch': 'missing'},
      },
    );
    await tester.tap(find.byKey(const ValueKey('bundle-return-enabled')));
    await tester.pumpAndSettle();
    expect(container.read(currentProfileProvider)!.selectedMap, isEmpty);
    expect(find.byKey(const ValueKey('bundle-return-error')), findsOneWidget);
  });

  testWidgets(
    'logout fences a late activation ACK without writing the profile',
    (tester) async {
      await mountDispatch(tester);
      final pending = Completer<Map<String, dynamic>?>();
      when(
        () => core.setClientReturnRoute(any()),
      ).thenAnswer((_) => pending.future);
      await tester.tap(find.byKey(const ValueKey('bundle-return-enabled')));
      await tester.pump();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('bundle-return-enabled')))
            .onChanged,
        isNull,
      );
      await fixture.session.logout();
      pending.complete({
        'enabled': true,
        'selectedId': 'direct',
        'selections': <String, dynamic>{},
      });
      await tester.pumpAndSettle();
      expect(container.read(currentProfileProvider)!.selectedMap, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all return roles select the exact producer target without aliases in labels',
    (tester) async {
      final raw = returnDispatchFixture();
      fixture.onBundle = (_) async => clientBundleResponse(raw);
      await tester.runAsync(
        () => fixture.session.refreshClientBundle(
          coreVersion: 'v1.19.32',
          clock: () => now,
        ),
      );
      profile = profile.copyWith(
        zolnitBundleId: fixture.session.clientBundle!.bundleId,
      );
      container.read(profilesProvider.notifier).put(profile);
      container.read(groupsProvider.notifier).value = returnDispatchCoreGroups(
        raw,
        active: true,
      );
      await mount(tester);
      final mapping = (raw['routing']['ui_groups'] as List).first;
      for (final (id, label) in [
        ('direct', 'Direct to China'),
        ('hk_lite', 'Hong Kong preferred'),
        ('hk_optimized', 'Hong Kong optimized'),
      ]) {
        await tester.tap(find.byKey(const ValueKey('bundle-return-route')));
        await tester.pumpAndSettle();
        expect(find.textContaining('zn.group.'), findsNothing);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        final option = (mapping['options'] as List).singleWhere(
          (o) => o['id'] == id,
        );
        final owner =
            container.read(proxiesActionProvider.notifier) as _Recording;
        expect(owner.selections.last, (mapping['group'], option['target']));
        expect(owner.selections.last.$2, isNot('DIRECT'));
      }
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('bundle-return-route')),
            )
            .onChanged,
        isNull,
      );
    },
  );

  for (final skin in ZolnitSkin.values) {
    testWidgets(
      'restricted graph offers only the authorized role on ${skin.name}',
      (tester) async {
        final raw = returnDispatchFixture(
          source: returnRouteAvailabilityFixture(
            restricted: true,
            bundleId: 'restricted',
          ),
        );
        fixture.onBundle = (_) async => clientBundleResponse(raw);
        await tester.runAsync(
          () => fixture.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => now,
          ),
        );
        profile = profile.copyWith(
          zolnitBundleId: fixture.session.clientBundle!.bundleId,
        );
        container.read(profilesProvider.notifier).put(profile);
        container.read(groupsProvider.notifier).value =
            returnDispatchCoreGroups(raw, active: true);
        await mount(tester, skin: skin);
        final dropdown = tester.widget<DropdownButton<String>>(
          find.byKey(const ValueKey('bundle-return-route')),
        );
        expect(dropdown.items!.map((item) => item.value), ['hk_lite']);
        dropdown.onChanged!('direct');
        await tester.pump();
        final owner =
            container.read(proxiesActionProvider.notifier) as _Recording;
        expect(owner.selections, isEmpty);
        dropdown.onChanged!('hk_lite');
        await tester.pumpAndSettle();
        expect(
          owner.selections.last.$2,
          (raw['routing']['ui_groups'] as List).first['options'][1]['target'],
        );
      },
    );
  }

  testWidgets('a stale Core bundle guard never dispatches a return choice', (
    tester,
  ) async {
    final raw = returnDispatchFixture(source: returnRouteAvailabilityFixture());
    fixture.onBundle = (_) async => clientBundleResponse(raw);
    await tester.runAsync(
      () => fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => now,
      ),
    );
    profile = profile.copyWith(
      zolnitBundleId: fixture.session.clientBundle!.bundleId,
    );
    container.read(profilesProvider.notifier).put(profile);
    container.read(groupsProvider.notifier).value = returnDispatchCoreGroups(
      raw,
      active: true,
    );
    when(core.getClientBundleOwner).thenAnswer(
      (_) async => {
        'returnRouteGuard': {
          'instanceId': 'fixture-core',
          'token': 'new-policy',
          'configurationGeneration': 2,
          'accountId': fixture.session.clientBundle!.accountId,
          'accountGeneration': fixture.api.generation,
          'bundleId': 'different-native-bundle',
        },
      },
    );
    await mount(tester);
    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('bundle-return-route')),
        )
        .onChanged!('direct');
    await tester.pumpAndSettle();
    expect(
      (container.read(proxiesActionProvider.notifier) as _Recording).selections,
      isEmpty,
    );
  });

  testWidgets(
    'current display follows Core data rather than a display-name guess',
    (tester) async {
      await mount(tester);
      expect(find.text('Current route: US · 原名'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bundle-routing-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual').last);
      await tester.pumpAndSettle();
      final owner =
          container.read(proxiesActionProvider.notifier) as _Recording;
      expect(owner.selections, [('zn.service.ai', 'zn.service.ai.manual')]);
    },
  );

  for (final skin in ZolnitSkin.values) {
    testWidgets(
      '24 authorized manual routes and four qualified auto routes on ${skin.name}',
      (tester) async {
        final raw =
            (jsonDecode(
                  File(
                    'packages/zolnit_client/test/fixtures/authorized24-qualified4.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['data'];
        fixture.onBundle = (_) async => clientBundleResponse(raw);
        await tester.runAsync(
          () => fixture.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => now,
          ),
        );
        profile = profile.copyWith(
          zolnitBundleId: fixture.session.clientBundle!.bundleId,
        );
        container.read(profilesProvider.notifier).put(profile);
        final prepared = prepareClientBundleConfiguration((
          bundle: fixture.session.clientBundle!,
          now: now,
          automaticAllowed: true,
        ));
        final proxyTypes = {
          for (final proxy in prepared.config['proxies'] as List)
            proxy['name']: proxy['type'],
        };
        container.read(groupsProvider.notifier).value = [
          for (final raw in prepared.config['proxy-groups'] as List)
            Group(
              name: raw['name'],
              type: GroupType.Selector,
              now: raw['name'] == 'zn.service.ai'
                  ? 'zn.service.ai.manual'
                  : (raw['proxies'] as List).first,
              all: [
                for (final name in raw['proxies'] as List)
                  Proxy(
                    name: name,
                    type:
                        proxyTypes[name] ??
                        (name == 'DIRECT'
                            ? 'Direct'
                            : name == 'REJECT'
                            ? 'Reject'
                            : 'Selector'),
                  ),
              ],
            ),
        ];
        await mount(tester, skin: skin);
        final picker = find.byKey(const ValueKey('bundle-manual-route'));
        final dropdown = tester.widget<DropdownButton<String>>(picker);
        expect(dropdown.items, hasLength(24));
        final sg = fixture.session.clientBundle!.outbounds.last;
        dropdown.onChanged!(sg.proxyName);
        await tester.pumpAndSettle();
        expect(
          container
              .read(currentProfileProvider)!
              .selectedMap['zn.service.ai.manual'],
          sg.proxyName,
        );
        expect(
          tester.widget<DropdownButton<String>>(picker).value,
          sg.proxyName,
        );
        expect(find.textContaining('Latency does not'), findsNothing);
        expect(
          find.byKey(const ValueKey('bundle-current-route')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'auto shows the Core exit when its snapshot moves beyond REJECT',
    (tester) async {
      final actualGroups = container.read(groupsProvider);
      final groupsNotifier = container.read(groupsProvider.notifier);
      groupsNotifier.value = [
        for (final group in actualGroups)
          group.name == 'zn.service.ai.auto'
              ? group.copyWith(now: 'REJECT')
              : group,
      ];
      await mount(tester);
      expect(find.text('No route selected. Try Manual.'), findsOneWidget);
      expect(find.textContaining('Current route:'), findsNothing);

      container
          .read(routeTrackerProvider.notifier)
          .applySnapshot(
            RouteSnapshot(
              coreEpoch: 1,
              picksVersion: 2,
              picks: {
                for (final group in actualGroups) group.name: group.realNow,
              },
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Current route: US · 原名'), findsOneWidget);
      expect(find.text('No route selected. Try Manual.'), findsNothing);
    },
  );

  testWidgets(
    'manual failure restores selection and profile switch fences late error',
    (tester) async {
      container.read(groupsProvider.notifier).value = [
        for (final group in container.read(groupsProvider))
          group.name == 'zn.service.ai'
              ? group.copyWith(now: 'zn.service.ai.manual')
              : group.name == 'zn.service.ai.manual'
              ? group.copyWith(now: 'DIRECT')
              : group,
      ];
      await mount(tester);
      final owner =
          container.read(proxiesActionProvider.notifier) as _Recording;
      final result = Completer<bool>();
      owner.selectionResult = () => result.future;
      final picker = find.byKey(const ValueKey('bundle-manual-route'));
      tester.widget<DropdownButton<String>>(picker).onChanged!(
        'zn.node.trojan.9',
      );
      await tester.pump();
      expect(
        tester.widget<DropdownButton<String>>(picker).value,
        'zn.node.trojan.9',
      );
      expect(find.byKey(const ValueKey('bundle-mode-pending')), findsOneWidget);
      container.read(profilesProvider.notifier).put(profile.copyWith(id: 2));
      container.read(currentProfileIdProvider.notifier).value = 2;
      await tester.pump();
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bundle-mode-error')), findsNothing);
      expect(container.read(currentProfileProvider)!.selectedMap, isEmpty);
    },
  );

  testWidgets('mode selection shows pending and failure feedback', (
    tester,
  ) async {
    await mount(tester);
    final owner = container.read(proxiesActionProvider.notifier) as _Recording;
    final result = Completer<bool>();
    owner.selectionResult = () => result.future;
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('bundle-routing-mode')),
    );
    dropdown.onChanged!('zn.service.ai.manual');
    await tester.pump();
    expect(find.byKey(const ValueKey('bundle-mode-pending')), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('bundle-routing-mode')),
          )
          .value,
      'zn.service.ai.manual',
    );
    result.complete(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('bundle-mode-pending')), findsNothing);
    expect(find.byKey(const ValueKey('bundle-mode-error')), findsOneWidget);
  });

  testWidgets('a late mode result cannot replace the latest intent', (
    tester,
  ) async {
    await mount(tester);
    final owner = container.read(proxiesActionProvider.notifier) as _Recording;
    final first = Completer<bool>();
    final second = Completer<bool>();
    var calls = 0;
    owner.selectionResult = () => calls++ == 0 ? first.future : second.future;
    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('bundle-routing-mode')),
        )
        .onChanged!('zn.service.ai.manual');
    await tester.pump();
    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('bundle-routing-mode')),
        )
        .onChanged!('DIRECT');
    await tester.pump();
    first.complete(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('bundle-mode-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('bundle-mode-error')), findsNothing);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('bundle-routing-mode')),
          )
          .value,
      'DIRECT',
    );
    second.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bundle-mode-pending')), findsNothing);
    expect(find.byKey(const ValueKey('bundle-mode-error')), findsNothing);
  });

  testWidgets(
    'current service route uses the same protocol-free distinct server identity as All Routes',
    (tester) async {
      final raw = clientBundleFixture();
      for (final outbound in raw['outbounds'] as List) {
        if (outbound['id'] == 'vless:7') {
          outbound['display_name'] = '香港 Lite A · HY2 · 1×';
        }
        if (outbound['id'] == 'hysteria:8') {
          outbound['display_name'] = '香港 Lite A · REALITY · 1×';
        }
      }
      for (final node in raw['routing']['nodes'] as List) {
        if (node['id'] == 'vless:7') {
          node['final_egress']['country'] = 'HK';
        }
      }
      fixture.onBundle = (_) async => clientBundleResponse(raw);
      await tester.runAsync(
        () => fixture.session.refreshClientBundle(
          coreVersion: 'v1.19.32',
          clock: () => now,
        ),
      );
      await mount(tester);
      expect(find.text('Current route: HK · Lite A · 2'), findsOneWidget);
      expect(find.textContaining('HY2'), findsNothing);
      expect(find.textContaining('REALITY'), findsNothing);
      final owner =
          container.read(proxiesActionProvider.notifier) as _Recording;
      expect(owner.selections, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cached in [true, false]) {
    testWidgets(
      'refresh failure copy distinguishes retained settings ($cached)',
      (tester) async {
        if (!cached) await tester.runAsync(() => fixture.session.logout());
        container
            .read(zolnitBundleStatusProvider.notifier)
            .set(ZolnitBundleStatus.refreshFailed);
        final message = cached
            ? "Connection information can't be updated right now."
            : "Connection settings couldn't be loaded. Try again shortly.";
        await mount(tester);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('bundle-status'))).data,
          message,
        );
        await tester.pumpWidget(
          TestApp(
            includeNavigatorKey: false,
            locale: const Locale('en'),
            child: Builder(
              builder: (context) => Text(
                zolnitConfigurationMessage(
                  context,
                  fixture.session,
                  ZolnitBundleStatus.refreshFailed,
                  privateTransport: true,
                )!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
      },
    );
  }

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
      expect(status, contains('out of date'));
      expect(status, contains("couldn't be loaded"));
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
      equals('No routes for automatic selection.'),
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

  testWidgets('missing runtime groups do not imply no eligible candidates', (
    tester,
  ) async {
    container.read(groupsProvider.notifier).value = [];
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await mount(tester);
    expect(find.text('No routes for automatic selection.'), findsNothing);
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('a disconnected Core is never displayed as a live choice', (
    tester,
  ) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await mount(tester);
    expect(find.text('Current route: US · 原名'), findsNothing);
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
