import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'withdrawal removes cached messages and rejects late replay across restart, scoped to account',
    () async {
      final store = ZolnitRealtimePreferencesStore(), id = 'a' * 32;
      final item = ZolnitRealtimeInboxItem(
        id: id,
        title: 'Mistake',
        body: 'Withdraw',
        createdAt: DateTime.now(),
        popup: true,
      );
      const a = 'https://panel.invalid:account-a',
          b = 'https://panel.invalid:account-b';
      await store.appendInbox(a, item);
      await store.appendInbox(b, item);
      await store.appendInbox(
        a,
        ZolnitRealtimeInboxItem(
          id: 'b' * 32,
          title: 'Keep',
          body: 'Valid',
          createdAt: DateTime.now(),
          popup: false,
        ),
      );
      await store.withdrawInbox(a, [id]);
      expect((await store.readInbox(a)).map((e) => e.title), ['Keep']);
      expect((await store.readInbox(b)).single.title, 'Mistake');
      final reopened = ZolnitRealtimePreferencesStore();
      expect(await reopened.appendInbox(a, item), false);
      expect((await reopened.readInbox(a)).map((e) => e.title), ['Keep']);
    },
  );
  test(
    'withdrawal snapshot is strict and compatible with old inbox responses',
    () {
      final base = {'subject': 'b' * 64, 'events': <Json>[]};
      expect(ZolnitRealtimeInbox.parse(base)!.withdrawn, isEmpty);
      expect(
        ZolnitRealtimeInbox.parse({
          ...base,
          'withdrawn': ['a' * 32],
        })!.withdrawn,
        ['a' * 32],
      );
      expect(
        ZolnitRealtimeInbox.parse({
          ...base,
          'withdrawn': ['other-account'],
        }),
        isNull,
      );
    },
  );
}
