import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

Json config() => {
  'enabled': true,
  'account_id': 'accountA',
  'configured': true,
  'environment': 'Sandbox',
  'management_url': 'https://apps.apple.com/account/subscriptions',
  'products': {
    'fixture.monthly': {
      'plan_id': 1,
      'period': 'monthly',
      'type': 'Auto-Renewable Subscription',
    },
  },
  'prepare_path': '/api/v1/zolnit-apple/prepare',
  'verify_path': '/api/v1/zolnit-apple/verify',
};

http.Response data(dynamic value) =>
    http.Response(jsonEncode({'data': value}), 200);

void main() {
  test(
    'typed configuration exposes only server product mappings and paths',
    () {
      final parsed = AppleBillingConfig.parse(config());
      expect(parsed.available, isTrue);
      expect(parsed.productIds, {'fixture.monthly'});
      final product = parsed.productFor(1, 'monthly')!;
      expect(product.productId, 'fixture.monthly');
      expect(product.planId, 1);
      expect(product.period, 'monthly');
      expect(parsed.productFor(2, 'monthly'), isNull);
      expect(AppleBillingPaths.fromConfig(parsed).prepare, parsed.preparePath);
      expect(() => parsed.products.clear(), throwsUnsupportedError);
      expect(() => parsed.productIds.clear(), throwsUnsupportedError);
    },
  );

  for (final patch in <Json>[
    {'enabled': false},
    {'configured': false},
    {'products': <String, dynamic>{}},
  ]) {
    test('unavailable config never claims purchasability $patch', () {
      expect(
        AppleBillingConfig.parse({...config(), ...patch}).available,
        isFalse,
      );
    });
  }

  for (final patch in <Json>[
    {'enabled': 'true'},
    {'configured': 1},
    {'products': null},
    {'prepare_path': 'https://foreign.example/prepare'},
    {'verify_path': '/api/v1/../verify'},
    {'verify_path': '/api/v1/zolnit-apple/verify?extra=1'},
    {
      'products': [
        {'product_id': 'fixture', 'plan_id': '1', 'period': 'monthly'},
      ],
    },
    {
      'products': [
        {'product_id': 'fixture', 'plan_id': 1, 'period': ''},
      ],
    },
    {
      'products': {
        'bad': {'plan_id': 1, 'period': 'monthly', 'type': 'Consumable'},
      },
    },
    {
      'products': {
        'bad': {
          'plan_id': 1,
          'period': 'onetime',
          'type': 'Auto-Renewable Subscription',
        },
      },
    },
  ]) {
    test('invalid configuration fails closed $patch', () {
      expect(
        () => AppleBillingConfig.parse({...config(), ...patch}),
        throwsA(isA<ClientFailure>()),
      );
    });
  }

  test(
    'configuration, prepare and verify use authenticated minimal contract',
    () async {
      final requests = <http.Request>[];
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((r) async {
          requests.add(r);
          expect(r.headers['Authorization'], 'Bearer fixture');
          if (r.url.path.endsWith('/config')) return data(config());
          if (r.url.path.endsWith('/prepare')) {
            return data({
              'account_id': 'accountA',
              'product_id': 'fixture.monthly',
              'app_account_token': '11111111-2222-4333-8444-555555555555',
            });
          }
          return data({
            'account_id': 'accountA',
            'product_id': 'fixture.monthly',
            'transaction_id': 'transaction1',
            'applied': true,
          });
        }),
      )..setAuthorization('Bearer fixture');
      addTearDown(api.close);
      final backend = XboardAppleBillingBackend(api, const AppleBillingPaths());
      expect((await backend.config()).available, isTrue);
      expect((await backend.prepare('fixture.monthly')).accountId, 'accountA');
      final verified = await backend.verify(
        const ApplePurchaseProof(
          productId: 'fixture.monthly',
          transactionId: 'transaction1',
          verificationData: 'synthetic-proof',
          source: 'app_store',
        ),
      );
      expect(verified.applied, isTrue);
      expect(requests.map((r) => r.method), ['GET', 'POST', 'POST']);
      expect(jsonDecode(requests[1].body), {'product_id': 'fixture.monthly'});
      expect(jsonDecode(requests[2].body), {
        'product_id': 'fixture.monthly',
        'transaction_id': 'transaction1',
        'verification_data': 'synthetic-proof',
        'source': 'app_store',
      });
    },
  );

  for (final patch in <Json>[
    {'applied': 'true'},
    {'applied': 1},
    {'applied': null},
    {'product_id': 'foreign'},
    {'transaction_id': 'foreign'},
  ]) {
    test('malformed verify acknowledgment is rejected $patch', () async {
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (_) async => data({
            'account_id': 'accountA',
            'product_id': 'fixture.monthly',
            'transaction_id': 'transaction1',
            'applied': true,
            ...patch,
          }),
        ),
      )..setAuthorization('Bearer fixture');
      addTearDown(api.close);
      await expectLater(
        XboardAppleBillingBackend(api, const AppleBillingPaths()).verify(
          const ApplePurchaseProof(
            productId: 'fixture.monthly',
            transactionId: 'transaction1',
            verificationData: 'synthetic-proof',
            source: 'app_store',
          ),
        ),
        throwsA(isA<ClientFailure>()),
      );
    });
  }

  test(
    'late Apple config after an account change cannot be consumed',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((_) {
          started.complete();
          return pending.future;
        }),
      )..setAuthorization('Bearer accountA');
      addTearDown(api.close);
      final result = XboardAppleBillingBackend(
        api,
        const AppleBillingPaths(),
      ).config();
      final assertion = expectLater(
        result,
        throwsA(
          isA<ClientFailure>().having((e) => e.code, 'code', 'superseded'),
        ),
      );
      await started.future;
      api.setAuthorization('Bearer accountB');
      pending.complete(data(config()));
      await assertion;
    },
  );
}
