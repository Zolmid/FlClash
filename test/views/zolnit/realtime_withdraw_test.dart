import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'canonical edit preserves read, rejects stale and replay, honors tombstone',
    () async {
      final store = ZolnitRealtimePreferencesStore();
      const scope = 'https://panel.invalid:account-a';
      final old = ZolnitRealtimeInboxItem(
        id: 'c' * 32,
        title: 'Old',
        body: 'Old body',
        createdAt: DateTime.now(),
        popup: true,
        read: true,
      );
      final edit = ZolnitRealtimeInboxItem(
        id: old.id,
        title: 'New',
        body: 'New body',
        createdAt: old.createdAt,
        popup: false,
      );
      expect(await store.appendInbox(scope, old), isTrue);
      expect(
        await store.applyCanonicalInbox(scope, edit, isCurrent: () => true),
        ZolnitInboxMerge.updated,
      );
      expect(await store.appendInbox(scope, old), isFalse);
      final item = (await store.readInbox(scope)).single;
      expect(
        (item.title, item.body, item.popup, item.read),
        ('New', 'New body', false, true),
      );
      var epochChecks = 0;
      expect(
        await store.applyCanonicalInbox(
          scope,
          old,
          isCurrent: () => ++epochChecks == 1,
        ),
        ZolnitInboxMerge.unchanged,
      );
      expect(epochChecks, greaterThan(1));
      expect((await store.readInbox(scope)).single.title, 'New');
      await store.withdrawInbox(scope, [old.id]);
      expect(
        await store.applyCanonicalInbox(scope, old, isCurrent: () => true),
        ZolnitInboxMerge.unchanged,
      );
      expect(await store.readInbox(scope), isEmpty);
    },
  );
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
