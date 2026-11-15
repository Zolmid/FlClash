import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/lib.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

/// The Runner's reply contract, modelled on one authority record: every
/// accepted command becomes the latest intent and replaces whoever held it.
class _FakeRunner {
  final methods = <String>[];
  String? latestIntent;
  var admitsStart = true;
  var _sequence = 0;

  void acceptExternalIntent(String intent) => latestIntent = intent;

  Object? reply(MethodCall call) {
    methods.add(call.method);
    switch (call.method) {
      case 'start':
        if (!admitsStart) return false;
        return latestIntent = 'app-start-${++_sequence}';
      case 'stop':
        latestIntent = 'app-stop-${++_sequence}';
        return true;
      case 'abandonStart':
        final owned = call.arguments as String?;
        if (owned == null || latestIntent != owned) return 'notOwned';
        latestIntent = 'app-stop-${++_sequence}';
        return 'stopped';
    }
    return null;
  }
}

class _FailingIosSetupAction extends SetupAction {
  void Function()? afterStartAccepted;
  bool failBeforeHandoff = false;
  bool applySucceeds = false;
  final preloads = <Future<void> Function()>[];

  @override
  bool get listenerManagedByService => true;

  @override
  void resetCoreTraffic() {}

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    if (failBeforeHandoff) return false;
    ref.read(builtProfileTunProvider.notifier).value = (
      generation: Object(),
      identity: profileTunIdentity(
        ref.read(currentProfileProvider),
        ref.read(patchClashConfigProvider),
        ref.read(networkSettingProvider),
      ),
      tun: const ProfileTun(),
    );
    if (preloadInvoke != null) preloads.add(preloadInvoke);
    await preloadInvoke?.call();
    afterStartAccepted?.call();
    return applySucceeds;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('$packageName/service');
  const options = VpnOptions(
    enable: true,
    port: 7890,
    ipv6: false,
    dnsHijacking: true,
    accessControlProps: AccessControlProps(),
    allowBypass: false,
    systemProxy: false,
    bypassDomain: [],
    stack: 'mixed',
    mtu: 1500,
  );

  late _FakeRunner runner;
  late Service service;
  late ProviderContainer container;
  late _FailingIosSetupAction action;
  var rejectOptions = false;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    runner = _FakeRunner();
    rejectOptions = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => runner.reply(call));
    service = Service.forTesting(isIOS: true);
    final profile = Profile.custom(label: 'A').copyWith(id: 1);
    action = _FailingIosSetupAction();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        coreHandlerProvider.overrideWithValue(
          CoreController.scoped(
            CoreLib.scoped(service, listenerManagedByService: true),
          ),
        ),
        setupActionProvider.overrideWith(() => action),
        vpnOptionsProvider.overrideWith((_) {
          if (rejectOptions) {
            throw StateError('VPN options unavailable before handoff');
          }
          return options;
        }),
        sharedStateProvider.overrideWith(
          (_) => const SharedState(
            stopTip: '',
            startTip: '',
            localNetworkTip: '',
            currentProfileName: 'A',
            stopText: '',
            onlyStatisticsProxy: false,
          ),
        ),
      ],
    );
    globalState.container = container;
    container.read(setupActionProvider.notifier);
  });

  tearDown(() {
    container.dispose();
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    globalState.needInitStatus = true;
  });

  Future<bool> failedAutomaticStart() => action
      .setRunning(true, initialize: true)
      .timeout(const Duration(seconds: 5));

  group('iOS failed start cleanup', () {
    test('B rejected resolving options never cleans up admitted A', () async {
      action.applySucceeds = true;
      expect(await failedAutomaticStart(), isTrue);
      final acceptedA = runner.latestIntent;
      runner.methods.clear();
      rejectOptions = true;
      container.invalidate(vpnOptionsProvider);
      action.applySucceeds = false;

      expect(await failedAutomaticStart(), isFalse);

      expect(runner.latestIntent, acceptedA);
      expect(runner.methods, isEmpty);
    });

    test(
      'late admission reply for A is not assigned to unadmitted B',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final reply = runner.reply(call);
              if (call.method == 'start') {
                entered.complete();
                await release.future;
              }
              return reply;
            });
        final first = failedAutomaticStart();
        await entered.future.timeout(const Duration(seconds: 2));
        final acceptedA = runner.latestIntent;
        action.failBeforeHandoff = true;
        final second = failedAutomaticStart();
        release.complete();

        expect(await first, isTrue);
        expect(await second, isFalse);
        expect(runner.latestIntent, acceptedA);
        expect(runner.methods, ['start']);
      },
    );

    test('a stale preload retry cannot claim the next operation', () async {
      action.applySucceeds = true;
      expect(await failedAutomaticStart(), isTrue);
      final obsoletePreload = action.preloads.single;
      expect(await failedAutomaticStart(), isTrue);
      final acceptedB = runner.latestIntent;
      runner.methods.clear();

      await obsoletePreload();
      action.failBeforeHandoff = true;
      expect(await failedAutomaticStart(), isFalse);

      expect(runner.latestIntent, acceptedB);
      expect(runner.methods, isEmpty);
    });

    test(
      'B fails before handoff without consuming completed start A',
      () async {
        action.applySucceeds = true;
        expect(await failedAutomaticStart(), isTrue);
        final acceptedA = runner.latestIntent;
        runner.methods.clear();
        action
          ..applySucceeds = false
          ..failBeforeHandoff = true;

        expect(await failedAutomaticStart(), isFalse);

        expect(runner.latestIntent, acceptedA);
        expect(runner.methods, isEmpty);
      },
    );

    test('owned admitted B failure cleans B up after completed A', () async {
      action.applySucceeds = true;
      expect(await failedAutomaticStart(), isTrue);
      final acceptedA = runner.latestIntent;
      runner.methods.clear();
      action.applySucceeds = false;

      expect(await failedAutomaticStart(), isFalse);

      expect(runner.methods.first, 'start');
      expect(runner.latestIntent, isNot(acceptedA));
      expect(runner.latestIntent, startsWith('app-stop-'));
    });

    test(
      'a start superseded before admission leaves the newer intent',
      () async {
        runner
          ..admitsStart = false
          ..acceptExternalIntent('widget-start');

        expect(await failedAutomaticStart(), isFalse);

        expect(runner.methods, isNot(contains('stop')));
        expect(runner.latestIntent, 'widget-start');
        expect(container.read(runTimeProvider), isNull);
      },
    );

    test(
      'an accepted start superseded before cleanup leaves the newer intent',
      () async {
        action.afterStartAccepted = () =>
            runner.acceptExternalIntent('widget-start');

        expect(await failedAutomaticStart(), isFalse);

        expect(runner.methods.first, 'start');
        expect(runner.methods, isNot(contains('stop')));
        expect(runner.latestIntent, 'widget-start');
        expect(container.read(runTimeProvider), isNull);
      },
    );

    test('a failed start that still owns the intent is stopped', () async {
      expect(await failedAutomaticStart(), isFalse);

      expect(runner.methods.first, 'start');
      expect(runner.latestIntent, startsWith('app-stop-'));
      expect(container.read(runTimeProvider), isNull);
    });

    test('an explicit stop replaces a newer external start', () async {
      runner.acceptExternalIntent('widget-start');

      expect(await action.setRunning(false), isTrue);

      expect(runner.methods, ['stop']);
      expect(runner.latestIntent, startsWith('app-stop-'));
    });
  });
}
