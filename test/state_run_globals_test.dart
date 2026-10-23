import 'package:fl_clash/providers/zolnit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zolnit_client/zolnit_client.dart';
import 'package:fl_clash/providers/zolnit_vault.dart';
import 'package:fl_clash/bootstrap.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';

import 'helpers/preferences.dart';

class _StartupSession extends Mock implements ZolnitSessionController {}

class _StartupApi extends Mock implements XboardClient {}

class _EmptyVault implements ZolnitSessionVault {
  @override
  Future<String?> readAuthorization() async => null;
  @override
  Future<void> writeAuthorization(String value) async {}
  @override
  Future<void> deleteAuthorization() async {}
}

class _StartupCore extends CoreAction {
  _StartupCore([this.events]);
  final List<String>? events;
  var starts = 0;

  @override
  Future<bool> startCore() async {
    events?.add('ownerReady');
    starts++;
    return true;
  }
}

class _StartupSetup extends SetupAction {
  _StartupSetup([this.events]);
  final List<String>? events;
  bool? autoRunAllowed;
  var starts = 0;

  @override
  void build() {}

  @override
  Future<void> initStatus({bool allowAutoRun = true}) async {
    autoRunAllowed = allowAutoRun;
    events?.add(allowAutoRun ? 'autoRunAllowed' : 'autoRunBlocked');
    starts++;
  }
}

class _StartupSystem extends SystemAction {
  var exits = 0;

  @override
  Future<void> updateTray() async {}

  @override
  Future<void> handleExit([bool needSave = true]) async => exits++;
}

class _StartupResources extends ResourcesAction {
  @override
  Future<void> autoUpdate() async {}
}

class _StartupCommon extends CommonAction {
  @override
  void build() {}

  @override
  Future<bool> autoCheckUpdate() async => false;
}

final _packageInfo = PackageInfo(
  appName: 'ZolNit',
  packageName: 'com.zolmid.zolnit',
  version: '1.2.3',
  buildNumber: '1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUpAll(() {
    globalState.packageInfo = _packageInfo;
  });

  setUp(() async {
    await mockPreferences();
    container = ProviderContainer();
    globalState.container = container;
  });

  tearDown(() {
    container.dispose();
    globalState.isAttach = false;
  });

  void setGlobalUa(String value) {
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(globalUa: value));
  }

  group('user agent', () {
    test('falls back to the package user agent when none is configured', () {
      setGlobalUa('');

      expect(globalState.ua, _packageInfo.ua);
      expect(globalState.ua, contains('ZolNit/v1.2.3'));
      expect(globalState.ua, contains('clash-verge'));
    });

    test('prefers the configured global user agent', () {
      setGlobalUa('custom-agent/1.0');

      expect(globalState.ua, 'custom-agent/1.0');
    });

    test('treats a blank configured user agent as unset', () {
      setGlobalUa('   ');

      expect(globalState.ua, _packageInfo.ua);
    });
  });

  group('attach', () {
    testWidgets('a first launch starts without disclaimer consent', (
      tester,
    ) async {
      final core = _StartupCore();
      final setup = _StartupSetup();
      final system = _StartupSystem();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          safeModeProvider.overrideWithValue(true),
          zolnitSessionVaultProvider.overrideWithValue(_EmptyVault()),
          coreActionProvider.overrideWith(() => core),
          setupActionProvider.overrideWith(() => setup),
          systemActionProvider.overrideWith(() => system),
          resourcesActionProvider.overrideWith(_StartupResources.new),
          commonActionProvider.overrideWith(_StartupCommon.new),
        ],
      );
      globalState.container = container;
      container.listen(appSettingProvider, (_, _) {});
      const freshSettings = AppSettingProps();
      expect(container.read(appSettingProvider), freshSettings);
      expect(freshSettings.acceptedDisclaimerVersion, 0);
      const channel = MethodChannel('window');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      container.listen(currentProfileIdProvider, (_, _) {});
      await bootstrap.attach();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(core.starts, 1);
      expect(setup.starts, 1);
      expect(setup.autoRunAllowed, isFalse);
      expect(system.exits, 0);
      expect(container.read(initProvider), isTrue);
      expect(globalState.isAttach, isTrue);
      expect(container.read(appSettingProvider), freshSettings);
      expect(await preferences.getConfigMap(), isNull);
      expect(tester.takeException(), isNull);
    });

    for (final remainsSignedIn in [true, false]) {
      testWidgets(
        'startup gates auto-connect after managed sync (valid: $remainsSignedIn)',
        (tester) async {
          final events = <String>[];
          final session = _StartupSession();
          final api = _StartupApi();
          var authenticated = false;
          var generation = 0;
          when(() => session.api).thenReturn(api);
          when(() => api.generation).thenAnswer((_) => generation);
          when(() => session.authenticated).thenAnswer((_) => authenticated);
          when(() => session.restore()).thenAnswer((_) async {
            events.add('restore');
            authenticated = true;
          });
          final core = _StartupCore(events);
          final setup = _StartupSetup(events);
          container.dispose();
          container = ProviderContainer(
            overrides: [
              safeModeProvider.overrideWithValue(true),
              zolnitSessionProvider.overrideWithValue(session),
              zolnitSyncProfileProvider.overrideWithValue(() async {
                events.add('managedSync');
                if (!remainsSignedIn) {
                  authenticated = false;
                  generation++;
                }
                return 71;
              }),
              appSettingProvider.overrideWithBuild(
                (_, _) => const AppSettingProps(autoRun: true),
              ),
              coreActionProvider.overrideWith(() => core),
              setupActionProvider.overrideWith(() => setup),
              systemActionProvider.overrideWith(_StartupSystem.new),
              resourcesActionProvider.overrideWith(_StartupResources.new),
              commonActionProvider.overrideWith(_StartupCommon.new),
            ],
          );
          globalState.container = container;
          const channel = MethodChannel('window');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (_) async => false,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          container.listen(currentProfileIdProvider, (_, _) {});
          await bootstrap.attach();
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(events, [
            'ownerReady',
            'restore',
            'managedSync',
            remainsSignedIn ? 'autoRunAllowed' : 'autoRunBlocked',
          ]);
          expect(setup.autoRunAllowed, remainsSignedIn);
          expect(
            container.read(currentProfileIdProvider),
            remainsSignedIn ? 71 : null,
          );
        },
      );
    }

    test('an already attached app never re-runs startup', () async {
      globalState.isAttach = true;

      container.listen(currentProfileIdProvider, (_, _) {});
      await bootstrap.attach();

      expect(globalState.isAttach, isTrue);
      expect(
        container.read(initProvider),
        isFalse,
        reason: 'startup must not have run a second time',
      );
    });
  });

  group('canCrashCoreFor', () {
    test('allows a forced Core crash in debug and on the dev channel', () {
      expect(
        GlobalState.canCrashCoreFor(isDebug: true, appEnv: 'stable'),
        isTrue,
      );
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'dev'),
        isTrue,
      );
    });

    test('never allows a forced Core crash in a release build', () {
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'stable'),
        isFalse,
      );
      expect(
        GlobalState.canCrashCoreFor(isDebug: false, appEnv: 'pre'),
        isFalse,
      );
    });
  });
}
