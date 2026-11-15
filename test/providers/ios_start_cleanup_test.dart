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
  String? _appStart;
  var admitsStart = true;
  var _sequence = 0;

  void acceptExternalIntent(String intent) => latestIntent = intent;

  Object? reply(MethodCall call) {
    methods.add(call.method);
    switch (call.method) {
      case 'start':
        _appStart = null;
        if (!admitsStart) return false;
        latestIntent = _appStart = 'app-start-${++_sequence}';
        return true;
      case 'stop':
        _appStart = null;
        latestIntent = 'app-stop-${++_sequence}';
        return true;
      case 'abandonStart':
        final owned = _appStart;
        if (owned == null || latestIntent != owned) return 'notOwned';
        _appStart = null;
        latestIntent = 'app-stop-${++_sequence}';
        return 'stopped';
    }
    return null;
  }
}

class _FailingIosSetupAction extends SetupAction {
  void Function()? afterStartAccepted;

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
    ref.read(builtProfileTunProvider.notifier).value = (
      generation: Object(),
      identity: profileTunIdentity(
        ref.read(currentProfileProvider),
        ref.read(patchClashConfigProvider),
        ref.read(networkSettingProvider),
      ),
      tun: const ProfileTun(),
    );
    await preloadInvoke?.call();
    afterStartAccepted?.call();
    return false;
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

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() {
    runner = _FakeRunner();
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
        vpnOptionsProvider.overrideWith((_) => options),
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
