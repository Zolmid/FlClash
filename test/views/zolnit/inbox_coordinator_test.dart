import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/inbox_coordinator.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zolnit_client/zolnit_client.dart';

class _BlockingPreferences extends InMemorySharedPreferencesStore {
  _BlockingPreferences() : super.empty();
  final started = Completer<void>();
  final release = Completer<void>();
  bool block = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (block) {
      block = false;
      started.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

class _CountingPreferences extends InMemorySharedPreferencesStore {
  _CountingPreferences() : super.empty();
  int inboxWrites = 0;
  bool failInbox = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith('.inbox')) {
      inboxWrites++;
      if (failInbox) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'snapshot merges 100 entries once, preserves read and skips replay writes',
    () async {
      final prefs = _CountingPreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      final store = ZolnitRealtimePreferencesStore();
      const scope = 'https://panel.example:batch';
      final now = DateTime.now();
      final items = List.generate(
        100,
        (i) => ZolnitRealtimeInboxItem(
          id: i.toRadixString(16).padLeft(32, '0'),
          title: 'title $i',
          body: 'x' * 1024,
          createdAt: now.subtract(Duration(seconds: i)),
          popup: false,
        ),
      );
      await store.appendInbox(scope, items.first.asRead());
      prefs.inboxWrites = 0;
      final first = await store.mergeSnapshot(
        scope,
        items,
        [],
        isCurrent: () => true,
      );
      expect(prefs.inboxWrites, 1);
      expect(first.inbox, hasLength(100));
      expect(first.inbox.first.read, isTrue);
      await store.mergeSnapshot(scope, items, [], isCurrent: () => true);
      expect(prefs.inboxWrites, 1);
      final other = await store.readInbox('https://panel.example:other');
      expect(other, isEmpty);
    },
  );

  test(
    'queued withdrawal defeats replay and failed snapshot is retryable',
    () async {
      final prefs = _CountingPreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      final store = ZolnitRealtimePreferencesStore();
      const scope = 'https://panel.example:batch';
      final item = ZolnitRealtimeInboxItem(
        id: 'a' * 32,
        title: 'Title',
        body: 'Body',
        createdAt: DateTime.now(),
        popup: true,
      );
      prefs.failInbox = true;
      await expectLater(
        store.mergeSnapshot(scope, [item], [], isCurrent: () => true),
        throwsStateError,
      );
      prefs.failInbox = false;
      await store.mergeSnapshot(scope, [item], [], isCurrent: () => true);
      await Future.wait([
        store.withdrawInbox(scope, [item.id]),
        store.mergeSnapshot(scope, [item], [], isCurrent: () => true),
      ]);
      expect(await store.readInbox(scope), isEmpty);
    },
  );

  test(
    'coordinator snapshot writes once and identical refresh writes zero',
    () async {
      final prefs = _CountingPreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      final subject = 'b' * 64;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final events = List.generate(
        100,
        (i) => {
          'id': i.toRadixString(16).padLeft(32, '0'),
          'type': 'notice.published',
          'data': {'title': 'Title $i', 'body': 'x' * 1024},
          'created_at': now - i,
        },
      );
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {'subject': subject, 'events': events},
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer fixture');
      final coordinator = ZolnitInboxCoordinator(
        api: () => api,
        current: (gen) => api.generation == gen,
        foreground: () => true,
        liveRead: (_) async => false,
        updateTitle: () => 'Update',
        onConnect: (_, _) {},
        onPopup: (_, _, _) {},
        onUpdated: (_) {},
        onWithdrawn: (_) {},
        onUnread: () {},
        onUpdateHint: (_) {},
      );
      addTearDown(() {
        coordinator.dispose();
        api.close();
      });
      await coordinator.refresh(api.generation);
      expect(prefs.inboxWrites, 1);
      expect(coordinator.unread, 100);
      await coordinator.refresh(api.generation);
      expect(prefs.inboxWrites, 1);
    },
  );

  test('superseded snapshot does not report an uncommitted merge', () async {
    final store = ZolnitRealtimePreferencesStore();
    final item = ZolnitRealtimeInboxItem(
      id: 'e' * 32,
      title: 'Title',
      body: 'Body',
      createdAt: DateTime.now(),
      popup: true,
    );
    var checks = 0;
    final result = await store.mergeSnapshot(
      'https://panel.example:batch',
      [item],
      [],
      isCurrent: () => ++checks < 5,
    );
    expect(result.merges, isEmpty);
    expect(await store.readInbox('https://panel.example:batch'), isEmpty);
  });

  test(
    'withdrawal queued during snapshot write prevents later replay',
    () async {
      final prefs = _BlockingPreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      final store = ZolnitRealtimePreferencesStore();
      const scope = 'https://panel.example:batch';
      final item = ZolnitRealtimeInboxItem(
        id: 'f' * 32,
        title: 'Title',
        body: 'Body',
        createdAt: DateTime.now(),
        popup: true,
      );
      final snapshot = store.mergeSnapshot(
        scope,
        [item],
        [],
        isCurrent: () => true,
      );
      await prefs.started.future;
      final withdrawal = store.withdrawInbox(scope, [item.id]);
      prefs.release.complete();
      await Future.wait([snapshot, withdrawal]);
      await store.mergeSnapshot(scope, [item], [], isCurrent: () => true);
      expect(await store.readInbox(scope), isEmpty);
    },
  );

  test(
    'installed update in a snapshot is acknowledged and remains read',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'ZolNit',
        packageName: 'test',
        version: '1.2.3',
        buildNumber: '10',
        buildSignature: '',
      );
      final subject = 'b' * 64;
      final id = 'a' * 32;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        clientPlatform: 'macos',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'subject': subject,
                'events': [
                  {
                    'id': id,
                    'type': 'client.update',
                    'data': {'platform': 'all', 'build': 5, 'version': '1.2.3'},
                    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  },
                ],
              },
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer fixture');
      var acknowledgements = 0;
      final coordinator = ZolnitInboxCoordinator(
        api: () => api,
        current: (gen) => api.generation == gen,
        foreground: () => true,
        liveRead: (_) async {
          acknowledgements++;
          return true;
        },
        updateTitle: () => 'Update',
        onConnect: (_, _) {},
        onPopup: (_, _, _) {},
        onUpdated: (_) {},
        onWithdrawn: (_) {},
        onUnread: () {},
        onUpdateHint: (_) {},
      );
      addTearDown(() {
        coordinator.dispose();
        api.close();
      });
      await coordinator.refresh(api.generation);
      expect(acknowledgements, 1);
      expect(coordinator.unread, 0);
      expect(
        (await coordinator.read('https://panel.example:$subject')).single.read,
        isTrue,
      );
    },
  );

  test('queued account write is discarded after generation changes', () async {
    final preferences = _BlockingPreferences();
    SharedPreferencesStorePlatform.instance = preferences;
    final store = ZolnitRealtimePreferencesStore();
    const scope = 'https://panel.example:old-account';
    final item = ZolnitRealtimeInboxItem(
      id: 'a' * 32,
      title: 'Old account',
      body: 'Must not be saved',
      createdAt: DateTime.now(),
      popup: false,
    );
    final blocker = store.write(scope, const ZolnitRealtimeState());
    await preferences.started.future;
    var current = true;
    final pending = store.appendInbox(scope, item, isCurrent: () => current);
    current = false;
    preferences.release.complete();
    await blocker;
    expect(await pending, isFalse);
    expect(await store.readInbox(scope), isEmpty);
  });

  test(
    'invalidated snapshot is refetched before a withdrawn notice appears',
    () async {
      final first = Completer<http.Response>();
      final second = Completer<http.Response>();
      final started = Completer<void>();
      final nextStarted = Completer<void>();
      var requests = 0;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((request) {
          requests++;
          if (requests == 1) {
            started.complete();
            return first.future;
          }
          nextStarted.complete();
          return second.future;
        }),
      )..setAuthorization('Bearer fixture');
      final popups = <String>[];
      final coordinator = ZolnitInboxCoordinator(
        api: () => api,
        current: (generation) => api.generation == generation,
        foreground: () => true,
        liveRead: (_) async => false,
        updateTitle: () => 'Update',
        onConnect: (_, _) {},
        onPopup: (item, _, _) => popups.add(item.id),
        onUpdated: (_) {},
        onWithdrawn: (_) {},
        onUnread: () {},
        onUpdateHint: (_) {},
      );
      addTearDown(() {
        coordinator.dispose();
        api.close();
      });
      final id = 'a' * 32;
      final subject = 'b' * 64;
      final generation = api.generation;
      final old = coordinator.refresh(generation);
      await started.future;
      coordinator.invalidate();
      final newer = coordinator.refresh(generation);
      first.complete(
        http.Response(
          jsonEncode({
            'data': {
              'subject': subject,
              'events': [
                {
                  'id': id,
                  'type': 'notice.popup',
                  'data': {'title': 'Late', 'body': 'Withdrawn'},
                  'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                },
              ],
            },
          }),
          200,
        ),
      );
      await nextStarted.future;
      second.complete(
        http.Response(
          jsonEncode({
            'data': {
              'subject': subject,
              'events': [],
              'withdrawn': [id],
            },
          }),
          200,
        ),
      );
      await Future.wait([old, newer]);
      expect(requests, 2);
      expect(popups, isEmpty);
      expect(await coordinator.read('https://panel.example:$subject'), isEmpty);
      await coordinator.apply(
        id,
        'notice.popup',
        {'title': 'Replay', 'body': 'Late'},
        'https://panel.example:$subject',
        generation,
        DateTime.now(),
        false,
      );
      expect(popups, isEmpty);
      expect(await coordinator.read('https://panel.example:$subject'), isEmpty);
    },
  );

  test(
    'account switch discards presentation from an already started platform write',
    () async {
      final preferences = _BlockingPreferences()..block = false;
      SharedPreferencesStorePlatform.instance = preferences;
      final id = 'a' * 32;
      var subject = 'b' * 64;
      var title = 'Old account';
      final oldScope = 'https://panel.example:$subject';
      final newScope = 'https://panel.example:${'c' * 64}';
      final store = ZolnitRealtimePreferencesStore();
      await store.appendInbox(
        newScope,
        ZolnitRealtimeInboxItem(
          id: id,
          title: 'Existing new account history',
          body: 'Body',
          createdAt: DateTime.now(),
          popup: true,
        ),
      );
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': {
                'subject': subject,
                'events': [
                  {
                    'id': id,
                    'type': 'notice.popup',
                    'data': {'title': title, 'body': 'Body'},
                    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  },
                ],
              },
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer fixture');
      final popups = <String>[];
      final coordinator = ZolnitInboxCoordinator(
        api: () => api,
        current: (generation) => api.generation == generation,
        foreground: () => true,
        liveRead: (_) async => false,
        updateTitle: () => 'Update',
        onConnect: (_, _) {},
        onPopup: (item, _, _) => popups.add(item.title),
        onUpdated: (_) {},
        onWithdrawn: (_) {},
        onUnread: () {},
        onUpdateHint: (_) {},
      );
      addTearDown(() {
        if (!preferences.release.isCompleted) preferences.release.complete();
        coordinator.dispose();
        api.close();
      });
      preferences.block = true;
      final old = coordinator.refresh(api.generation);
      await preferences.started.future;
      coordinator.invalidate();
      subject = 'c' * 64;
      title = 'Existing new account history';
      api.setAuthorization('Bearer next');
      coordinator.reset();
      final newer = coordinator.refresh(api.generation);
      preferences.release.complete();
      await Future.wait([old, newer]);
      await coordinator.refresh(api.generation);
      expect(popups, isEmpty);
      expect(coordinator.canonicalNotices.value, isEmpty);
      expect((await store.readInbox(oldScope)).single.title, 'Old account');
      expect((await store.readInbox(newScope)).single.title, title);
      final saved = (await preferences.getAll()).values.whereType<String>();
      expect(saved.any((value) => value.contains('Old account')), isTrue);
    },
  );

  test(
    'account switch during live read prevents HTTP fallback and storage write',
    () async {
      final live = Completer<bool>();
      var readRequests = 0;
      final subject = 'b' * 64;
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/realtime/read')) readRequests++;
          return http.Response(
            jsonEncode({
              'data': {'subject': subject, 'events': []},
            }),
            200,
          );
        }),
      )..setAuthorization('Bearer fixture');
      final coordinator = ZolnitInboxCoordinator(
        api: () => api,
        current: (generation) => api.generation == generation,
        foreground: () => true,
        liveRead: (_) => live.future,
        updateTitle: () => 'Update',
        onConnect: (_, _) {},
        onPopup: (_, _, _) {},
        onUpdated: (_) {},
        onWithdrawn: (_) {},
        onUnread: () {},
        onUpdateHint: (_) {},
      );
      addTearDown(() {
        coordinator.dispose();
        api.close();
      });
      final generation = api.generation;
      await coordinator.refresh(generation);
      final scope = 'https://panel.example:$subject';
      final item = ZolnitRealtimeInboxItem(
        id: 'a' * 32,
        title: 'Notice',
        body: 'Body',
        createdAt: DateTime.now(),
        popup: false,
      );
      await coordinator.store.appendInbox(scope, item);
      final pending = coordinator.markRead(item, scope, generation);
      api.setAuthorization('Bearer next');
      coordinator.reset();
      live.complete(false);
      expect(await pending, isFalse);
      expect(readRequests, 0);
      expect((await coordinator.read(scope)).single.read, isFalse);
    },
  );
}
