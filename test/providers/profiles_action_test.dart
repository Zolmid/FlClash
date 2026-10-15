import 'dart:io';
import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _SingleFlightProfilesAction extends ProfilesAction {
  final response = Completer<Profile>();
  var requests = 0;

  @override
  Future<Profile> fetchUpdatedProfile(Profile profile) {
    requests++;
    return response.future;
  }
}

class _QueuedProfilesAction extends ProfilesAction {
  final requests = <Profile>[];
  final responses = <Completer<Profile>>[];

  @override
  Future<Profile> fetchUpdatedProfile(Profile profile) {
    requests.add(profile);
    final response = Completer<Profile>();
    responses.add(response);
    return response.future;
  }
}

class _NoProfileApply extends SetupAction {
  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;
  late _MockCoreHandlerInterface core;
  late ProviderContainer container;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    home = Directory.systemTemp.createTempSync('flclash-profiles-action-');
    AppPath.supportDirectory = () async => home;
    AppPath.temporaryDirectory = () async => home;
    AppPath.cacheDirectory = () async => home;
    AppPath.downloadDirectory = () async => home;
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  setUp(() {
    core = _MockCoreHandlerInterface();
    when(() => core.validateConfig(any())).thenAnswer((_) async => '');
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
  });

  void decodesTo(String link, List<Map<String, dynamic>> proxies) {
    when(
      () => core.decodeShareLinks([link]),
    ).thenAnswer((_) async => [proxies]);
  }

  Future<void> pumpHost(WidgetTester tester) async {
    const size = Size(1200, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(withStatusManager: true, child: SizedBox()),
      ),
    );
  }

  Future<List<Map>> savedProxies(Profile profile) async {
    final config = loadYaml(await (await profile.file).readAsString()) as Map;
    return [for (final proxy in config['proxies'] as List) proxy as Map];
  }

  test(
    'manual and automatic refreshes share the same in-flight profile update',
    () async {
      const profile = Profile(
        id: 42,
        type: ProfileType.url,
        url: 'https://example.com',
        autoUpdateDuration: Duration(minutes: 20),
      );
      final action = _SingleFlightProfilesAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          profilesActionProvider.overrideWith(() => action),
          setupActionProvider.overrideWith(_NoProfileApply.new),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(profilesActionProvider.notifier);

      final automatic = action.autoUpdateProfiles();
      final manual = action.updateProfile(profile, showLoading: true);
      expect(action.requests, 1);
      final updated = profile.copyWith(lastUpdateDate: DateTime(2026, 10, 15));
      action.response.complete(updated);
      await Future.wait([automatic, manual]);
      expect(
        scoped.read(profilesProvider).single.lastUpdateDate,
        updated.lastUpdateDate,
      );
      expect(action.lastUpdateAttempt(profile.id), isNotNull);
    },
  );

  test('failed manual refreshes record an attempt for the scheduler', () async {
    const profile = Profile(
      id: 42,
      type: ProfileType.url,
      url: 'https://example.com',
      autoUpdateDuration: Duration(minutes: 20),
    );
    final action = _SingleFlightProfilesAction();
    final scoped = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        profilesActionProvider.overrideWith(() => action),
      ],
    );
    addTearDown(scoped.dispose);
    scoped.read(profilesActionProvider.notifier);
    final operation = action.updateProfile(profile);
    action.response.completeError(StateError('offline'));

    await expectLater(operation, throwsStateError);
    expect(action.lastUpdateAttempt(profile.id), isNotNull);
    expect(scoped.read(profilesProvider).single.lastUpdateDate, isNull);
  });

  for (final fails in [false, true]) {
    test(
      'source edits wait for an active refresh without being lost ($fails)',
      () async {
        const profile = Profile(
          id: 42,
          type: ProfileType.url,
          url: 'https://old.example.com',
          autoUpdateDuration: Duration(minutes: 20),
        );
        final edited = profile.copyWith(
          url: 'https://new.example.com',
          ageSecretKey: 'AGE-SECRET-KEY-NEW',
        );
        final action = _QueuedProfilesAction();
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            profilesActionProvider.overrideWith(() => action),
            setupActionProvider.overrideWith(_NoProfileApply.new),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          ],
        );
        addTearDown(scoped.dispose);
        scoped.read(profilesActionProvider.notifier);
        final active = action.updateProfile(profile);
        final activeResult = expectLater(
          active,
          fails ? throwsStateError : completes,
        );
        final saved = action.updateProfile(edited);
        expect(action.requests, [profile]);
        if (fails) {
          action.responses.first.completeError(StateError('old URL offline'));
        } else {
          action.responses.first.complete(
            profile.copyWith(lastUpdateDate: DateTime(2026, 10, 15)),
          );
        }
        await activeResult;
        await pumpEventQueue();
        expect(action.requests, [profile, edited]);
        action.responses.last.complete(
          edited.copyWith(lastUpdateDate: DateTime(2026, 10, 16)),
        );
        await saved;
        expect(scoped.read(profilesProvider).single.url, edited.url);
        expect(
          scoped.read(profilesProvider).single.ageSecretKey,
          edited.ageSecretKey,
        );
      },
    );

    test(
      'startup file recovery joins the scheduler and awaits the latest source ($fails)',
      () async {
        const profile = Profile(
          id: 7501,
          type: ProfileType.url,
          url: 'https://old.example.com',
          autoUpdateDuration: Duration(minutes: 20),
        );
        final edited = profile.copyWith(
          url: 'https://new.example.com',
          ageSecretKey: 'AGE-SECRET-KEY-NEW',
        );
        final action = _QueuedProfilesAction();
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            profilesActionProvider.overrideWith(() => action),
            setupActionProvider.overrideWith(_NoProfileApply.new),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          ],
        );
        addTearDown(scoped.dispose);
        scoped.read(profilesActionProvider.notifier);
        final errors = <Object>[];
        final updater = ProfileAutoUpdater(
          profiles: () => scoped.read(profilesProvider),
          update: action.updateProfile,
          onError: errors.add,
        );
        addTearDown(updater.dispose);
        updater.start();
        final scheduled = updater.check();
        var ready = false;
        final startup = action
            .ensureProfileFile(profile.id)
            .then((_) => ready = true);
        await pumpEventQueue();
        expect(action.requests, [profile]);
        final saved = action.updateProfile(edited);
        if (fails) {
          action.responses.first.completeError(StateError('old URL offline'));
        } else {
          action.responses.first.complete(
            profile.copyWith(lastUpdateDate: DateTime.now()),
          );
        }
        await scheduled;
        await pumpEventQueue();
        expect(action.requests, [profile, edited]);
        expect(ready, isFalse);
        action.responses.last.complete(
          edited.copyWith(lastUpdateDate: DateTime.now()),
        );
        await Future.wait([saved, startup]);
        expect(ready, isTrue);
        expect(errors, hasLength(fails ? 1 : 0));
        expect(scoped.read(currentProfileProvider)?.url, edited.url);
        expect(
          scoped.read(currentProfileProvider)?.ageSecretKey,
          edited.ageSecretKey,
        );
        updater.dispose();
      },
    );
  }

  group('addProfileFromLink with a share link', () {
    test('saves a file profile named after the proxy it holds', () async {
      const link = 'vless://id@hk.example.com:443#HK';
      decodesTo(link, [
        {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);

      final profile = container.read(profilesProvider).single;
      expect(profile.type, ProfileType.file);
      expect(profile.url, isEmpty);
      expect(profile.label, 'HK');
      expect(await savedProxies(profile), [
        {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
      ]);
      verify(() => core.validateConfig(any())).called(1);
    });

    test('names an unnamed proxy after its server', () async {
      const link = 'ss://YWVzLTEyOC1nY206cGFzcw@ss.example.com:8388';
      decodesTo(link, [
        {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link, label: 'Mine');

      final profile = container.read(profilesProvider).single;
      expect(profile.label, 'Mine');
      expect((await savedProxies(profile)).single['name'], 'ss.example.com');
    });

    test('moves a proxy off a name mihomo reserves', () async {
      const link = 'trojan://pass@t.example.com:443#DIRECT';
      decodesTo(link, [
        {'name': 'DIRECT', 'type': 'trojan', 'server': 't.example.com'},
      ]);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);

      final profile = container.read(profilesProvider).single;
      expect((await savedProxies(profile)).single['name'], 'DIRECT-01');
    });

    testWidgets('reports a link no proxy can be read from and adds nothing', (
      tester,
    ) async {
      const link = 'vmess://not-base64';
      decodesTo(link, const []);
      await pumpHost(tester);

      await container
          .read(profilesActionProvider.notifier)
          .addProfileFromLink(link);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text(currentAppLocalizations.shareLinksInvalid), findsOne);
      expect(container.read(profilesProvider), isEmpty);
      verifyNever(() => core.validateConfig(any()));
    });
  });

  group('addProfilesFromLinks with share links', () {
    const links = [
      'vless://id@hk.example.com:443#HK',
      'trojan://pass@hk2.example.com:443#HK',
      'ss://YWVzLTEyOC1nY206cGFzcw@ss.example.com:8388',
    ];

    test('makes one profile of all their proxies', () async {
      when(() => core.decodeShareLinks(links)).thenAnswer(
        (_) async => [
          [
            {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
          ],
          [
            {'name': 'HK', 'type': 'trojan', 'server': 'hk2.example.com'},
          ],
          [
            {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
          ],
        ],
      );

      await container
          .read(profilesActionProvider.notifier)
          .addProfilesFromLinks(links);

      final profile = container.read(profilesProvider).single;
      expect(profile.type, ProfileType.file);
      expect(
        profile.label,
        currentAppLocalizations.proxiesProfileLabel('HK', 3),
      );
      expect(
        [for (final proxy in await savedProxies(profile)) proxy['name']],
        ['HK', 'HK-01', 'ss.example.com'],
      );
      verify(() => core.decodeShareLinks(links)).called(1);
    });

    testWidgets('names the link no proxy can be read from and adds nothing', (
      tester,
    ) async {
      when(() => core.decodeShareLinks(links)).thenAnswer(
        (_) async => [
          [
            {'name': 'HK', 'type': 'vless', 'server': 'hk.example.com'},
          ],
          const [],
          [
            {'name': '', 'type': 'ss', 'server': 'ss.example.com'},
          ],
        ],
      );
      await pumpHost(tester);

      await container
          .read(profilesActionProvider.notifier)
          .addProfilesFromLinks(links);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final l10n = currentAppLocalizations;
      expect(
        find.text(
          l10n.failedItem(links.first, l10n.shareLinkUnreadable(links[1])),
        ),
        findsOne,
      );
      expect(container.read(profilesProvider), isEmpty);
      verifyNever(() => core.validateConfig(any()));
    });
  });
}
