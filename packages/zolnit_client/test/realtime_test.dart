import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

class _Store implements ZolnitRealtimeStore {
  final _states = <String, ZolnitRealtimeState>{};
  @override
  Future<ZolnitRealtimeState> read(String key) async =>
      _states[key] ?? const ZolnitRealtimeState();
  @override
  Future<void> write(String key, ZolnitRealtimeState value) async =>
      _states[key] = value;
}

class _Socket implements ZolnitRealtimeSocket {
  final controller = StreamController<Object?>();
  final sent = <Object>[];
  @override
  Stream<Object?> get messages => controller.stream;
  @override
  void send(Object value) => sent.add(value);
  @override
  Future<void> close() => controller.close();
}

void main() {
  test('ticket is an exact authenticated POST response', () async {
    final requests = <http.Request>[];
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"data":{"ticket":"${'a' * 43}","subject":"${'b' * 64}"}}',
          200,
        );
      }),
    )..setAuthorization('Bearer panel-token');
    expect((await api.realtimeTicket()).ticket, 'a' * 43);
    expect(requests.single.url.path, '/api/v1/zolnit/client/realtime/ticket');
    expect(requests.single.method, 'POST');
    expect(requests.single.body, '{}');
  });

  test('replay is ignored and ack follows completed handling', () async {
    final socket = _Socket();
    final seen = <String>[];
    final channel = ZolnitRealtimeChannel(
      api: XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (_) async => http.Response(
            '{"data":{"ticket":"${'a' * 43}","subject":"${'b' * 64}"}}',
            200,
          ),
        ),
      )..setAuthorization('Bearer panel-token'),
      scopeKey: () => 'https://panel.example:${'b' * 64}',
      store: _Store(),
      connect: (_) async => socket,
      onResync: () async {},
      onEvent: (event) async => seen.add(event.type),
    );
    await channel.start();
    socket.controller.add(
      jsonEncode({
        'v': 1,
        'op': 'event',
        'scope': 'account',
        'seq': 1,
        'id': 'a' * 32,
        'type': 'account.changed',
        'data': {},
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    socket.controller.add(
      jsonEncode({
        'v': 1,
        'op': 'event',
        'scope': 'account',
        'seq': 1,
        'id': 'a' * 32,
        'type': 'unknown.optional',
        'data': {},
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(seen, ['account.changed']);
    expect(socket.sent.whereType<String>().join(), contains('"ack"'));
    await channel.dispose();
  });
  test('catch-up is ordered across slow handlers and resync commits', () async {
    final socket = _Socket(),
        store = _Store(),
        gate = Completer<void>(),
        applied = <int>[];
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'subject': 'b' * 64, 'ticket': 't' * 43},
          }),
          200,
        ),
      ),
    )..setAuthorization('Bearer fixture');
    final scope = 'https://panel.example:${'b' * 64}';
    final channel = ZolnitRealtimeChannel(
      api: api,
      scopeKey: () => scope,
      store: store,
      connect: (_) async => socket,
      onResync: () => gate.future,
      onEvent: (e) async {
        applied.add(e.seq);
      },
    );
    await channel.start();
    void frame(Map data) =>
        socket.controller.add(jsonEncode({'v': 1, ...data}));
    frame({
      'op': 'resync',
      'cursor': {'global': 5, 'account': 4},
    });
    frame({'op': 'ready'});
    frame({'op': 'pulse'});
    frame({
      'op': 'event',
      'scope': 'account',
      'seq': 5,
      'id': 'a' * 32,
      'type': 'account.changed',
      'data': {},
    });
    await Future<void>.delayed(Duration.zero);
    expect(applied, isEmpty);
    expect(channel.healthy, isFalse);
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(applied, [5]);
    expect(channel.healthy, isTrue);
    expect((await store.read(scope)).cursor.toJson(), {
      'global': 5,
      'account': 5,
    });
    expect(
      socket.sent.where((s) => s.toString().contains('"ack"')),
      hasLength(1),
    );
    await channel.dispose();
    api.close();
  });

  test(
    'handler/storage failure does not escape, acknowledge, or change the session',
    () async {
      final socket = _Socket(), store = _Store();
      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {'subject': 'b' * 64, 'ticket': 't' * 43},
            }),
            200,
          ),
        ),
      )..setAuthorization('Bearer fixture');
      final scope = 'https://panel.example:${'b' * 64}',
          generation = api.generation;
      final channel = ZolnitRealtimeChannel(
        api: api,
        scopeKey: () => scope,
        store: store,
        connect: (_) async => socket,
        onResync: () async {},
        onEvent: (e) async {
          throw StateError('disk unavailable');
        },
      );
      await channel.start();
      for (final frame in [
        {'op': 'ready'},
        {'op': 'pulse'},
        {
          'op': 'event',
          'scope': 'account',
          'seq': 1,
          'id': 'a' * 32,
          'type': 'account.changed',
          'data': {},
        },
      ]) {
        socket.controller.add(jsonEncode({'v': 1, ...frame}));
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(channel.healthy, isFalse);
      expect(api.generation, generation);
      expect((await store.read(scope)).cursor.account, 0);
      expect(socket.sent.any((s) => s.toString().contains('"ack"')), isFalse);
      await channel.dispose();
      api.close();
    },
  );
}
