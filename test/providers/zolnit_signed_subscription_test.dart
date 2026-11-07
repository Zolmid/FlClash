import 'dart:convert';

import 'package:fl_clash/common/zolnit_native_renewal.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/providers/zolnit_signed_subscription.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

const _installation = 'aW5zdGFsbGF0aW9uLXNlY3JldC1maXh0dXJlLTMyYnk';
const _device = '0123456789abcdef0123456789abcdef';

class _Core extends CoreHandlerInterface {
  final calls = <(CoreMethod, Object?)>[];
  Object? Function(CoreMethod method, Object? arguments)? answer;

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls.add((method, arguments));
    return answer?.call(method, arguments) as T?;
  }

  static const _unused = CoreLifecycleResult(
    revision: 0,
    outcome: CoreLifecycleOutcome.applied,
  );
  @override
  Future<CoreLifecycleResult> start() async => _unused;
  @override
  Future<CoreLifecycleResult> restart() async => _unused;
  @override
  Future<CoreLifecycleResult> stop() async => _unused;
  @override
  Future<CoreLifecycleResult> close() async => _unused;
}

void main() {
  late _Core core;
  late CoreSignedSubscriptionOwner owner;
  setUp(() {
    core = _Core();
    owner = CoreSignedSubscriptionOwner(CoreController.scoped(core));
  });

  test(
    'current projection is bound to the observed active Core lease',
    () async {
      final lease = <String, dynamic>{
        'instanceId': 'core-fixture',
        'token': 'current-token',
        'configurationGeneration': 2,
        'accountId': '2',
        'accountGeneration': 3,
        'bundleId': 'installed-bundle',
        'configurationDigest': 'current-digest',
        'expiresAt': 1300000,
      };
      var response = <String, Object?>{
        'lease': lease,
        'body': jsonEncode({
          'data': {
            'account_id': '2',
            'bundle_id': 'installed-bundle',
            'expires_at': 1300,
          },
        }),
        'state': {
          'available': true,
          'hasFloor': true,
          'installed': true,
          'serial': 2,
          'intent': 4,
        },
      };
      core.answer = (method, arguments) {
        expect(method, CoreMethod.projectSignedSubscription);
        expect(arguments, {
          'accountId': '2',
          'deviceId': _device,
          'intent': 4,
          'current': true,
          'lease': lease,
        });
        return response;
      };
      final current = await owner.current(
        accountId: '2',
        deviceId: _device,
        intent: 4,
        lease: lease,
      );
      expect(current.data['bundle_id'], 'installed-bundle');
      expect(current.state.serial, 2);
      expect(current.intent, 4);
      for (final change in [
        {
          'lease': {...lease, 'token': 'old-token'},
        },
        {
          'state': {'intent': 3},
        },
        {
          'body': jsonEncode({
            'data': {
              'account_id': 'other',
              'bundle_id': 'installed-bundle',
              'expires_at': 1300,
            },
          }),
        },
        {
          'body': jsonEncode({
            'data': {
              'account_id': '2',
              'bundle_id': 'installed-bundle',
              'expires_at': 1400,
            },
          }),
        },
      ]) {
        final original = response;
        response = {...response, ...change};
        await expectLater(
          owner.current(
            accountId: '2',
            deviceId: _device,
            intent: 4,
            lease: lease,
          ),
          throwsA(isA<ClientFailure>()),
        );
        response = original;
      }
    },
  );

  test(
    'the Core is asked to verify, commit and project signed material',
    () async {
      core.answer = (method, arguments) => switch (method) {
        CoreMethod.getSignedSubscription => {
          'available': (arguments as Map).isNotEmpty,
          'intent': 0,
          'installed': true,
          'subscriptionExpiresAt': 100000,
        },
        CoreMethod.applySignedSubscription => {
          'available': true,
          'installed': true,
          'serial': 2,
        },
        CoreMethod.projectSignedSubscription => {
          'body': jsonEncode({
            'data': {'schema_version': 1, 'account_id': '2'},
          }),
        },
        _ => true,
      };
      expect(await owner.available(), isNull);
      final state = await owner.status(accountId: '2', deviceId: _device);
      expect(state.subscriptionExpiresAt, DateTime.utc(1970, 1, 2, 3, 46, 40));
      expect(
        (await owner.apply(
          accountId: '2',
          deviceId: _device,
          envelope: '{}',
          intent: 0,
        )).serial,
        2,
      );
      expect(
        (await owner.project(accountId: '2', deviceId: _device))['account_id'],
        '2',
      );
      await owner.signOut(0);
      expect(core.calls.map((call) => call.$1), [
        CoreMethod.getSignedSubscription,
        CoreMethod.getSignedSubscription,
        CoreMethod.applySignedSubscription,
        CoreMethod.projectSignedSubscription,
        CoreMethod.signOutSignedSubscription,
      ]);
      expect(core.calls[2].$2, {
        'accountId': '2',
        'deviceId': _device,
        'envelope': '{}',
        'intent': 0,
      });
    },
  );

  test(
    'Core refusals keep their signed code; transport loss does not',
    () async {
      core.answer = (method, _) => throw const CoreMethodException(
        code: 'subscription_tombstone',
        message: 'subscription_tombstone',
      );
      await expectLater(
        owner.project(accountId: '2', deviceId: _device),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'subscription_tombstone',
          ),
        ),
      );
      core.answer = (method, _) => throw const CoreMethodException(
        code: 'transport_disconnected',
        message: 'gone',
      );
      await expectLater(
        owner.available(),
        throwsA(
          isA<ClientFailure>().having(
            (e) => e.code,
            'code',
            'core_unavailable',
          ),
        ),
      );
    },
  );

  test('only signed subscription methods take the unlogged path', () {
    expect(
      () => core.signedSubscription(CoreMethod.setupConfig, const {}),
      throwsArgumentError,
    );
  });

  test('session invalidation and logout carry the observed intent', () async {
    core.answer = (method, _) => switch (method) {
      CoreMethod.getSignedSubscription => {'available': true, 'intent': 4},
      CoreMethod.invalidateSignedSubscription => 5,
      CoreMethod.signOutSignedSubscription => true,
      _ => null,
    };
    expect(await owner.invalidate(), 5);
    await owner.signOut(5);
    expect(core.calls[1].$2, {'intent': 4});
    expect(core.calls[2].$2, {'intent': 5});
  });

  test(
    'native renewal receives the signed device only when negotiated',
    () async {
      final received = <Map<String, Object?>?>[];
      final client = ZolnitNativeRenewalClient(
        journal: _Journal(),
        call: (method, arguments) async {
          received.add(arguments);
          return {'supported': true, 'sessionEpoch': 1, 'ownerId': 1};
        },
      );
      addTearDown(client.dispose);
      Future<void> configure(ZolnitClientDevice? device) => client.configure(
        accountId: '2',
        accountGeneration: 1,
        authorization: 'Bearer SYNTHETIC_ONLY',
        distribution: 'direct',
        signedDevice: device,
      );
      await configure(null);
      await configure(
        const ZolnitClientDevice(
          deviceId: _device,
          installationId: _installation,
        ),
      );
      expect(received[0]!.containsKey('deviceId'), isFalse);
      expect(received[1]!['deviceId'], _device);
      expect(received[1]!['installationId'], _installation);
    },
  );
}

class _Journal implements ZolnitRenewalJournal {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}
