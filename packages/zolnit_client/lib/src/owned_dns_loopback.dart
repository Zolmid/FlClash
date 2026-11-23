import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'owned_dns.dart';
import 'owned_dns_sdk.dart';

final class _SdkLookup {
  _SdkLookup(this.epoch);
  final int epoch;
  final issued = <String, DateTime?>{};
}

final class OwnedDnsSdkLoopback {
  OwnedDnsSdkLoopback({
    required Set<String> hosts,
    required this.rawLookup,
    required this.adapter,
    DateTime Function()? now,
  }) : hosts = Set.unmodifiable(hosts),
       _now = now ?? DateTime.now;

  final Set<String> hosts;
  final OwnedDnsLookup rawLookup;
  final OwnedDnsSdkAdapter adapter;
  final DateTime Function() _now;
  final _active = <String, _SdkLookup>{};
  final _pending = <String, Future<OwnedDnsAnswer?>>{};
  final _lease = Stopwatch();
  HttpServer? _server;
  Future<bool>? _starting;
  DateTime? _expiresAt, _retryAfter;
  String _keyId = '', _secret = '';
  int _epoch = 0, _requests = 0;
  bool _closed = false;

  void invalidate() {
    _epoch++;
    _active.clear();
    _pending.clear();
  }

  Future<OwnedDnsAnswer?> lookup(String host) async {
    if (_closed || !adapter.supported || !hosts.contains(host)) return null;
    return _pending[host] ??= _perform(host);
  }

  Future<OwnedDnsAnswer?> _perform(String host) async {
    final epoch = _epoch;
    try {
      if (!await (_starting ??= _start().whenComplete(() {
            _starting = null;
          })) ||
          epoch != _epoch) {
        return null;
      }
      final transaction = _SdkLookup(epoch);
      _active[host] = transaction;
      final result = await adapter.lookup(host);
      if (result == null ||
          _closed ||
          epoch != _epoch ||
          _active[host] != transaction) {
        return null;
      }
      var ttl = 86400;
      for (final ip in result.addresses) {
        if (!transaction.issued.containsKey(_ipKey(ip))) return null;
        final deadline = transaction.issued[_ipKey(ip)];
        if (deadline != null && !_now().isBefore(deadline)) return null;
        final remaining = deadline == null
            ? 0
            : deadline.difference(_now()).inSeconds;
        if (remaining < ttl) ttl = remaining;
      }
      return OwnedDnsAnswer(
        result.addresses.map((ip) => ip.address).toList(),
        ttl,
      );
    } catch (_) {
      return null;
    } finally {
      if (epoch == _epoch) {
        _active.remove(host);
        final pending = _pending.remove(host);
        if (pending != null)
          unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
      }
    }
  }

  Future<bool> _start() async {
    if (_closed) return false;
    if (_server != null &&
        _expiresAt != null &&
        _now().isBefore(_expiresAt!) &&
        _lease.elapsed < const Duration(minutes: 5)) {
      return true;
    }
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) return false;
    await _server?.close(force: true);
    _server = null;
    final random = Random.secure();
    String nonce() => List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _keyId = nonce();
    _secret = nonce();
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    server.idleTimeout = const Duration(seconds: 3);
    _server = server;
    _expiresAt = _now().add(const Duration(minutes: 5));
    _lease
      ..reset()
      ..start();
    server.listen((request) {
      unawaited(_handle(request));
    }, onError: (Object _) {});
    final ready = await adapter.configureLoopback(
      hosts: hosts,
      port: server.port,
      keyId: _keyId,
      secret: _secret,
      expiresAt: _expiresAt!,
    );
    if (!ready || _closed) {
      await server.close(force: true);
      if (_server == server) _server = null;
      _secret = '';
      _keyId = '';
      _retryAfter = _now().add(const Duration(minutes: 1));
      return false;
    }
    return true;
  }

  Future<void> _handle(HttpRequest request) async {
    request.response.persistentConnection = false;
    var admitted = false;
    try {
      final server = _server;
      final query = request.uri.queryParameters;
      final host = query['name'];
      final transaction = _active[host];
      final type = int.tryParse(query['type'] ?? '');
      final timestamp = int.tryParse(query['ts'] ?? '');
      var headerBytes = 0;
      request.headers.forEach((name, values) {
        headerBytes += name.length + values.join().length;
      });
      if (_closed ||
          server == null ||
          request.connectionInfo?.remoteAddress.isLoopback != true ||
          request.method != 'GET' ||
          request.uri.path != '/resolve' ||
          request.uri.toString().length > 8192 ||
          request.headers.value(HttpHeaders.hostHeader) !=
              '127.0.0.1:${server.port}' ||
          request.contentLength > 0 ||
          request.uri.queryParametersAll.values.any(
            (values) => values.length != 1,
          ) ||
          headerBytes > 8192 ||
          host == null ||
          !hosts.contains(host) ||
          transaction == null ||
          transaction.epoch != _epoch ||
          (type != 1 && type != 28) ||
          timestamp == null ||
          query['uid'] != '1' ||
          query['ak'] != _keyId ||
          (_now().millisecondsSinceEpoch ~/ 1000 - timestamp).abs() > 10 ||
          _expiresAt == null ||
          !_now().isBefore(_expiresAt!) ||
          _lease.elapsed >= const Duration(minutes: 5) ||
          !_equal(
            (query['key'] ?? '').toLowerCase(),
            sha256
                .convert(utf8.encode('1$_secret$timestamp$host$_keyId'))
                .toString(),
          )) {
        request.response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (_requests >= 4) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      _requests++;
      admitted = true;
      final answer = await rawLookup(host).timeout(const Duration(seconds: 5));
      if (_active[host] != transaction || transaction.epoch != _epoch) {
        request.response.statusCode = HttpStatus.forbidden;
        return;
      }
      final selected = answer.addresses
          .where((ip) => (type == 1) == (ip.type == InternetAddressType.IPv4))
          .toList();
      for (final ip in selected) {
        final deadline = answer.ttl == 0
            ? null
            : _now().add(Duration(seconds: answer.ttl));
        if (!transaction.issued.containsKey(_ipKey(ip))) {
          transaction.issued[_ipKey(ip)] = deadline;
        } else {
          final before = transaction.issued[_ipKey(ip)];
          if (deadline == null ||
              (before != null && deadline.isBefore(before))) {
            transaction.issued[_ipKey(ip)] = deadline;
          }
        }
      }
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.write(
        jsonEncode({
          'Status': 0,
          'Question': {'name': host, 'type': type},
          'Answer': [
            for (final ip in selected)
              {
                'name': host,
                'type': type,
                'TTL': answer.ttl,
                'data': ip.address,
              },
          ],
        }),
      );
    } catch (_) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
    } finally {
      if (admitted) _requests--;
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  static String _ipKey(InternetAddress address) =>
      base64Encode(address.rawAddress);

  static bool _equal(String actual, String expected) {
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> close() async {
    _closed = true;
    invalidate();
    _lease.stop();
    await _server?.close(force: true);
    _server = null;
    _secret = '';
    _keyId = '';
    await adapter.disable();
  }
}
