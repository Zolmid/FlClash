import 'package:fl_clash/providers/zolnit_rewards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'pending ID survives reconstruction, is account scoped, and clears on success',
    () async {
      final keys = <String?>[];
      var calls = 0;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        timeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/check')) {
            return http.Response(
              '{"data":{"template":{"name":"Gift"},"can_redeem":true}}',
              200,
            );
          }
          keys.add(request.headers['idempotency-key']);
          if (++calls == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
          return http.Response('{"data":{"rewards":{"balance":25}}}', 200);
        }),
      )..setAuthorization('Bearer accountA');
      addTearDown(api.close);
      ZolnitGiftPreferencesStore store(String account) =>
          ZolnitGiftPreferencesStore(api.origin, account);
      final first = ZolnitGiftCardAttempt(
        ZolnitRewardsClient(api),
        store: store('account-a'),
      )..edit(' Secret123 ');
      await first.recover();
      await first.check();
      await expectLater(first.redeem(), throwsA(isA<ClientFailure>()));
      first.clear();
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs
          .getKeys()
          .map((key) => '$key:${prefs.get(key)}')
          .join();
      expect(persisted.toLowerCase(), isNot(contains('secret123')));
      api.setAuthorization('Bearer accountB');
      await expectLater(first.recover(), throwsA(isA<ClientFailure>()));
      final other = ZolnitGiftCardAttempt(
        ZolnitRewardsClient(api),
        store: store('account-b'),
      )..edit('secret123');
      await other.recover();
      expect(other.canRetry, isFalse);
      api.setAuthorization('Bearer accountA');
      final restarted = ZolnitGiftCardAttempt(
        ZolnitRewardsClient(api),
        store: store('account-a'),
      )..edit('secret123');
      await restarted.recover();
      expect(restarted.canRetry, isTrue);
      expect((await restarted.redeem())['rewards'], {'balance': 25});
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      final later = ZolnitGiftCardAttempt(
        ZolnitRewardsClient(api),
        store: store('account-a'),
      )..edit('SECRET123');
      await later.recover();
      expect(later.canRetry, isFalse);
      expect(prefs.getKeys(), isEmpty);
    },
  );
}
