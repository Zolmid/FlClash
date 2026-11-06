import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'api.dart';

typedef RealtimeJson = Map<String, dynamic>;

final class ZolnitRealtimeCursor {
  const ZolnitRealtimeCursor({this.global = 0, this.account = 0})
    : assert(global >= 0),
      assert(account >= 0);

  final int global;
  final int account;

  RealtimeJson toJson() => {'global': global, 'account': account};

  static ZolnitRealtimeCursor? parse(Object? value) {
    if (value is! Map || value['global'] is! int || value['account'] is! int) {
      return null;
    }
    final global = value['global'] as int;
    final account = value['account'] as int;
    return global < 0 || account < 0
        ? null
        : ZolnitRealtimeCursor(global: global, account: account);
  }
}

final class ZolnitRealtimeEvent {
  const ZolnitRealtimeEvent({
    required this.scope,
    required this.seq,
    required this.id,
    required this.type,
    required this.data,
  });

  final String scope;
  final int seq;
  final String id;
  final String type;
  final RealtimeJson data;

  static ZolnitRealtimeEvent? parse(Object? value) {
    if (value is! Map ||
        value['v'] != 1 ||
        value['op'] != 'event' ||
        (value['scope'] != 'global' && value['scope'] != 'account') ||
        value['seq'] is! int ||
        (value['seq'] as int) <= 0 ||
        value['id'] is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(value['id'] as String) ||
        value['type'] is! String ||
        !RegExp(
          r'^[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+$',
        ).hasMatch(value['type'] as String) ||
        value['data'] is! Map) {
      return null;
    }
    return ZolnitRealtimeEvent(
      scope: value['scope'] as String,
      seq: value['seq'] as int,
      id: value['id'] as String,
      type: value['type'] as String,
      data: Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(value['data'] as Map),
      ),
    );
  }
}

abstract interface class ZolnitRealtimeStore {
  Future<ZolnitRealtimeState> read(String scopeKey);
  Future<void> write(String scopeKey, ZolnitRealtimeState state);
}

final class ZolnitRealtimeState {
  const ZolnitRealtimeState({
    this.cursor = const ZolnitRealtimeCursor(),
    this.dedup = const <String>{},
  });

  final ZolnitRealtimeCursor cursor;
  final Set<String> dedup;
}

abstract interface class ZolnitRealtimeSocket {
  Stream<Object?> get messages;
  void send(Object value);
  Future<void> close();
}

typedef ZolnitRealtimeConnect =
    Future<ZolnitRealtimeSocket> Function(String ticket);

// The SDK WebSocket upgrader only uses openUrl on its supplied client. Never
// forward a single-use credential across a redirect (including to a subdomain).
final class _UpgradeClient implements HttpClient {
  final inner = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    final req = await inner.openUrl(method, uri);
    req.followRedirects = false;
    return req;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _IoSocket implements ZolnitRealtimeSocket {
  _IoSocket(this.socket, this.client);
  final WebSocket socket;
  final HttpClient client;
  @override
  Stream<Object?> get messages => socket;
  @override
  void send(Object value) => socket.add(value);
  @override
  Future<void> close() async {
    try {
      await socket.close().timeout(const Duration(seconds: 2));
    } finally {
      client.close(force: true);
    }
  }
}

Future<ZolnitRealtimeSocket> connectZolnitRealtimeSocket(String ticket) async {
  final client = _UpgradeClient();
  try {
    final ws = await WebSocket.connect(
      'wss://link.zolmid.com/realtime/v1/socket',
      headers: {'Authorization': 'Bearer $ticket'},
      protocols: ['zolnit.v1'],
      customClient: client,
      compression: CompressionOptions.compressionOff,
    ).timeout(const Duration(seconds: 12));
    if (ws.protocol != 'zolnit.v1') {
      unawaited(ws.close());
      throw const FormatException('realtime protocol');
    }
    return _IoSocket(ws, client.inner);
  } catch (_) {
    client.inner.close(force: true);
    rethrow;
  }
}

const zolnitLiveReadMethods = {'order.status', 'inbox.list', 'notice.list'};

final class ZolnitRealtimeChannel implements ZolnitLiveReads {
  ZolnitRealtimeChannel({
    required this.api,
    required this.scopeKey,
    required this.store,
    required this.onEvent,
    required this.onResync,
    this.onHealthChanged,
    ZolnitRealtimeConnect? connect,
    this.random = _defaultRandom,
    this.pulseTimeout = const Duration(seconds: 150),
    this.rpcTimeout = const Duration(seconds: 8),
  }) : _connect = connect ?? connectZolnitRealtimeSocket,
       _production = connect == null,
       _apiGeneration = api.generation;
  final XboardClient api;
  final String Function() scopeKey;
  final ZolnitRealtimeStore store;
  final Future<void> Function(ZolnitRealtimeEvent) onEvent;
  final Future<void> Function() onResync;
  final void Function()? onHealthChanged;
  final ZolnitRealtimeConnect _connect;
  final bool _production;
  final double Function() random;
  final Duration pulseTimeout;
  final Duration rpcTimeout;
  final int _apiGeneration;
  ZolnitRealtimeSocket? _socket;
  // Both normal disposal and failed sessions cancel this subscription in _drop.
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _sub;
  Timer? _retry, _deadline, _ping;
  bool _ready = false,
      _pulse = false,
      _reported = false,
      _foreground = true,
      _disposed = false,
      _opening = false,
      _pong = true;
  int _epoch = 0, _attempt = 0, _rpcId = 0;
  var _cursor = const ZolnitRealtimeCursor();
  final _dedup = <String>{};
  final _methods = <String>{};
  final _untilPulse = <String>{};
  final _requests = <String, Completer<Map<dynamic, dynamic>?>>{};
  bool get healthy =>
      !_disposed && _foreground && _socket != null && _ready && _pulse;
  bool _current(int epoch) => !_disposed && _foreground && epoch == _epoch;

  Future<void> start() => _open();
  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (foreground) {
      unawaited(_open());
    } else {
      _drop(retry: false);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    api.detachLiveReads(this);
    _drop(retry: false);
  }

  void _notify() {
    if (_reported != healthy) {
      _reported = healthy;
      onHealthChanged?.call();
    }
  }

  void _drop({required bool retry}) {
    ++_epoch;
    _ready = false;
    _pulse = false;
    _opening = false;
    _methods.clear();
    _untilPulse.clear();
    _retry?.cancel();
    _deadline?.cancel();
    _ping?.cancel();
    final sub = _sub;
    _sub = null;
    final s = _socket;
    _socket = null;
    if (sub != null) unawaited(sub.cancel().catchError((Object _) {}));
    if (s != null) unawaited(s.close().catchError((Object _) {}));
    for (final c in _requests.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _requests.clear();
    _notify();
    if (retry && !_disposed && _foreground) {
      _attempt = min(_attempt + 1, 8);
      _retry = Timer(
        Duration(
          milliseconds:
              (min(180, 1 << _attempt) * (0.75 + random() * 0.5) * 1000)
                  .round(),
        ),
        () => unawaited(_open()),
      );
    }
  }

  void _fail(int epoch) {
    if (_current(epoch)) _drop(retry: true);
  }

  void _watch(int epoch, Duration limit) {
    _deadline?.cancel();
    _deadline = Timer(limit, () => _fail(epoch));
  }

  Future<void> _open() async {
    if (_disposed || !_foreground || _opening || _socket != null) return;
    final epoch = ++_epoch, scope = scopeKey();
    _opening = true;
    _watch(epoch, const Duration(seconds: 20));
    try {
      if (_production && api.origin.origin != 'https://link.zolmid.com') {
        throw const FormatException();
      }
      final state = await store.read(scope);
      if (!_current(epoch)) return;
      final ticket = await api.realtimeTicket();
      if (!_current(epoch)) return;
      if (scope != '${api.origin.origin}:${ticket.subject}') {
        throw const FormatException('realtime subject');
      }
      final s = await _connect(ticket.ticket);
      if (!_current(epoch)) {
        await s.close();
        return;
      }
      _socket = s;
      _cursor = state.cursor;
      _dedup
        ..clear()
        ..addAll(state.dedup);
      _opening = false;
      _pong = true;
      var pending = 0;
      var buffered = 0;
      Future<void> order = Future.value();
      _sub = s.messages.listen(
        (raw) {
          if (!_current(epoch)) return;
          if (raw == 'pong') {
            _pong = true;
            return;
          }
          if (raw is! String ||
              raw.length > 65536 ||
              pending >= 96 ||
              buffered + raw.length > 262144) {
            _fail(epoch);
            return;
          }
          final Object? m;
          try {
            m = jsonDecode(raw);
          } on FormatException {
            _fail(epoch);
            return;
          }
          // A handler in the ordered chain may itself be awaiting this reply.
          if (m is Map && m['v'] == 1 && m['op'] == 'response') {
            _requests.remove(m['id'])?.complete(m);
            return;
          }
          if (raw.length > 8192) {
            _fail(epoch);
            return;
          }
          pending++;
          buffered += raw.length;
          order = order
              .then((_) async {
                if (_current(epoch)) await _frame(m, scope, epoch);
              })
              .catchError((Object _) {
                _fail(epoch);
              })
              .whenComplete(() {
                pending--;
                buffered -= raw.length;
              });
        },
        onError: (Object _, StackTrace _) => _fail(epoch),
        onDone: () => _fail(epoch),
        cancelOnError: true,
      );
      s.send(jsonEncode({'v': 1, 'op': 'hello', 'cursor': _cursor.toJson()}));
      _watch(epoch, const Duration(seconds: 30));
      _ping = Timer.periodic(const Duration(seconds: 35), (_) {
        if (!_current(epoch)) return;
        if (!_pong) {
          _fail(epoch);
          return;
        }
        _pong = false;
        try {
          s.send('ping');
        } catch (_) {
          _fail(epoch);
        }
      });
    } catch (_) {
      _fail(epoch);
    }
  }

  Future<void> _frame(Object? m, String scope, int epoch) async {
    if (m is! Map || m['v'] != 1) throw const FormatException();
    switch (m['op']) {
      case 'pulse':
        _untilPulse.clear();
        _pulse = true;
        if (_ready) {
          _attempt = 0;
          _watch(epoch, pulseTimeout);
        }
        _notify();
        return;
      case 'ready':
        final methods = m['methods'];
        _methods
          ..clear()
          ..addAll(
            methods is List
                ? methods.whereType<String>().where(
                    zolnitLiveReadMethods.contains,
                  )
                : const <String>[],
          );
        api.attachLiveReads(this, _apiGeneration);
        _ready = true;
        if (_pulse) _attempt = 0;
        _watch(epoch, pulseTimeout);
        _notify();
        return;
      case 'resync':
        final cursor = ZolnitRealtimeCursor.parse(m['cursor']);
        if (cursor == null) throw const FormatException();
        _ready = false;
        _notify();
        await onResync().timeout(const Duration(seconds: 22));
        if (!_current(epoch)) return;
        await store.write(
          scope,
          ZolnitRealtimeState(cursor: cursor, dedup: Set.of(_dedup)),
        );
        if (_current(epoch)) _cursor = cursor;
        return;
      case 'event':
        final e = ZolnitRealtimeEvent.parse(m);
        if (e == null) throw const FormatException();
        final global = e.scope == 'global',
            last = global ? _cursor.global : _cursor.account;
        if (e.seq > last + 1) throw const FormatException('realtime gap');
        if (e.seq == last + 1) {
          if (!_dedup.contains(e.id)) {
            await onEvent(e).timeout(const Duration(seconds: 22));
          }
          if (!_current(epoch)) return;
          final ids = Set.of(_dedup)..add(e.id);
          if (ids.length > 256) ids.remove(ids.first);
          final next = ZolnitRealtimeCursor(
            global: global ? e.seq : _cursor.global,
            account: global ? _cursor.account : e.seq,
          );
          await store.write(
            scope,
            ZolnitRealtimeState(cursor: next, dedup: ids),
          );
          if (!_current(epoch)) return;
          _cursor = next;
          _dedup
            ..clear()
            ..addAll(ids);
        }
        _socket?.send(
          jsonEncode({'v': 1, 'op': 'ack', 'scope': e.scope, 'seq': e.seq}),
        );
        return;
      default:
        throw const FormatException('realtime frame');
    }
  }

  Future<Map<dynamic, dynamic>?> _exchange(
    String method,
    RealtimeJson? data, {
    bool failOnTimeout = false,
  }) async {
    final s = _socket, epoch = _epoch;
    if (s == null || !_ready || _requests.length >= 8) return null;
    final id = 'r${++_rpcId}', c = Completer<Map<dynamic, dynamic>?>();
    _requests[id] = c;
    try {
      s.send(
        jsonEncode({
          'v': 1,
          'op': 'request',
          'method': method,
          'id': id,
          'data': ?data,
        }),
      );
      return await c.future.timeout(
        rpcTimeout,
        onTimeout: () {
          if (failOnTimeout) _fail(epoch);
          return null;
        },
      );
    } catch (_) {
      _fail(epoch);
      return null;
    } finally {
      _requests.remove(id);
    }
  }

  Future<RealtimeJson?> _rpc(String method, [RealtimeJson? data]) async {
    final reply = (await _exchange(method, data))?['data'];
    return reply is RealtimeJson ? reply : null;
  }

  @override
  bool supports(String method) =>
      healthy &&
      _methods.contains(method) &&
      !_untilPulse.contains(method) &&
      api.generation == _apiGeneration;

  @override
  Future<({Object? result})?> read(
    String method,
    RealtimeJson data,
    bool Function(Object? result) valid,
  ) async {
    if (!supports(method)) return null;
    final epoch = _epoch;
    final reply = await _exchange(method, data, failOnTimeout: true);
    if (reply == null || !_current(epoch)) return null;
    final body = reply['data'];
    if (body is Map && body.containsKey('result') && valid(body['result'])) {
      return (result: body['result']);
    }
    if (body == null && reply['error'] != null) {
      final error = reply['error'];
      if (error == 'unsupported' ||
          (error is Map && error['code'] == 'unsupported')) {
        _methods.remove(method);
      } else {
        _untilPulse.add(method);
      }
      return null;
    }
    _fail(epoch);
    return null;
  }

  Future<ZolnitRealtimeCursor?> status() async =>
      ZolnitRealtimeCursor.parse((await _rpc('channel.status'))?['cursor']);
  Future<bool> markInboxRead(String eventId) async {
    if (!healthy || !RegExp(r'^[a-f0-9]{32}$').hasMatch(eventId)) return false;
    final reply = await _rpc('inbox.read', {'event_id': eventId});
    return reply?['read'] == true && reply?['event_id'] == eventId;
  }
}

double _defaultRandom() => Random.secure().nextDouble();
