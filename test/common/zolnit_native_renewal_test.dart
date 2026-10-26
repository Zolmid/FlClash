import 'dart:async';

import 'package:fl_clash/common/zolnit_native_renewal.dart';
import 'package:flutter_test/flutter_test.dart';

class _Journal implements ZolnitRenewalJournal {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}

const _authorization = 'Bearer SYNTHETIC_ONLY';
const _receipt = {
  'supported': true,
  'sessionEpoch': 7,
  'ownerId': 9,
  'ownsRenewal': true,
  'ready': true,
  'state': 'installed',
};

Future<ZolnitNativeRenewalSnapshot> _configure(
  ZolnitNativeRenewalClient client,
) => client.configure(
  accountId: 'fixture-account',
  accountGeneration: 2,
  authorization: _authorization,
  distribution: 'direct',
);

void main() {
  test(
    'journal persists the owner binding without persisting its bearer',
    () async {
      final journal = _Journal();
      final client = ZolnitNativeRenewalClient(
        journal: journal,
        call: (method, args) async {
          expect(method, 'configureClientBundleRenewal');
          expect(args?['authorization'], _authorization);
          return _receipt;
        },
      );
      addTearDown(client.dispose);
      expect((await _configure(client)).ownsRenewal, isTrue);
      expect(journal.value, isNot(contains('Bearer')));
      expect(journal.value, isNot(contains('SYNTHETIC_ONLY')));
      expect(await client.allowsRestoration(_authorization), isTrue);
    },
  );

  test('logout drains a pending configuration before returning', () async {
    final journal = _Journal();
    final started = Completer<void>();
    final configured = Completer<Object?>();
    final methods = <String>[];
    final client = ZolnitNativeRenewalClient(
      journal: journal,
      call: (method, args) async {
        methods.add(method);
        if (method == 'configureClientBundleRenewal') {
          started.complete();
          return configured.future;
        }
        expect(args?['sessionEpoch'], 7);
        return true;
      },
    );
    addTearDown(client.dispose);
    final configuring = _configure(client);
    await started.future;
    final logout = client.logout();
    configured.complete(_receipt);
    await configuring;
    await logout;
    expect(methods, [
      'configureClientBundleRenewal',
      'logoutClientBundleRenewal',
    ]);
    expect(journal.value, isNull);
    expect(client.snapshot.ownsRenewal, isFalse);
  });

  test('failed cleanup blocks old restoration and remains retryable', () async {
    final journal = _Journal();
    var attempts = 0;
    final client = ZolnitNativeRenewalClient(
      journal: journal,
      call: (method, _) async {
        if (method == 'configureClientBundleRenewal') return _receipt;
        attempts++;
        return attempts > 1;
      },
    );
    addTearDown(client.dispose);
    await _configure(client);
    await expectLater(client.logout(), throwsStateError);
    expect(await client.allowsRestoration(_authorization), isFalse);
    expect(
      await client.allowsRestoration('Bearer NEW_SYNTHETIC_ACCOUNT'),
      isTrue,
    );
    expect(journal.value, isNotNull);
    await client.logout();
    expect(journal.value, isNull);
    expect(attempts, 2);
  });

  test(
    'closing the frontend does not revoke a pending valid native session',
    () async {
      final journal = _Journal();
      final started = Completer<void>();
      final configured = Completer<Object?>();
      final methods = <String>[];
      final client = ZolnitNativeRenewalClient(
        journal: journal,
        call: (method, _) async {
          methods.add(method);
          started.complete();
          return configured.future;
        },
      );
      final configuring = _configure(client);
      await started.future;
      client.dispose();
      configured.complete(_receipt);
      await configuring;
      expect(methods, ['configureClientBundleRenewal']);
      expect(journal.value, isNotNull);
    },
  );

  test(
    'a foreign epoch cannot log out this session through a status callback',
    () async {
      final journal = _Journal();
      var epoch = 8;
      final client = ZolnitNativeRenewalClient(
        journal: journal,
        call: (method, _) async {
          if (method == 'configureClientBundleRenewal') return _receipt;
          return {..._receipt, 'sessionEpoch': epoch, 'state': 'logged_out'};
        },
      );
      addTearDown(client.dispose);
      await _configure(client);
      await client.poll();
      expect(client.snapshot.ready, isTrue);
      expect(await client.allowsRestoration(_authorization), isTrue);
      epoch = 7;
      await client.poll();
      expect(client.snapshot.state, 'logged_out');
      expect(await client.allowsRestoration(_authorization), isFalse);
    },
  );
}
