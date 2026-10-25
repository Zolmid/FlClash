import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_routing.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../packages/zolnit_client/test/client_bundle_fixture.dart';
import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Downloader extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ClientBundleSessionFixture fixture;
  late ProviderContainer container;
  late _Core core;
  late _Downloader downloader;
  void Function(ChangeProxyParams)? changed;
  late DateTime now;
  late bool safe;
  Future<void> Function()? validation;
  Map<String, dynamic>? compiled;
  String? compiledDigest;
  final picks = <String, String>{};

  setUpAll(() async {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(
      const ProbeParams(url: 'https://example.invalid/', timeout: 1000),
    );
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'g', proxyName: 'p'),
    );
    await AppLocalizations.load(const Locale('en'));
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zolnit-bundle-');
    await useAppPaths(directory);
    await mockPreferences();
    globalState.packageInfo = PackageInfo(
      appName: 'ZolNit',
      packageName: 'com.zolmid.zolnit.debug',
      version: '0.9.1',
      buildNumber: 'fixture',
    );
    now = bundleTime(1001);
    safe = true;
    validation = null;
    compiled = null;
    compiledDigest = null;
    picks.clear();
    fixture = ClientBundleSessionFixture();
    await fixture.login();
    core = _Core();
    downloader = _Downloader();
    changed = null;
    when(core.getCoreVersion).thenAnswer((_) async => 'v1.19.32');
    when(() => core.validateConfig(any())).thenAnswer((_) async {
      await validation?.call();
      return '';
    });
    when(() => core.changeProxy(any())).thenAnswer((call) async {
      final value = call.positionalArguments.single as ChangeProxyParams;
      picks[value.groupName] = value.proxyName;
      changed?.call(value);
      return const ChangeProxyResult(changed: true);
    });
    when(core.getRoutingLease).thenAnswer((_) async {
      final profile = container.read(currentProfileProvider);
      final bundle = fixture.session.clientBundle;
      if (profile == null || bundle == null) return null;
      return {
        'instanceId': 'fixture-core',
        'token': 'fixture-token',
        'configurationGeneration': 1,
        'accountId': bundle.accountId,
        'accountGeneration': fixture.api.generation,
        'bundleId': bundle.bundleId,
        'configurationDigest': compiledDigest,
        'expiresAt': bundle.expiresAt.millisecondsSinceEpoch,
      };
    });
    when(
      () => core.invalidateRoutingLease(any()),
    ).thenAnswer((_) async => true);
    when(core.resetConnections).thenAnswer((_) async => true);
    when(() => core.probe(any())).thenAnswer((call) async {
      final params = call.positionalArguments.single as ProbeParams;
      return ProbeResult(statusCode: 200, delay: 20, url: params.url);
    });
    when(core.getProxies).thenAnswer((_) async {
      final config = compiled!;
      final groups = (config['proxy-groups'] as List).cast<Map>();
      final raw = <String, dynamic>{
        'DIRECT': <String, dynamic>{'name': 'DIRECT', 'type': 'Direct'},
        'REJECT': <String, dynamic>{'name': 'REJECT', 'type': 'Reject'},
        for (final proxy in (config['proxies'] as List).cast<Map>())
          proxy['name'] as String: <String, dynamic>{
            'name': proxy['name'],
            'type': switch (proxy['type']) {
              'vless' => 'Vless',
              'trojan' => 'Trojan',
              'hysteria2' => 'Hysteria2',
              'hysteria' => 'Hysteria',
              _ => 'Socks5',
            },
          },
        for (final group in groups)
          group['name'] as String: <String, dynamic>{
            'name': group['name'],
            'type': switch (group['type']) {
              'url-test' => 'URLTest',
              'fallback' => 'Fallback',
              'load-balance' => 'LoadBalance',
              _ => 'Selector',
            },
            'all': group['proxies'] ?? <String>[],
            'now':
                picks[group['name']] ??
                (group['proxies'] as List?)?.firstOrNull ??
                '',
          },
      };
      return ProxiesData(
        all: groups.map((g) => g['name'] as String).toList(),
        proxies: raw,
      );
    });
    container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(fixture.session),
        zolnitProfileDownloaderProvider.overrideWithValue(downloader),
        zolnitClientBundleTransportProvider.overrideWithValue(true),
        zolnitClientBundleAutomaticProvider.overrideWithValue(true),
        zolnitBundleClockProvider.overrideWithValue(() => now),
        profilesProvider.overrideWith(() => TestProfiles()),
        currentProfileIdProvider.overrideWithBuild((_, _) => null),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        safeModeProvider.overrideWith((_) => safe),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    verifyZeroInteractions(downloader);
    fixture.dispose();
    await directory.delete(recursive: true);
  });

  Future<Profile> sync() async {
    final id = await container.read(zolnitSyncProfileProvider)();
    return container.read(profilesProvider).getProfile(id)!;
  }

  Future<BuiltProfile> build(Profile profile) async {
    final result = await container
        .read(setupActionProvider.notifier)
        .getProfile(
          setupState: SetupState(
            profileId: profile.id,
            profileLastUpdateDate: null,
            profileType: ProfileType.file,
            extendType: ExtendType.standard,
            rules: const [],
            proxyGroups: const [],
            addedRules: const [],
            script: null,
            overrides: const ProfileOverrides(),
          ),
          patchConfig: const PatchClashConfig(),
        );
    compiled = Map<String, dynamic>.from(loadPlainYaml(result.yaml) as Map);
    compiledDigest = result.md5;
    return result;
  }

  Map group(String name) => (compiled!['proxy-groups'] as List)
      .cast<Map>()
      .singleWhere((g) => g['name'] == name);
  Future<ZolnitRouting> activate(Profile profile) async {
    container.read(currentProfileIdProvider.notifier).value = profile.id;
    final built = await build(profile);
    final routing = container.read(zolnitRoutingProvider);
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    routing.activate(profile.id, built.md5);
    safe = false;
    container.invalidate(safeModeProvider);
    return routing;
  }

  for (final status in [403, 503]) {
    test(
      'initial bundle HTTP $status never creates a subscription profile',
      () async {
        final code = status == 403
            ? 'entitlement_unavailable'
            : 'client_api_unavailable';
        final subscription = fixture.session.subscription;
        fixture.onBundle = (_) async => http.Response(
          jsonEncode({
            'error': {'code': code},
          }),
          status,
        );
        await expectLater(
          container.read(zolnitSyncProfileProvider)(),
          throwsA(isA<ClientFailure>().having((e) => e.code, 'code', code)),
        );
        expect(container.read(profilesProvider), isEmpty);
        expect(fixture.session.authenticated, isTrue);
        expect(fixture.session.subscription, subscription);
        expect(fixture.invalidations, 0);
      },
    );
  }

  for (final expiresAt in [1000, 1301, 1001]) {
    test(
      'invalid or expired TTL $expiresAt cannot create a bundle profile',
      () async {
        fixture.onBundle = (_) async {
          final raw = clientBundleFixture();
          raw['expires_at'] = expiresAt;
          return clientBundleResponse(raw);
        };
        await expectLater(
          container.read(zolnitSyncProfileProvider)(),
          throwsA(isA<ClientFailure>()),
        );
        expect(container.read(profilesProvider), isEmpty);
        expect(fixture.session.clientBundle, isNull);
        expect(fixture.session.authenticated, isTrue);
      },
    );
  }

  test(
    'a transient 503 preserves automatic eligibility only until TTL',
    () async {
      final profile = await sync();
      final subscription = fixture.session.subscription;
      final routing = await activate(profile);
      await routing.run();
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"client_api_unavailable"}}', 503);
      now = bundleTime(1299);
      await routing.refreshBundle();
      await routing.run();
      expect(picks['zn.service.ai.auto'], 'zn.node.vless.7');
      await build(profile);
      expect(
        group('zn.service.ai.auto')['proxies'],
        contains('zn.node.vless.7'),
      );
      final rejected = Completer<void>();
      changed = (value) {
        if (!rejected.isCompleted &&
            value.groupName == 'zn.service.ai.auto' &&
            value.proxyName == 'REJECT') {
          rejected.complete();
        }
      };
      now = bundleTime(1300);
      await routing.refreshBundle();
      await rejected.future;
      await routing.run();
      expect(picks['zn.service.ai.auto'], 'REJECT');
      expect(
        container.read(zolnitBundleStatusProvider),
        ZolnitBundleStatus.expired,
      );
      await build(profile);
      expect(group('zn.service.ai.auto')['proxies'], ['REJECT']);
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.subscription, subscription);
      expect(
        cachedManualZolnitBundleProfile(
          [profile],
          fixture.session,
          enabled: true,
        ),
        isNull,
      );
    },
  );

  test(
    '403 revokes active automatic routing and denies cached reconnect',
    () async {
      final profile = await sync();
      final subscription = fixture.session.subscription;
      final routing = await activate(profile);
      await routing.run();
      final rejected = Completer<void>();
      changed = (value) {
        if (!rejected.isCompleted &&
            value.groupName == 'zn.service.ai.auto' &&
            value.proxyName == 'REJECT') {
          rejected.complete();
        }
      };
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"entitlement_unavailable"}}', 403);
      await routing.refreshBundle();
      await rejected.future;
      await routing.run();
      expect(picks['zn.service.ai.auto'], 'REJECT');
      expect(
        container.read(zolnitBundleStatusProvider),
        ZolnitBundleStatus.forbidden,
      );
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.subscription, subscription);
      expect(fixture.invalidations, 0);
      for (final choice in ['zn.service.ai.manual', 'DIRECT']) {
        final cached = profile.copyWith(selectedMap: {'zn.service.ai': choice});
        expect(
          cachedManualZolnitBundleProfile(
            [cached],
            fixture.session,
            enabled: true,
          ),
          isNull,
        );
      }
      await expectLater(build(profile), throwsA(isA<ClientFailure>()));
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"client_api_unavailable"}}', 503);
      await routing.refreshBundle();
      final rebuilt = await build(profile);
      clearInteractions(core);
      routing.activate(profile.id, rebuilt.md5);
      await routing.run();
      verifyNever(() => core.probe(any()));
      expect(picks['zn.service.ai.auto'], 'REJECT');
    },
  );

  for (final expiresAt in [1000, 1301, 1001]) {
    test(
      'TTL rejection $expiresAt invalidates old automatic eligibility',
      () async {
        final profile = await sync();
        final subscription = fixture.session.subscription;
        final routing = await activate(profile);
        await routing.run();
        final rejected = Completer<void>();
        changed = (value) {
          if (!rejected.isCompleted &&
              value.groupName == 'zn.service.ai.auto' &&
              value.proxyName == 'REJECT') {
            rejected.complete();
          }
        };
        fixture.onBundle = (_) async {
          final raw = clientBundleFixture();
          raw['expires_at'] = expiresAt;
          return clientBundleResponse(raw);
        };
        await routing.refreshBundle();
        await rejected.future;
        await routing.run();
        expect(picks['zn.service.ai.auto'], 'REJECT');
        expect(fixture.session.authenticated, isTrue);
        expect(fixture.session.subscription, subscription);
      },
    );
  }

  for (final choice in ['zn.service.ai.manual', 'DIRECT']) {
    test(
      'expired same-account $choice cache remains available after 503',
      () async {
        final profile = await sync();
        now = bundleTime(1300);
        fixture.onBundle = (_) async =>
            http.Response('{"error":{"code":"bundle_unavailable"}}', 503);
        await expectLater(
          container.read(zolnitSyncProfileProvider)(),
          throwsA(isA<ClientFailure>()),
        );
        final cached = profile.copyWith(selectedMap: {'zn.service.ai': choice});
        expect(
          cachedManualZolnitBundleProfile(
            [cached],
            fixture.session,
            enabled: true,
          )?.id,
          profile.id,
        );
        expect(
          cachedManualZolnitBundleProfile(
            [cached.copyWith(zolnitAccountId: 'other')],
            fixture.session,
            enabled: true,
          ),
          isNull,
        );
        await build(profile);
        expect(group('zn.service.ai.auto')['proxies'], ['REJECT']);
        expect(group('zn.service.ai.manual')['proxies'], contains('DIRECT'));
      },
    );
  }

  test(
    'a renewed bundle requires a new applied Core lease even when YAML is identical',
    () async {
      final profile = await sync();
      final before = await build(profile);
      fixture.onBundle = (_) async => clientBundleResponse(
        clientBundleFixture(
          issuedAt: 1001,
          bundleId: 'renewed-immutable-bundle',
        ),
      );
      now = bundleTime(1002);
      final renewed = await sync();
      final after = await build(renewed);
      expect(renewed.id, profile.id);
      expect(after.yaml, before.yaml);
      expect(after.md5, isNot(before.md5));
      final spec = container
          .read(zolnitRoutingProvider)
          .preparedLease(renewed.id, after.md5)!;
      expect(spec['bundleId'], 'renewed-immutable-bundle');
      expect(spec['expiresAt'], bundleTime(1301).millisecondsSinceEpoch);
    },
  );

  test(
    'bundle dispatch uses no subscription URL and commits one bound source record',
    () async {
      expect(fixture.session.subscription!['subscribe_url'], isNull);
      final profile = await sync();
      expect(profile.zolnitAccountId, 'account-1');
      expect(profile.zolnitOrigin, fixture.api.origin.origin);
      expect(profile.url, isEmpty);
      expect(profile.type, ProfileType.file);
      expect(
        container.read(zolnitBundleStatusProvider),
        ZolnitBundleStatus.ready,
      );
      final record = File(await zolnitBundlePath(profile));
      expect(await record.exists(), isTrue);
      if (!Platform.isWindows) {
        expect((await record.stat()).mode & 0x1ff, 0x180);
      }
      await build(profile);
      expect(group('zn.service.ai.auto')['proxies'], [
        'REJECT',
        'zn.node.vless.7',
      ]);
      expect(group('zn.service.media.auto')['proxies'], [
        'REJECT',
        'zn.node.hysteria.8',
        'zn.node.vless.7',
      ]);
      expect(
        group('zn.service.ai.manual')['proxies'],
        contains('zn.node.trojan.9'),
      );
      verifyNever(() => core.getConfig(any()));
      verifyNever(() => core.getProfileBase(any()));
    },
  );

  test(
    'cached expiry removes automatic candidates while retaining manual credentials and paid snapshot',
    () async {
      final profile = await sync();
      final subscription = fixture.session.subscription;
      now = bundleTime(1301);
      await build(profile);
      expect(group('zn.service.ai.auto')['proxies'], ['REJECT']);
      expect(
        group('zn.service.ai.manual')['proxies'],
        containsAll([
          'zn.node.vless.7',
          'zn.node.hysteria.8',
          'zn.node.trojan.9',
          'DIRECT',
        ]),
      );
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.subscription, subscription);
    },
  );

  test('changed account cannot build a cached private profile', () async {
    final profile = await sync();
    await fixture.session.logout();
    expect(() => build(profile), throwsA(isA<ClientFailure>()));
  });

  test(
    'tampered cached document never becomes an applied configuration',
    () async {
      final profile = await sync();
      final target = File(await zolnitBundlePath(profile));
      final data = jsonDecode(await target.readAsString()) as Json;
      (data['connection'] as Map)['document'] += '\n';
      await target.writeAsString(jsonEncode(data));
      expect(
        () => build(profile),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'invalid_client_bundle',
          ),
        ),
      );
    },
  );

  test(
    'an immutable bundle ID cannot be reused for different routing data',
    () async {
      final first = await sync();
      final before = await File(await zolnitBundlePath(first)).readAsString();
      fixture.onBundle = (_) async {
        final raw = clientBundleFixture();
        (raw['routing'] as Map)['revision'] = 'changed-under-same-id';
        return clientBundleResponse(raw);
      };
      await expectLater(
        container.read(zolnitSyncProfileProvider)(),
        throwsA(isA<ClientFailure>()),
      );
      expect(
        container.read(profilesProvider).single.zolnitBundleId,
        first.zolnitBundleId,
      );
      expect(await File(await zolnitBundlePath(first)).readAsString(), before);
      expect(
        container.read(zolnitBundleStatusProvider),
        ZolnitBundleStatus.invalid,
      );
    },
  );

  test(
    'logout during Core validation cannot commit a late private profile',
    () async {
      final entered = Completer<void>();
      final pending = Completer<void>();
      validation = () {
        entered.complete();
        return pending.future;
      };
      final operation = container.read(zolnitSyncProfileProvider)();
      await entered.future;
      await fixture.session.logout();
      pending.complete();
      await expectLater(
        operation,
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'superseded'),
        ),
      );
      expect(container.read(profilesProvider), isEmpty);
    },
  );

  test(
    'entitlement denial prevents reapplying cached connection data',
    () async {
      final profile = await sync();
      final subscription = fixture.session.subscription;
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"entitlement_unavailable"}}', 403);
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => now,
      );
      await expectLater(
        build(profile),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'entitlement_unavailable',
          ),
        ),
      );
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.subscription, subscription);
      expect(container.read(profilesProvider).single.id, profile.id);
    },
  );

  test(
    'runtime expiry converges automatic groups to REJECT without expiring authentication',
    () async {
      final profile = await sync();
      final routing = await activate(profile);
      await routing.run();
      expect(picks['zn.service.ai.auto'], 'zn.node.vless.7');
      now = bundleTime(1301);
      await routing.run();
      expect(picks['zn.service.ai.auto'], 'REJECT');
      expect(
        container.read(zolnitBundleStatusProvider),
        ZolnitBundleStatus.expired,
      );
      expect(fixture.session.authenticated, isTrue);
    },
  );

  test(
    'explicit manual choice survives expiry and an unavailable refresh',
    () async {
      final profile = await sync();
      final routing = await activate(profile);
      await routing.run();
      final owner = container.read(proxiesActionProvider.notifier);
      await owner.changeProxy(
        groupName: 'zn.service.ai',
        proxyName: 'zn.service.ai.manual',
      );
      await owner.changeProxy(
        groupName: 'zn.service.ai.manual',
        proxyName: 'zn.node.trojan.9',
      );
      await owner.updateGroups();
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"client_api_unavailable"}}', 503);
      now = bundleTime(1301);
      await routing.refreshBundle();
      expect(picks['zn.service.ai'], 'zn.service.ai.manual');
      expect(picks['zn.service.ai.manual'], 'zn.node.trojan.9');
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.clientBundleFailure, 'client_api_unavailable');
    },
  );
  test(
    'private automatic groups start rejected while explicit manual intent survives application',
    () async {
      final profile = await sync();
      final built = await build(profile);
      final routing = container.read(zolnitRoutingProvider);
      final selected = routing.preparedSelections(profile.id, built.md5, {
        'zn.service.ai': 'zn.service.ai.manual',
        'zn.service.ai.manual': 'zn.node.trojan.9',
        'zn.service.ai.auto': 'zn.node.vless.7',
      });
      expect(selected['zn.service.ai.auto'], 'REJECT');
      expect(selected['zn.service.ai'], 'zn.service.ai.manual');
      expect(selected['zn.service.ai.manual'], 'zn.node.trojan.9');
    },
  );

  for (final edge in [true, false]) {
    test(
      'edge/network error never recovers a cached manual profile ($edge)',
      () async {
        final profile = await sync();
        fixture.onBundle = (_) async {
          if (!edge) throw http.ClientException('PRIVATE network detail');
          return http.Response('<html>edge blocked</html>', 403);
        };
        await expectLater(
          container.read(zolnitSyncProfileProvider)(),
          throwsA(isA<ClientFailure>()),
        );
        final manual = profile.copyWith(
          selectedMap: {'zn.service.ai': 'zn.service.ai.manual'},
        );
        expect(
          cachedManualZolnitBundleProfile(
            [manual],
            fixture.session,
            enabled: true,
          ),
          isNull,
        );
        expect(fixture.session.authenticated, isTrue);
        verifyZeroInteractions(downloader);
      },
    );
  }

  test(
    'cached fallback requires explicit same-account manual intent and no authorization denial',
    () async {
      final profile = await sync();
      expect(
        cachedManualZolnitBundleProfile(
          [profile],
          fixture.session,
          enabled: true,
        ),
        isNull,
      );
      final manual = profile.copyWith(
        selectedMap: {'zn.service.ai': 'zn.service.ai.manual'},
      );
      expect(
        cachedManualZolnitBundleProfile(
          [manual],
          fixture.session,
          enabled: true,
        )?.id,
        profile.id,
      );
      fixture.onBundle = (_) async =>
          http.Response('{"error":{"code":"entitlement_unavailable"}}', 403);
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => now,
      );
      expect(
        cachedManualZolnitBundleProfile(
          [manual],
          fixture.session,
          enabled: true,
        ),
        isNull,
      );
      expect(fixture.session.authenticated, isTrue);
    },
  );
}
