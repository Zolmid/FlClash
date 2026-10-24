import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

Json clientBundleFixture({
  int issuedAt = 1000,
  String accountId = 'account-1',
  String? bundleId,
}) {
  final local = File('test/fixtures/client-bundle-v1.json');
  final file = local.existsSync()
      ? local
      : File('packages/zolnit_client/test/fixtures/client-bundle-v1.json');
  final raw = (jsonDecode(file.readAsStringSync()) as Json)['data'] as Json;
  raw['issued_at'] = issuedAt;
  raw['expires_at'] = issuedAt + 300;
  raw['account_id'] = accountId;
  if (bundleId != null) raw['bundle_id'] = bundleId;
  return raw;
}

http.Response clientBundleResponse(Object? raw) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': raw})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

DateTime bundleTime(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

class _BundleBackend implements CheckoutBackend {
  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async =>
      const StatusOnlyCheckout();
  @override
  Future<int> status(String tradeNo) async => 0;
}

class _BundlePlatform implements CheckoutPlatform {
  @override
  Future<bool> open(Uri uri) async => false;
  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async {}
}

class ClientBundleSessionFixture {
  ClientBundleSessionFixture() {
    api = XboardClient(
      origin: Uri.parse('https://panel.example.invalid'),
      clientPlatform: 'macos',
      distribution: 'direct',
      userAgent: 'ZolNit/fixture',
      client: MockClient((request) async {
        requests.add(request);
        final route = request.url.path;
        if (route == '/api/v1/zolnit/client/bundle') {
          return onBundle?.call(request) ??
              clientBundleResponse(clientBundleFixture());
        }
        dynamic value = [];
        if (route.endsWith('/login')) {
          value = {'auth_data': 'Bearer fixture'};
        } else if (route.endsWith('/user/info')) {
          value = {'email': 'fixture@example.invalid'};
        } else if (route.endsWith('/getSubscribe')) {
          value = {
            'email': 'fixture@example.invalid',
            'plan_id': 1,
            'transfer_enable': 1024,
            'u': 0,
            'd': 0,
          };
        }
        return clientBundleResponse(value);
      }),
    );
    session = ZolnitSessionController(
      api: api,
      billing: ZolnitBillingClient(api),
      checkout: CheckoutController(
        allowStripe: false,
        backend: _BundleBackend(),
        platform: _BundlePlatform(),
        allowedHttpsOrigins: const {},
      ),
      onAuthenticationInvalidated: () async {
        invalidations++;
      },
    );
  }
  late final XboardClient api;
  late final ZolnitSessionController session;
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request)? onBundle;
  int invalidations = 0;
  Future<void> login() =>
      session.login('fixture@example.invalid', 'fixture-password');
  void dispose() => session.dispose();
}
