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

typedef _Reply = Map<String, dynamic>? Function(String method, Object? data);

class _Edge implements ZolnitRealtimeSocket {
  _Edge(this.reply);
  final _Reply reply;
  final frames = StreamController<Object?>();
  final requests = <String>[];
  @override
  Stream<Object?> get messages => frames.stream;
  @override
  void send(Object value) {
    final m = value is String && value.startsWith('{')
        ? jsonDecode(value)
        : null;
    if (m is! Map || m['op'] != 'request') return;
    requests.add(m['method'] as String);
    final frame = reply(m['method'] as String, m['data']);
    if (frame != null) {
      scheduleMicrotask(
        () => receive({'op': 'response', 'id': m['id'], ...frame}),
      );
    }
  }

  void receive(Map<String, dynamic> frame) {
    if (!frames.isClosed) frames.add(jsonEncode({'v': 1, ...frame}));
  }

  void negotiate([
    List<String>? methods = const ['order.status', 'inbox.list', 'notice.list'],
  ]) {
    receive({'op': 'ready', 'methods': ?methods});
    receive({'op': 'pulse'});
  }

  @override
  Future<void> close() async {
    if (!frames.isClosed) await frames.close();
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  final subject = 'b' * 64, scope = 'https://panel.example:${'b' * 64}';
  late List<String> http_;
  late List<_Edge> edges;
  late XboardClient api;
  late _Reply reply;

  ZolnitRealtimeChannel channel({
    Future<void> Function(ZolnitRealtimeEvent)? onEvent,
  }) => ZolnitRealtimeChannel(
    api: api,
    scopeKey: () => scope,
    store: _Store(),
    connect: (_) async {
      final edge = _Edge((m, d) => reply(m, d));
      edges.add(edge);
      return edge;
    },
    random: () => 0,
    rpcTimeout: const Duration(milliseconds: 40),
    onResync: () async {},
    onEvent: onEvent ?? (_) async {},
  );

  setUp(() {
    http_ = [];
    edges = [];
    reply = (method, data) => switch (method) {
      'order.status' => {
        'data': {'result': (data as Map)['trade_no'] == 'paid' ? 3 : 0},
      },
      'inbox.list' => {
        'data': {
          'result': {'subject': subject, 'events': <Object>[]},
        },
      },
      'notice.list' => {
        'data': {
          'result': [
            {'id': 7, 'title': 'live'},
          ],
        },
      },
      _ => null,
    };
    api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/realtime/ticket')) {
          return http.Response(
            jsonEncode({
              'data': {'ticket': 'a' * 43, 'subject': subject},
            }),
            200,
          );
        }
        http_.add(path);
        final data = path.endsWith('/order/check')
            ? 1
            : path.endsWith('/notice/fetch')
            ? [
                {'id': 1, 'title': 'http'},
              ]
            : {'subject': subject, 'events': <Object>[]};
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    )..setAuthorization('Bearer fixture');
  });
  tearDown(() => api.close());

  test('negotiated healthy channel serves typed reads without HTTP', () async {
    final c = channel();
    await c.start();
    expect(api.liveReads, isNull);
    edges.single.negotiate();
    await _settle();
    expect(api.liveReads?.supports('order.status'), isTrue);
    expect(await api.orderStatus('paid'), 3);
    expect((await api.realtimeInbox()).subject, subject);
    expect((await api.notices() as List).single['title'], 'live');
    expect(edges.single.requests, [
      'order.status',
      'inbox.list',
      'notice.list',
    ]);
    expect(http_, isEmpty);
    expect(c.healthy, isTrue);
    await c.dispose();
    expect(api.liveReads, isNull);
  });

  test('an edge without methods keeps every read on HTTP', () async {
    final c = channel();
    await c.start();
    edges.single.negotiate(null);
    await _settle();
    expect(c.healthy, isTrue);
    expect(api.liveReads?.supports('order.status'), isFalse);
    expect(await api.orderStatus('paid'), 1);
    expect((await api.notices() as List).single['title'], 'http');
    expect(edges.single.requests, isEmpty);
    expect(http_, hasLength(2));
    await c.dispose();
  });

  test('an unsupported reply downgrades only that method', () async {
    reply = (method, data) => method == 'notice.list'
        ? {
            'error': {'code': 'unsupported'},
          }
        : {
            'data': {'result': 0},
          };
    final c = channel();
    await c.start();
    edges.single.negotiate();
    await _settle();
    expect((await api.notices() as List).single['title'], 'http');
    expect((await api.notices() as List).single['title'], 'http');
    expect(await api.orderStatus('t'), 0);
    expect(edges.single.requests, ['notice.list', 'order.status']);
    expect(http_, ['/api/v1/user/notice/fetch', '/api/v1/user/notice/fetch']);
    expect(c.healthy, isTrue);
    await c.dispose();
  });

  test(
    'a temporary read failure recovers on the next origin pulse without redialling',
    () async {
      var unavailable = true;
      reply = (_, _) => unavailable
          ? {'error': 'unavailable'}
          : {
              'data': {'result': 3},
            };
      final c = channel();
      await c.start();
      edges.single.negotiate();
      await _settle();
      expect(await api.orderStatus('paid'), 1);
      expect(c.supports('order.status'), false);
      unavailable = false;
      edges.single.receive({'op': 'pulse'});
      await _settle();
      expect(await api.orderStatus('paid'), 3);
      expect(http_, ['/api/v1/user/order/check']);
      expect(edges, hasLength(1));
      await c.dispose();
    },
  );

  for (final (name, broken) in <(String, _Reply)>[
    ('timeout', (_, _) => null),
    (
      'invalid result',
      (_, _) => {
        'data': {'result': 'three'},
      },
    ),
  ]) {
    test('$name falls back once, reconnects, then upgrades again', () async {
      final healthy = reply;
      reply = broken;
      final c = channel();
      await c.start();
      edges.single.negotiate();
      await _settle();
      expect(await api.orderStatus('paid'), 1);
      expect(http_, ['/api/v1/user/order/check']);
      expect(c.healthy, isFalse);
      expect(api.liveReads?.supports('order.status'), isFalse);
      reply = healthy;
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(edges, hasLength(2));
      edges.last.negotiate();
      await _settle();
      expect(await api.orderStatus('paid'), 3);
      expect(http_, hasLength(1));
      await c.dispose();
    });
  }

  test(
    'a new account generation never reads through the old channel',
    () async {
      final c = channel();
      await c.start();
      edges.single.negotiate();
      await _settle();
      api.setAuthorization('Bearer other');
      expect(api.liveReads, isNull);
      expect(c.supports('order.status'), isFalse);
      expect(await api.orderStatus('paid'), 1);
      expect(edges.single.requests, isEmpty);
      await c.dispose();
    },
  );

  test('an event handler can await a live read without stalling', () async {
    final results = <Object?>[];
    final c = channel(onEvent: (_) async => results.add(await api.notices()));
    await c.start();
    edges.single.negotiate();
    edges.single.receive({
      'op': 'event',
      'scope': 'global',
      'seq': 1,
      'id': 'a' * 32,
      'type': 'notice.changed',
      'data': {},
    });
    await _settle();
    expect((results.single as List).single['title'], 'live');
    expect(http_, isEmpty);
    expect(c.healthy, isTrue);
    await c.dispose();
  });

  test('responses may reach 64 KiB while other frames stay at 8 KiB', () async {
    final notices = [
      for (var i = 0; i < 300; i++) {'id': i, 'title': 'n' * 100},
    ];
    reply = (_, _) => {
      'data': {'result': notices},
    };
    final c = channel();
    await c.start();
    edges.single.negotiate();
    await _settle();
    expect(await api.notices(), hasLength(300));
    expect(http_, isEmpty);
    edges.single.receive({'op': 'pulse', 'pad': 'x' * 9000});
    await _settle();
    expect(c.healthy, isFalse);
    await c.dispose();
  });
}
