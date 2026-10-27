import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'client_bundle_fixture.dart';

class _MemoryVault implements ZolnitSessionVault {
  String? authorization = 'Bearer restored-fixture';

  @override
  Future<String?> readAuthorization() async => authorization;

  @override
  Future<void> writeAuthorization(String value) async => authorization = value;

  @override
  Future<void> deleteAuthorization() async => authorization = null;
}

void main() {
  late ClientBundleSessionFixture fixture;
  setUp(() => fixture = ClientBundleSessionFixture());
  tearDown(() => fixture.dispose());

  for (final restore in [false, true]) {
    test(
      'canonical account 2 bootstrap after ${restore ? 'restore' : 'login'}',
      () async {
        final client = ClientBundleSessionFixture(vault: _MemoryVault());
        addTearDown(client.dispose);
        client.onBundle = (_) async =>
            clientBundleResponse(clientBundleFixture(accountId: '2'));
        if (restore) {
          await client.session.restore();
        } else {
          await client.login();
        }
        expect(client.session.authenticated, isTrue);
        expect(client.session.failure, isNull);
        expect(client.session.account!.containsKey('id'), isFalse);
        expect(client.session.clientBundleAccountId, isNull);
        final before = client.requests.length;
        for (var receipt = 0; receipt < 2; receipt++) {
          final bundle = await client.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => bundleTime(1001),
          );
          expect(bundle!.accountId, '2');
          expect(client.session.clientBundleAccountId, '2');
        }
        final accepted = client.session.clientBundle;
        client.onBundle = (_) async =>
            clientBundleResponse(clientBundleFixture(accountId: '3'));
        expect(
          await client.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => bundleTime(1001),
          ),
          isNull,
        );
        expect(
          client.session.clientBundleFailure,
          'client_bundle_binding_mismatch',
        );
        expect(client.session.clientBundle, same(accepted));
        expect(client.session.clientBundleAccountId, '2');
        expect(
          client.requests.skip(before).map((r) => r.url.path),
          everyElement('/api/v1/zolnit/client/bundle'),
        );
        for (final request in client.requests) {
          expect(request.url.origin, 'https://panel.example.invalid');
          expect(request.followRedirects, isFalse);
          if (request.url.path.endsWith('/login')) {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], isNull);
          } else {
            expect(
              request.headers['Authorization'],
              restore ? 'Bearer restored-fixture' : 'Bearer fixture',
            );
          }
        }
      },
    );
  }

  test('invalid bootstrap cannot seed the canonical account binding', () async {
    await fixture.login();
    final invalid = clientBundleFixture(accountId: '3');
    (invalid['connection'] as Json)['document'] = 'tampered';
    fixture.onBundle = (_) async => clientBundleResponse(invalid);
    expect(
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      ),
      isNull,
    );
    expect(fixture.session.clientBundleAccountId, isNull);
    fixture.onBundle = (_) async =>
        clientBundleResponse(clientBundleFixture(accountId: '2'));
    expect(
      (await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      ))!.accountId,
      '2',
    );
  });

  for (final transition in ['logout', 'rotate', 'switch']) {
    test('pending canonical bootstrap is fenced by $transition', () async {
      await fixture.login();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      fixture.onBundle = (_) {
        started.complete();
        return response.future;
      };
      final old = fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      await started.future;
      if (transition == 'rotate') {
        fixture.api.setAuthorization('Bearer rotated-fixture');
      } else if (transition == 'switch') {
        await fixture.session.login(
          'other@example.invalid',
          'synthetic-password',
        );
      } else {
        await fixture.session.logout();
      }
      expect(fixture.session.clientBundleAccountId, isNull);
      if (transition != 'logout') {
        fixture.onBundle = (_) async =>
            clientBundleResponse(clientBundleFixture(accountId: '3'));
        expect(
          (await fixture.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => bundleTime(1001),
          ))!.accountId,
          '3',
        );
      }
      response.complete(
        clientBundleResponse(clientBundleFixture(accountId: '2')),
      );
      expect(await old, isNull);
      expect(
        fixture.session.clientBundleAccountId,
        transition == 'logout' ? isNull : '3',
      );
      expect(fixture.session.clientBundleFailure, isNull);
      expect(fixture.session.authenticated, transition != 'logout');
    });
  }

  test(
    'actual server synthetic serialization works without a numeric user-info id',
    () async {
      await fixture.login();
      expect(fixture.session.account!.containsKey('id'), isFalse);
      final value = await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      expect(value!.accountId, 'account-1');
      expect(value.outbounds.length, 3);
      expect(value.routingManifest.nodes.length, 2);
      expect(value.outbounds.any((o) => o.id == 'trojan:9'), isTrue);
      expect(
        value.routingManifest.nodes.any((n) => n.id == 'trojan:9'),
        isFalse,
      );
      expect(fixture.session.clientBundleAccountId, 'account-1');
      final request = fixture.requests.last;
      expect(request.url.path, '/api/v1/zolnit/client/bundle');
      expect(request.headers['X-ZolNit-Core-Version'], 'v1.19.32');
      expect(request.headers['X-ZolNit-Platform'], 'macos');
      expect(request.headers['X-ZolNit-Distribution'], 'direct');
      expect(request.url.queryParameters, isEmpty);
    },
  );

  test(
    'same-generation account mismatch retains the previous binding',
    () async {
      await fixture.login();
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: 'account-other'));
      expect(
        await fixture.session.refreshClientBundle(
          coreVersion: 'v1.19.32',
          clock: () => bundleTime(1002),
        ),
        isNull,
      );
      expect(
        fixture.session.clientBundleFailure,
        'client_bundle_binding_mismatch',
      );
      expect(fixture.session.clientBundleAccountId, 'account-1');
      expect(fixture.session.clientBundle!.accountId, 'account-1');
      expect(fixture.session.authenticated, isTrue);
    },
  );

  for (final entry in [
    (403, 'entitlement_unavailable'),
    (503, 'client_api_unavailable'),
    (503, 'bundle_unavailable'),
    (400, 'core_version_required'),
    (404, 'client_api_unavailable'),
  ]) {
    test(
      'bundle error ${entry.$1}/${entry.$2} retains authentication and paid snapshots',
      () async {
        await fixture.login();
        final subscription = fixture.session.subscription;
        final generation = fixture.api.generation;
        fixture.onBundle = (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': entry.$2,
              'message': 'MUST_NOT_SURFACE fixture private text',
            },
          }),
          entry.$1,
        );
        expect(
          await fixture.session.refreshClientBundle(
            coreVersion: 'v1.19.32',
            clock: () => bundleTime(1001),
          ),
          isNull,
        );
        expect(fixture.session.clientBundleFailure, entry.$2);
        expect(fixture.session.authenticated, isTrue);
        expect(fixture.api.generation, generation);
        expect(fixture.session.subscription, subscription);
        expect(fixture.session.failureMessage, isNull);
        expect(fixture.invalidations, 0);
      },
    );
  }

  for (final entry in [
    (403, '<html>edge denied PRIVATE</html>'),
    (403, '{"error":{"code":"edge_denied"}}'),
    (401, '<html>edge authentication</html>'),
    (503, '<html>upstream unavailable</html>'),
  ]) {
    test('edge response ${entry.$1} never expires the session', () async {
      await fixture.login();
      final subscription = fixture.session.subscription;
      fixture.onBundle = (_) async => http.Response(entry.$2, entry.$1);
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      expect(fixture.session.clientBundleFailure, 'client_api_unavailable');
      expect(fixture.session.authenticated, isTrue);
      expect(fixture.session.subscription, subscription);
      expect(fixture.invalidations, 0);
      expect(fixture.session.failureMessage, isNull);
    });
  }

  test('401 alone enters existing authentication invalidation', () async {
    await fixture.login();
    fixture.onBundle = (_) async =>
        http.Response('{"error":{"code":"unauthenticated"}}', 401);
    await fixture.session.refreshClientBundle(
      coreVersion: 'v1.19.32',
      clock: () => bundleTime(1001),
    );
    expect(fixture.session.authenticated, isFalse);
    expect(fixture.session.clientBundleAccountId, isNull);
    expect(fixture.session.clientBundle, isNull);
    expect(fixture.invalidations, 1);
  });

  test(
    'receipt time controls expiry even when the request began fresh',
    () async {
      await fixture.login();
      var now = bundleTime(1001);
      fixture.onBundle = (_) async {
        now = bundleTime(1301);
        return clientBundleResponse(clientBundleFixture());
      };
      expect(
        await fixture.session.refreshClientBundle(
          coreVersion: 'v1.19.32',
          clock: () => now,
        ),
        isNull,
      );
      expect(fixture.session.clientBundleFailure, 'client_bundle_expired');
      expect(fixture.session.authenticated, isTrue);
    },
  );

  test(
    'late bundle after logout/new login cannot replace the new account',
    () async {
      await fixture.login();
      final started = Completer<void>();
      final pending = Completer<http.Response>();
      fixture.onBundle = (_) {
        started.complete();
        return pending.future;
      };
      final old = fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      await started.future;
      await fixture.session.logout();
      await fixture.login();
      fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: 'account-new'));
      final fresh = await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      pending.complete(clientBundleResponse(clientBundleFixture()));
      expect(await old, isNull);
      expect(fresh!.accountId, 'account-new');
      expect(fixture.session.clientBundleAccountId, 'account-new');
      expect(fixture.session.authenticated, isTrue);
    },
  );

  test(
    'token-generation changes clear the binding before a new receipt',
    () async {
      await fixture.login();
      await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      fixture.api.setAuthorization('Bearer new-fixture');
      expect(fixture.session.clientBundleAccountId, isNull);
      fixture.onBundle = (_) async =>
          clientBundleResponse(clientBundleFixture(accountId: 'account-next'));
      final fresh = await fixture.session.refreshClientBundle(
        coreVersion: 'v1.19.32',
        clock: () => bundleTime(1001),
      );
      expect(fresh!.accountId, 'account-next');
    },
  );

  for (final platform in [null, 'macos']) {
    test(
      'missing bundle context is rejected before HTTP ($platform)',
      () async {
        var calls = 0;
        final api = XboardClient(
          origin: Uri.parse('https://panel.example.invalid'),
          clientPlatform: platform,
          distribution: platform == null ? 'direct' : null,
          client: MockClient((_) async {
            calls++;
            return clientBundleResponse(clientBundleFixture());
          }),
        );
        addTearDown(api.close);
        await expectLater(
          api.fetchClientBundle(coreVersion: 'v1.19.32'),
          throwsA(
            isA<ClientFailure>().having(
              (e) => e.code,
              'code',
              'invalid_client_context',
            ),
          ),
        );
        expect(calls, 0);
      },
    );
  }

  test('invalid Core header is rejected before any HTTP request', () async {
    await fixture.login();
    final before = fixture.requests.length;
    await fixture.session.refreshClientBundle(
      coreVersion: 'v1.19.32\r\nInjected: bad',
      clock: () => bundleTime(1001),
    );
    expect(fixture.requests.length, before);
    expect(fixture.session.clientBundleFailure, 'core_version_required');
    expect(fixture.session.authenticated, isTrue);
  });
}
