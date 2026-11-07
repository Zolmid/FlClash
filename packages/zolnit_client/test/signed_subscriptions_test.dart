import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zolnit_client/zolnit_client.dart';

import 'client_bundle_fixture.dart';

const _device = '0123456789abcdef0123456789abcdef';
const _seedHex =
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';
const _publicHex =
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

Future<Json> _envelope(String kind, int serial, {String account = '2'}) async {
  final payload = <String, dynamic>{
    'schema_version': 2,
    'issuer': 'https://link.zolmid.com',
    'audience': 'zolnit-client-subscription-v2',
    'kind': kind,
    'account_id': account,
    'device_id': _device,
    'serial': serial,
    'issued_at': 1000,
    'expires_at': kind == 'revoked' ? null : 100000,
    'bundle_id': 'bundle-$serial',
    if (kind == 'bundle') ...{
      'connection': <String, dynamic>{'document': 'x'},
      'outbounds': <dynamic>[],
      'routing': <String, dynamic>{'nodes': <dynamic>[]},
    },
    if (kind == 'state') ...{
      'current_bundle_id': 'bundle-$serial',
      'needs_refresh': false,
    },
    if (kind == 'revoked') 'reason': 'device_revoked',
  };
  final bytes = utf8.encode(jsonEncode(payload));
  final key = SimpleKeyPairData(
    Uint8List.fromList(_hex(_seedHex)),
    publicKey: SimplePublicKey(
      Uint8List.fromList(_hex(_publicHex)),
      type: KeyPairType.ed25519,
    ),
    type: KeyPairType.ed25519,
  );
  final signature = await Ed25519().sign([
    ...utf8.encode(signedSubscriptionPrefix),
    ...bytes,
  ], keyPair: key);
  String b64(List<int> value) => base64UrlEncode(value).replaceAll('=', '');
  return {
    for (final field in [
      'schema_version',
      'kind',
      'account_id',
      'device_id',
      'serial',
      'issued_at',
      'expires_at',
      'bundle_id',
    ])
      field: payload[field],
    'signed': {
      'kid': 'rfc8032-test',
      'payload': b64(bytes),
      'signature': b64(signature.bytes),
    },
  };
}

/// Mirrors the Core store's ordering rules closely enough to drive the app
/// orchestration; the authoritative store is tested in Go.
class _CoreOwner implements ZolnitSignedSubscriptionOwner {
  bool enabled = true;
  bool unavailable = false;
  bool timeoutAfterCommit = false;
  bool timeoutAfterSignOut = false;
  int floor = 0;
  String? floorAccount;
  bool revoked = false;
  bool installed = false;
  int signOuts = 0;
  int intent = 0;
  final applied = <String>[];

  ZolnitSignedState get _state => ZolnitSignedState(
    available: true,
    hasFloor: floor > 0,
    installed: installed,
    revoked: revoked,
    serial: floor,
    needsRefresh: !installed && !revoked,
  );

  @override
  Future<int?> available() async {
    if (unavailable) throw const ClientFailure('core_unavailable');
    return enabled ? intent : null;
  }

  @override
  Future<int> invalidate() async => ++intent;

  @override
  Future<bool> refusesUnsigned(String accountId) async =>
      floor > 0 && floorAccount == accountId;

  @override
  Future<ZolnitSignedState> status({
    required String accountId,
    required String deviceId,
  }) async => _state;

  @override
  Future<ZolnitSignedState> apply({
    required String accountId,
    required String deviceId,
    required String envelope,
    required int intent,
  }) async {
    if (intent != this.intent) {
      throw const ClientFailure('signed_subscription_stale_owner');
    }
    final value = jsonDecode(envelope) as Json;
    final kind = value['kind'] as String;
    final serial = value['serial'] as int;
    applied.add('$kind:$serial');
    if (kind == 'state') return _state;
    if (serial <= floor || revoked && serial <= floor) {
      throw const ClientFailure('subscription_replay');
    }
    floor = serial;
    floorAccount = accountId;
    revoked = kind == 'revoked';
    installed = kind == 'bundle';
    if (timeoutAfterCommit) {
      throw TimeoutException('response lost after commit');
    }
    return _state;
  }

  @override
  Future<Json> project({
    required String accountId,
    required String deviceId,
  }) async {
    if (revoked) throw const ClientFailure('subscription_tombstone');
    if (!installed) throw const ClientFailure('signed_subscription_required');
    return clientBundleFixture(accountId: accountId, bundleId: 'p-$floor');
  }

  @override
  Future<void> signOut(int expected) async {
    if (intent != expected) {
      throw const ClientFailure('signed_subscription_stale_owner');
    }
    intent++;
    signOuts++;
    installed = false;
    if (timeoutAfterSignOut) throw TimeoutException('logout response lost');
  }
}

class _Vault implements ZolnitInstallationVault {
  String? installation;
  String? enrollment;
  int writes = 0;
  bool pending = false;

  @override
  Future<bool> readSignOutPending() async => pending;
  @override
  Future<void> writeSignOutPending(bool value) async {
    pending = value;
  }

  @override
  Future<String?> readInstallationId() async => installation;
  @override
  Future<void> writeInstallationId(String value) async {
    writes++;
    installation = value;
  }

  @override
  Future<String?> readEnrollment() async => enrollment;
  @override
  Future<void> writeEnrollment(String value) async => enrollment = value;
}

class _Harness {
  _Harness({bool pinned = true}) {
    signed = ZolnitSignedSubscriptions(
      owner: owner,
      vault: vault,
      platform: 'macos',
      verifier: () async => pinned
          ? SignedSubscriptionVerifier.testOnlyRfc8032(_hex(_publicHex))
          : SignedSubscriptionVerifier.fromTrustJson('{"public_key_map":{}}'),
      monotonic: clock,
    );
    fixture = ClientBundleSessionFixture(
      signedSubscriptions: signed,
      onRequest: _route,
    );
  }

  final owner = _CoreOwner();
  final vault = _Vault();
  final clock = _ManualStopwatch();
  late final ZolnitSignedSubscriptions signed;
  late final ClientBundleSessionFixture fixture;
  final paths = <String>[];
  Json Function()? bundle;
  Json Function()? state;
  String? accountUuid;
  int registerStatus = 200;
  int stateStatus = 200;
  int bundleStatus = 200;

  Future<http.Response?> _route(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/user/info') && accountUuid != null) {
      return clientBundleResponse({'uuid': accountUuid});
    }
    if (!path.contains('/zolnit/client/')) return null;
    if (path.endsWith('/devices/online')) {
      return clientBundleResponse({
        'online': 0,
        'observed_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    }
    final signedFormat =
        request.headers['X-ZolNit-Subscription-Format'] == 'signed-v2';
    paths.add(path.endsWith('/bundle') && !signedFormat ? 'v1' : path);
    if (path.endsWith('/devices/register')) {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Json;
      expect(body['installation_id'], vault.installation);
      return registerStatus == 200
          ? clientBundleResponse({'device_id': _device, 'platform': 'macos'})
          : _error(registerStatus, 'signed_subscriptions_unavailable');
    }
    if (path.endsWith('/subscription/state')) {
      expect(request.headers['X-ZolNit-Device-Id'], _device);
      expect(request.headers['X-ZolNit-Installation'], vault.installation);
      return stateStatus == 200
          ? clientBundleResponse(state!())
          : _error(stateStatus, 'unauthenticated');
    }
    if (path.endsWith('/bundle') && signedFormat) {
      return bundleStatus == 200
          ? clientBundleResponse(bundle!())
          : _error(bundleStatus, 'bundle_unavailable');
    }
    return null;
  }

  Future<ZolnitClientBundle?> refresh() => fixture.session.refreshClientBundle(
    coreVersion: 'v1.19.32',
    clock: () => bundleTime(1001),
  );
}

http.Response _error(int status, String code) => http.Response(
  jsonEncode({
    'error': {'code': code},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

class _ManualStopwatch extends Stopwatch {
  Duration now = Duration.zero;
  @override
  Duration get elapsed => now;
}

void main() {
  test(
    'native state cannot cross account, device, session or revocation boundaries',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final envelope = await _envelope('bundle', 1);
      harness.bundle = () => envelope;
      await harness.fixture.login();
      expect(await harness.refresh(), isNotNull);
      final active = harness.signed.active!;
      final generation = harness.fixture.api.generation;
      bool accept({
        String? account,
        String? device,
        int? intent,
        int? gen,
        bool revoked = false,
        bool expired = false,
        int serial = 2,
      }) => harness.signed.acceptNativeState(
        harness.fixture.api,
        generation: gen ?? generation,
        accountId: account ?? active.accountId,
        deviceId: device ?? active.device.deviceId,
        intent: intent ?? active.intent,
        state: ZolnitSignedState(
          available: true,
          hasFloor: true,
          installed: true,
          serial: serial,
          revoked: revoked,
          expired: expired,
        ),
      );
      expect(accept(account: 'another-account'), false);
      expect(accept(device: 'fedcba9876543210fedcba9876543210'), false);
      expect(accept(intent: active.intent + 1), false);
      expect(accept(gen: generation + 1), false);
      expect(accept(revoked: true), false);
      expect(accept(expired: true), false);
      expect(harness.signed.active!.serial, 1);
      expect(accept(), true);
      expect(harness.signed.active!.serial, 2);
      expect(accept(serial: 1), false);
      await harness.fixture.session.logout();
      expect(accept(), false);
    },
  );

  test('unavailable Core before enrollment uses legacy bundle', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    harness.owner.unavailable = true;
    await harness.fixture.login();
    expect(await harness.refresh(), isNotNull);
    expect(harness.paths, ['v1']);
  });

  test('unavailable Core after enrollment does not downgrade', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    harness.bundle = () => throw StateError('unexpected signed request');
    harness.vault.enrollment = '{"origin":"https://example.test"}';
    harness.owner.unavailable = true;
    await harness.fixture.login();
    expect(await harness.refresh(), isNull);
    expect(harness.paths, isEmpty);
  });

  test('tampered initial signed package cannot become active', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    final value = await _envelope('bundle', 1);
    value['serial'] = 2;
    harness.bundle = () => value;
    await harness.fixture.login();
    expect(await harness.refresh(), isNull);
    expect(
      harness.fixture.session.clientBundleFailure,
      'invalid_signed_subscription',
    );
    expect(harness.owner.installed, isFalse);
  });

  test(
    'missing enrollment with an existing installation fails closed',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      harness.vault.installation =
          'aW5zdGFsbGF0aW9uLXNlY3JldC1maXh0dXJlLTMyYnk';
      harness.owner.unavailable = true;
      await harness.fixture.login();
      expect(await harness.refresh(), isNull);
      expect(harness.paths, isEmpty);
    },
  );

  test('missing enrollment still checks Core account floor', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    harness.owner.floor = 2;
    harness.owner.floorAccount = 'account-1';
    harness.registerStatus = 404;
    await harness.fixture.login();
    expect(await harness.refresh(), isNull);
    expect(
      harness.fixture.session.clientBundleFailure,
      'signed_subscription_required',
    );
  });

  test(
    'vault loss and Core reconnect preserve the signed floor across accounts',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final one = await _envelope('bundle', 1);
      harness.bundle = () => one;
      await harness.fixture.login();
      expect((await harness.refresh())?.accountId, '2');
      await harness.fixture.session.logout(clearSignedCredentials: false);
      harness.vault.installation = null;
      harness.vault.enrollment = null;
      harness.vault.pending = false;
      harness.owner.unavailable = true;
      harness.fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: '2'));
      await harness.fixture.login();
      expect((await harness.refresh())?.accountId, '2');
      expect(harness.paths.last, 'v1');
      expect(harness.owner.floor, 1);
      expect(harness.owner.installed, isTrue);
      harness.owner.unavailable = false;
      expect((await harness.refresh())?.accountId, '2');
      expect(harness.owner.floor, 1);
      await harness.fixture.session.logout(clearSignedCredentials: false);
      harness.accountUuid = '00000000-0000-4000-8000-000000000003';
      harness.registerStatus = 503;
      harness.fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: '3'));
      await harness.fixture.login();
      expect((await harness.refresh())?.accountId, '3');
      expect(harness.owner.floor, 1);
      expect(harness.owner.floorAccount, '2');
      expect(harness.owner.installed, isTrue);
    },
  );

  test('lost apply response leaves a durable fallback fence', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    harness.bundle = () => throw StateError('fixture not initialized');
    final one = await _envelope('bundle', 1);
    harness.bundle = () => one;
    harness.owner.timeoutAfterCommit = true;
    await harness.fixture.login();
    expect(await harness.refresh(), isNull);
    expect(harness.owner.floor, 1);
    expect(harness.vault.enrollment, isNotNull);
    harness.paths.clear();
    harness.owner.unavailable = true;
    expect(await harness.refresh(), isNull);
    expect(harness.paths, isEmpty);
    expect(harness.owner.floor, 1);
  });

  test('unconfirmed logout cannot be bypassed by a new login', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    final one = await _envelope('bundle', 1);
    harness.bundle = () => one;
    await harness.fixture.login();
    expect(await harness.refresh(), isNotNull);
    harness.owner.timeoutAfterSignOut = true;
    await harness.fixture.session.logout();
    expect(harness.vault.pending, isTrue);
    final restarted = ZolnitSignedSubscriptions(
      owner: harness.owner,
      vault: harness.vault,
      platform: 'macos',
      verifier: () async =>
          SignedSubscriptionVerifier.testOnlyRfc8032(_hex(_publicHex)),
    );
    await expectLater(
      restarted.bundle(harness.fixture.session.api, coreVersion: 'v1'),
      throwsA(isA<ClientFailure>()),
    );
    await harness.fixture.login();
    harness.paths.clear();
    expect(await harness.refresh(), isNull);
    expect(harness.paths, isEmpty);
    expect(harness.owner.floor, 1);
  });

  test(
    'empty production pin keeps the legacy bundle and never registers',
    () async {
      final harness = _Harness(pinned: false);
      addTearDown(harness.fixture.dispose);
      await harness.fixture.login();
      final bundle = await harness.refresh();
      expect(bundle, isNotNull);
      expect(harness.paths, ['v1']);
      expect(harness.fixture.session.usage?.onlineDevices, 0);
      expect(harness.vault.installation, isNull);
    },
  );

  test(
    'negotiated install registers once, then renews from signed state',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final one = await _envelope('bundle', 1);
      harness.bundle = () => one;
      await harness.fixture.login();
      final first = await harness.refresh();
      expect(first!.accountId, '2');
      expect(harness.paths, [
        '/api/v1/zolnit/client/devices/register',
        '/api/v1/zolnit/client/bundle',
      ]);
      final installation = harness.vault.installation;
      expect(installation, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(harness.signed.active?.device.deviceId, _device);
      harness.paths.clear();
      await harness.refresh();
      expect(harness.paths, isEmpty, reason: 'lease renewal is local');
      final current = await _envelope('state', 1);
      harness.state = () => current;
      harness.clock.now = const Duration(minutes: 6);
      await harness.refresh();
      expect(harness.paths, ['/api/v1/zolnit/client/subscription/state']);
      expect(harness.vault.installation, installation);
      expect(harness.vault.writes, 1);
    },
  );

  test('transport failures and unsigned 401 keep the signed package', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    final one = await _envelope('bundle', 1);
    harness.bundle = () => one;
    await harness.fixture.login();
    await harness.refresh();
    harness.clock.now = const Duration(minutes: 6);
    harness.stateStatus = 401;
    final kept = await harness.refresh();
    expect(kept, isNotNull);
    expect(harness.owner.installed, isTrue);
    harness.stateStatus = 503;
    harness.clock.now = const Duration(minutes: 12);
    expect(await harness.refresh(), isNotNull);
  });

  test(
    'tampered signed state retains the independently verified package',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final one = await _envelope('bundle', 1);
      harness.bundle = () => one;
      await harness.fixture.login();
      expect(await harness.refresh(), isNotNull);
      final state = await _envelope('state', 1);
      state['serial'] = 2;
      harness.state = () => state;
      harness.clock.now = const Duration(minutes: 6);
      expect(await harness.refresh(), isNotNull);
      expect(harness.fixture.session.clientBundleFailure, isNull);
      expect(harness.owner.installed, isTrue);
    },
  );

  test(
    'signed revocation stops service and replay cannot resurrect it',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final one = await _envelope('bundle', 1);
      harness.bundle = () => one;
      await harness.fixture.login();
      await harness.refresh();
      final revoked = await _envelope('revoked', 2);
      harness.state = () => revoked;
      harness.clock.now = const Duration(minutes: 6);
      expect(await harness.refresh(), isNull);
      expect(
        harness.fixture.session.clientBundleFailure,
        'subscription_tombstone',
      );
      harness.clock.now = const Duration(minutes: 12);
      harness.state = () => one;
      expect(await harness.refresh(), isNull);
      expect(harness.owner.revoked, isTrue);
      final renewed = await _envelope('bundle', 3);
      harness.bundle = () => renewed;
      expect(await harness.refresh(), isNotNull);
      expect(harness.owner.floor, 3);
    },
  );

  test(
    'registration failure never restores a different account package',
    () async {
      final harness = _Harness();
      addTearDown(harness.fixture.dispose);
      final one = await _envelope('bundle', 1);
      harness.bundle = () => one;
      await harness.fixture.login();
      expect((await harness.refresh())?.accountId, '2');
      await harness.fixture.session.logout(clearSignedCredentials: false);
      harness.accountUuid = '00000000-0000-4000-8000-000000000003';
      harness.registerStatus = 503;
      harness.fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: '3'));
      await harness.fixture.login();
      expect((await harness.refresh())?.accountId, '3');
      expect(harness.owner.installed, isTrue);
    },
  );

  test('a signed floor refuses the unsigned legacy bundle', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    final one = await _envelope('bundle', 1);
    harness.bundle = () => one;
    await harness.fixture.login();
    await harness.refresh();
    harness.owner.enabled = false;
    harness.fixture.onBundle = (_) async =>
        clientBundleResponse(clientBundleFixture(accountId: '2'));
    expect(await harness.refresh(), isNull);
    expect(
      harness.fixture.session.clientBundleFailure,
      'signed_subscription_required',
    );
  });

  for (final status in [404, 503]) {
    test(
      'server without signed support ($status) stays on legacy before enrollment',
      () async {
        final harness = _Harness();
        addTearDown(harness.fixture.dispose);
        harness.registerStatus = status;
        await harness.fixture.login();
        expect(await harness.refresh(), isNotNull);
        expect(harness.paths.last, 'v1');
      },
    );
  }

  test('only explicit logout clears signed credentials', () async {
    final harness = _Harness();
    addTearDown(harness.fixture.dispose);
    final one = await _envelope('bundle', 1);
    harness.bundle = () => one;
    await harness.fixture.login();
    await harness.refresh();
    await harness.fixture.session.logout(clearSignedCredentials: false);
    expect(harness.owner.signOuts, 0);
    await harness.fixture.login();
    await harness.fixture.session.logout();
    expect(harness.owner.signOuts, 1);
    expect(harness.owner.floor, 1);
  });
}
