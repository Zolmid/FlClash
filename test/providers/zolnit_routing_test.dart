import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_routing.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../packages/zolnit_client/test/routing_fixture.dart';
import '../helpers/test_profiles.dart';
import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Session extends Mock implements ZolnitSessionController {}

class _Api extends Mock implements XboardClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Core core;
  late _Session session;
  late _Api api;
  late ZolnitRouting routing;
  late Map<String, dynamic> config;
  late Map<String, String> picks;
  late int accountGeneration;
  var safe = true;
  var usType = 'Shadowsocks';
  Future<Delay?> Function(String url, String proxy)? probe;

  setUpAll(() async {
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'g', proxyName: 'p'),
    );
    registerFallbackValue(() {});
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    accountGeneration = 1;
    safe = true;
    usType = 'Shadowsocks';
    probe = null;
    config = prepareZolnitRouting(routingFixture()).config;
    core = _Core();
    session = _Session();
    api = _Api();
    when(() => session.api).thenReturn(api);
    when(() => session.authenticated).thenReturn(true);
    when(
      () => session.account,
    ).thenReturn({'email': 'fixture@example.invalid'});
    when(
      () => api.origin,
    ).thenReturn(Uri.parse('https://panel.example.invalid'));
    when(() => api.generation).thenAnswer((_) => accountGeneration);
    picks = {
      'AI 服务': 'AI 自动',
      '海外影音': '影音自动',
      'AI 自动': 'REJECT',
      '影音自动': 'REJECT',
    };
    when(core.getProxies).thenAnswer((_) async {
      final groups = (config['proxy-groups'] as List).cast<Map>();
      final proxies = <String, dynamic>{
        'DIRECT': <String, dynamic>{'name': 'DIRECT', 'type': 'Direct'},
        'REJECT': <String, dynamic>{'name': 'REJECT', 'type': 'Reject'},
        for (final name in ['hk-exit', 'us-exit', 'jp-exit'])
          name: <String, dynamic>{
            'name': name,
            'type': name == 'us-exit' ? usType : 'Shadowsocks',
          },
        for (final g in groups)
          g['name'] as String: <String, dynamic>{
            'name': g['name'],
            'type': g['type'] == 'select' ? 'Selector' : 'URLTest',
            'all': g['proxies'],
            'now': picks[g['name']] ?? (g['proxies'] as List).first,
          },
      };
      return ProxiesData(
        all: groups.map((g) => g['name'] as String).toList(),
        proxies: proxies,
      );
    });
    when(() => core.asyncTestDelay(any(), any())).thenAnswer((call) async {
      final url = call.positionalArguments[0] as String;
      final proxy = call.positionalArguments[1] as String;
      if (probe != null) return probe!(url, proxy);
      final latency = url.contains('netflix')
          ? (proxy == 'hk-exit' ? 10 : 100)
          : (proxy == 'us-exit' ? 20 : 180);
      return Delay(name: proxy, url: url, value: latency);
    });
    when(() => core.changeProxy(any())).thenAnswer((call) async {
      final params = call.positionalArguments.single as ChangeProxyParams;
      picks[params.groupName] = params.proxyName;
      return const ChangeProxyResult(changed: true);
    });
    when(core.resetConnections).thenAnswer((_) async => true);
    const profile = Profile(
      id: 1,
      label: 'ZolNit · fixture@example.invalid @ panel.example.invalid',
      autoUpdateDuration: Duration.zero,
    );
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        zolnitSessionProvider.overrideWithValue(session),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        safeModeProvider.overrideWith((_) => safe),
      ],
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    routing = container.read(zolnitRoutingProvider);
  });

  tearDown(() => container.dispose());

  void activate({SmartRoutingManifest? manifest}) {
    final prepared = prepareZolnitRouting(routingFixture());
    routing.stage(
      profileId: 1,
      accountGeneration: accountGeneration,
      digest: 'compiled-fixture',
      manifest: manifest ?? prepared.manifest,
      engine: prepared.engine,
    );
    routing.activate(1, 'compiled-fixture');
  }

  Future<void> runNormally() async {
    safe = false;
    container.invalidate(safeModeProvider);
    await routing.run();
  }

  test(
    'actual service selectors receive different Core choices while rules stay intact',
    () async {
      activate();
      await runNormally();
      expect(picks['AI 自动'], 'us-exit');
      expect(picks['影音自动'], 'hk-exit');
      expect(picks['AI 服务'], 'AI 自动');
      expect(
        container.read(currentProfileProvider)!.selectedMap['AI 自动'],
        'us-exit',
      );
      verifyNever(
        () => core.asyncTestDelay(any(that: contains('chatgpt')), 'hk-exit'),
      );
    },
  );

  test(
    'editing an inactive manual preset does not disable automatic routing',
    () async {
      activate();
      routing.manualSelection('AI 手动', 'hk-exit');
      await runNormally();
      expect(picks['AI 自动'], 'us-exit');
    },
  );

  test('safe mode never probes or changes Core selections', () async {
    activate();
    await routing.run();
    verifyNever(() => core.asyncTestDelay(any(), any()));
    verifyNever(() => core.changeProxy(any()));
  });

  test(
    'a manual DIRECT intent invalidates outstanding automatic measurements',
    () async {
      activate();
      final started = Completer<void>();
      final pending = Completer<Delay?>();
      probe = (url, proxy) async {
        if (proxy == 'us-exit') {
          if (!started.isCompleted) started.complete();
          return pending.future;
        }
        return Delay(name: proxy, url: url, value: 100);
      };
      safe = false;
      container.invalidate(safeModeProvider);
      final cycle = routing.run();
      await started.future;
      await container
          .read(proxiesActionProvider.notifier)
          .changeProxy(groupName: 'AI 服务', proxyName: 'DIRECT');
      pending.complete(
        const Delay(name: 'us-exit', url: 'https://chatgpt.com/', value: 1),
      );
      await cycle;
      expect(picks['AI 服务'], 'DIRECT');
      expect(picks['AI 自动'], 'REJECT');
      verifyNever(
        () => core.changeProxy(
          any(
            that: isA<ChangeProxyParams>().having(
              (p) => p.groupName,
              'group',
              'AI 自动',
            ),
          ),
        ),
      );
    },
  );

  test(
    'an account generation change rejects late measurements without selecting a node',
    () async {
      activate();
      final started = Completer<void>();
      final pending = Completer<Delay?>();
      probe = (url, proxy) async {
        if (!started.isCompleted) started.complete();
        return pending.future;
      };
      safe = false;
      container.invalidate(safeModeProvider);
      final cycle = routing.run();
      await started.future;
      accountGeneration++;
      pending.complete(
        const Delay(name: 'us-exit', url: 'https://chatgpt.com/', value: 1),
      );
      await cycle;
      verifyNever(() => core.changeProxy(any()));
    },
  );

  test(
    'a channel without replies does not manufacture proxy failures or fallback to DIRECT',
    () async {
      activate();
      probe = (_, _) async => null;
      await runNormally();
      expect(picks['AI 自动'], 'REJECT');
      expect(picks['影音自动'], 'REJECT');
      verifyNever(() => core.changeProxy(any()));
    },
  );

  test(
    'a stale preparation or wrong managed profile cannot activate routing',
    () async {
      routing.stage(
        profileId: 1,
        accountGeneration: 0,
        digest: 'old',
        manifest: prepareZolnitRouting(routingFixture()).manifest,
      );
      routing.activate(1, 'old');
      await runNormally();
      verifyNever(() => core.asyncTestDelay(any(), any()));
    },
  );
  test(
    'managed profile building carries worker-prepared routing into the applied Core path',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'zolnit-routing-build-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await useAppPaths(directory);
      await mockPreferences();
      globalState.packageInfo = PackageInfo(
        appName: 'ZolNit',
        packageName: 'com.zolmid.zolnit.debug',
        version: '0.0.0',
        buildNumber: '0',
      );
      final source = File(await appPath.getProfilePath('1'));
      await source.parent.create(recursive: true);
      await source.writeAsString(yaml.encode(routingFixture()));
      final built = await container
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: const SetupState(
              profileId: 1,
              profileLastUpdateDate: null,
              profileType: ProfileType.url,
              extendType: ExtendType.standard,
              rules: [],
              proxyGroups: [],
              addedRules: [],
              script: null,
              overrides: ProfileOverrides(),
            ),
            patchConfig: const PatchClashConfig(),
          );
      final compiled = loadPlainYaml(built.yaml) as Map;
      final groups = (compiled['proxy-groups'] as List).cast<Map>();
      expect(groups.singleWhere((g) => g['name'] == 'AI 自动')['proxies'], [
        'REJECT',
        'us-exit',
        'jp-exit',
      ]);
      expect(compiled['rules'], routingFixture()['rules']);
      expect(built.base, isNull);
      verifyNever(() => core.getProfileBase(any()));
      verifyNever(() => core.getConfig(any()));
      routing.activate(1, built.md5);
      await runNormally();
      expect(picks['AI 自动'], 'us-exit');
    },
  );
  test(
    'a real Core type change during probes cannot route through a direct alias',
    () async {
      activate();
      probe = (url, proxy) async {
        usType = 'Direct';
        return Delay(
          name: proxy,
          url: url,
          value: proxy == 'us-exit' ? 1 : 100,
        );
      };
      await runNormally();
      expect(picks['AI 自动'], 'jp-exit');
    },
  );
  test(
    'activation cannot bind a staged plan to another applied configuration digest',
    () async {
      activate();
      routing.activate(1, 'not-the-applied-digest');
      await runNormally();
      verifyNever(() => core.asyncTestDelay(any(), any()));
      verifyNever(() => core.changeProxy(any()));
    },
  );
}
