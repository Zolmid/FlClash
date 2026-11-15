import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/inbox_coordinator.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
