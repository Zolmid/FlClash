import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/zolnit_native_renewal.dart';
import 'package:fl_clash/providers/zolnit_native_renewal.dart';
import 'package:fl_clash/providers/zolnit_vault.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/ios_setup_handoff.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Session extends Mock implements ZolnitSessionController {}

class _Api extends Mock implements XboardClient {}

class _Signed extends Mock implements ZolnitSignedSubscriptions {}

class _Journal implements ZolnitRenewalJournal {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Vault implements ZolnitSessionVault {
  String? value = 'Bearer synthetic-fixture';
  @override
  Future<String?> readAuthorization() async => value;
  @override
  Future<void> writeAuthorization(String value) async {}
  @override
  Future<void> deleteAuthorization() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'prepared setup survives actual iOS start and sync serialization, then invalidates',
    () async {
      await mockPreferences();
      await AppLocalizations.load(const Locale('en'));
      final session = _Session();
      final api = _Api();
      final signed = _Signed();
      when(() => session.signedSubscriptions).thenReturn(signed);
      when(() => signed.active).thenReturn((
        accountId: 'fixture-account',
        device: const ZolnitClientDevice(
          deviceId: 'fixture-device',
          installationId: 'fixture-installation',
        ),
        serial: 7,
        intent: 3,
      ));
      var generation = 1;
      var authenticated = true;
      VoidCallback? changed;
      when(() => session.api).thenReturn(api);
      when(() => session.authenticated).thenAnswer((_) => authenticated);
      when(() => api.generation).thenAnswer((_) => generation);
      when(() => session.addListener(any())).thenAnswer((call) {
        changed = call.positionalArguments.single as VoidCallback;
      });
      final profile = Profile.custom(label: 'managed').copyWith(
        id: 1,
        zolnitAccountId: 'fixture-account',
        zolnitBundleId: 'bundle',
        zolnitOrigin: 'https://link.zolmid.com',
        selectedMap: {'automatic': 'old-node'},
      );
      var dnsRequired = true;
      var configurations = 0;
      final entered = Completer<void>();
      final configured = Completer<Object?>();
      final journal = _Journal();
      final vault = _Vault();
      final nativeClient = ZolnitNativeRenewalClient(
        journal: journal,
        call: (method, arguments) async {
          configurations++;
          expect(method, 'configureClientBundleRenewal');
          expect(arguments?['accountId'], 'fixture-account');
          expect(arguments?['deviceId'], 'fixture-device');
          if (!entered.isCompleted) entered.complete();
          return configured.future;
        },
      );
      addTearDown(nativeClient.dispose);
      final container = ProviderContainer(
        overrides: [
          iosSetupHandoffEnabledProvider.overrideWithValue(true),
          iosOwnedDNSRequiredProvider.overrideWith((ref) => dnsRequired),
          zolnitNativeRenewalClientProvider.overrideWithValue(nativeClient),
          zolnitSessionVaultProvider.overrideWithValue(vault),
          zolnitSessionProvider.overrideWithValue(session),
          profilesProvider.overrideWith(
            () => TestProfiles([
              profile,
              Profile.custom(label: 'legacy').copyWith(id: 2),
            ]),
          ),
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(sharedStateProvider, (_, _) {});
      addTearDown(subscription.close);
      const prepared = SetupParams(
        selectedMap: {'automatic': 'REJECT'},
        testUrl: 'https://example.invalid',
        routingLease: {
          'accountId': 'fixture-account',
          'accountGeneration': 1,
          'signedDeviceId': 'fixture-device',
          'signedSerial': 7,
          'expiresAt': 4102444800000,
          'signedIntent': 3,
          'configurationDigest': 'fixture-digest',
          'bundleId': 'bundle',
        },
      );
      container
          .read(iosSetupHandoffProvider.notifier)
          .prepare(prepared, profileId: profile.id);
      final calls = <Map<String, dynamic>>[];
      final service = Service.forTesting(isIOS: true);
      addTearDown(service.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(service.methodChannel, (call) async {
            calls.add(
              jsonDecode(call.arguments as String) as Map<String, dynamic>,
            );
            return call.method == 'start' ? 'fixture-receipt' : '';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(service.methodChannel, null),
      );
      const options = VpnOptions(
        enable: true,
        port: 7890,
        ipv6: false,
        dnsHijacking: true,
        accessControlProps: AccessControlProps(),
        allowBypass: false,
        systemProxy: false,
        bypassDomain: [],
        stack: 'mips',
      );
      final start = container
          .read(iosSetupHandoffProvider.notifier)
          .startAuthorized(
            params: prepared,
            isCurrent: () => true,
            dispatch: () => service.start(
              container.read(sharedStateProvider).copyWith(vpnOptions: options),
            ),
          );
      await entered.future;
      expect(calls, isEmpty);
      configured.complete({
        'supported': true,
        'sessionEpoch': 1,
        'ownerId': 1,
        'state': 'waiting_for_tunnel',
      });
      expect(await start, isTrue);
      expect(journal.value, isNot(contains('synthetic-fixture')));
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(testUrl: 'changed'));
      await service.syncState(container.read(sharedStateProvider));
      for (final payload in calls) {
        expect(payload['setupParams'], prepared.toJson());
        expect(jsonEncode(payload), isNot(contains('authorization')));
      }
      if (Platform.isMacOS) {
        final directory = await Directory.systemTemp.createTemp(
          'zn-handoff-wire.',
        );
        try {
          final wire = File('${directory.path}/shared.json');
          expect(calls.first['vpnOptions'], isA<Map>());
          await wire.writeAsString(jsonEncode(calls.first));
          final native = await Process.run('bash', [
            'tool/acceptance/ios_intents/run_setup_handoff.sh',
            wire.path,
          ]);
          expect(
            native.exitCode,
            0,
            reason: '${native.stdout}\n${native.stderr}',
          );
          expect(native.stdout, contains('PASS widget cold start reprojects'));
        } finally {
          await directory.delete(recursive: true);
        }
      }
      expect(
        container
            .read(iosSetupHandoffProvider.notifier)
            .prepare(
              prepared.copyWith(
                routingLease: {...prepared.routingLease!, 'signedSerial': 8},
              ),
              profileId: profile.id,
            ),
        isTrue,
      );
      container
          .read(iosSetupHandoffProvider.notifier)
          .prepare(prepared, profileId: profile.id);
      expect(
        container
            .read(iosSetupHandoffProvider.notifier)
            .prepare(
              prepared.copyWith(
                routingLease: {...prepared.routingLease!, 'signedIntent': 2},
              ),
              profileId: profile.id,
            ),
        isFalse,
      );
      expect(container.read(iosSetupHandoffProvider), prepared);
      dnsRequired = false;
      container.invalidate(iosOwnedDNSRequiredProvider);
      expect(
        await container
            .read(iosSetupHandoffProvider.notifier)
            .startAuthorized(
              params: prepared,
              isCurrent: () => true,
              dispatch: () async => true,
            ),
        isTrue,
      );
      expect(configurations, 1);
      dnsRequired = true;
      container.invalidate(iosOwnedDNSRequiredProvider);
      vault.value = null;
      await expectLater(
        container
            .read(iosSetupHandoffProvider.notifier)
            .startAuthorized(
              params: prepared,
              isCurrent: () => true,
              dispatch: () async =>
                  throw StateError('missing credentials dispatched a start'),
            ),
        throwsA(isA<ClientFailure>()),
      );
      expect(configurations, 1);
      authenticated = false;
      generation++;
      changed!();
      expect(container.read(sharedStateProvider).setupParams?.routingLease, {
        'signedDeviceId': 'unprepared',
      });
      container.read(currentProfileIdProvider.notifier).value = 2;
      expect(
        container.read(sharedStateProvider).setupParams?.routingLease,
        isNull,
      );
      expect(
        container.read(sharedStateProvider).setupParams?.selectedMap,
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
