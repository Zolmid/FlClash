import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'owned_dns_sdk.dart';
import 'owned_dns_config.dart';
import 'owned_dns_loopback.dart';

final class OwnedDnsAnswer {
  OwnedDnsAnswer(List<String> addresses, this.ttl)
    : addresses = List.unmodifiable(
        addresses.map((value) {
          final address = InternetAddress.tryParse(value);
          if (address == null ||
              address.isLoopback ||
              address.isMulticast ||
              address.address == '0.0.0.0' ||
              address.address == '::' ||
              value.contains('%')) {
            throw const FormatException('Invalid owned DNS address');
          }
          return address;
        }),
      ) {
    if (this.addresses.isEmpty ||
        this.addresses.length > 32 ||
        ttl < 0 ||
        ttl > 86400) {
      throw const FormatException('Invalid owned DNS answer');
    }
  }
  OwnedDnsAnswer._empty(this.ttl) : addresses = const [];
  final List<InternetAddress> addresses;
  final int ttl;
}

typedef OwnedDnsLookup = Future<OwnedDnsAnswer> Function(String host);

final class OwnedDnsResolver {
  OwnedDnsResolver({
    required Set<String> hosts,
    required this.lookup,
    this.strict = true,
    DateTime Function()? now,
  }) : hosts = Set.unmodifiable(hosts.map(_host)),
       _now = now ?? DateTime.now;

  final Set<String> hosts;
  final bool strict;
  final OwnedDnsLookup lookup;
  final DateTime Function() _now;
  final _cache = <String, (OwnedDnsAnswer, DateTime)>{};
  final _pending = <String, Future<OwnedDnsAnswer>>{};
  bool owns(String host) =>
      hosts.contains(host.toLowerCase().replaceFirst(RegExp(r'\.$'), ''));
  int _epoch = 0;
  void clear() {
    _epoch++;
    _cache.clear();
    _pending.clear();
  }

  Future<List<InternetAddress>> resolve(String name) async =>
      (await resolveAnswer(name)).addresses;

  Future<OwnedDnsAnswer> resolveAnswer(String name) async {
    final host = _host(name);
    if (!owns(host)) throw const FormatException('Unowned DNS hostname');
    final cached = _cache[host];
    if (cached != null && _now().isBefore(cached.$2)) {
      return OwnedDnsAnswer(
        cached.$1.addresses.map((ip) => ip.address).toList(),
        cached.$2.difference(_now()).inSeconds.clamp(0, cached.$1.ttl),
      );
    }
    _cache.remove(host);
    try {
      final answer = await (_pending[host] ??= _load(host));
      return answer;
    } catch (_) {
      if (strict) rethrow;
      return OwnedDnsAnswer(
        (await InternetAddress.lookup(host)).map((ip) => ip.address).toList(),
        0,
      );
    }
  }

  Future<OwnedDnsAnswer> _load(String host) async {
    final epoch = _epoch;
    try {
      final answer = await lookup(host).timeout(const Duration(seconds: 8));
      if (epoch != _epoch) {
        throw const SocketException('Owned DNS session changed');
      }
      if (answer.ttl > 0) {
        _cache[host] = (answer, _now().add(Duration(seconds: answer.ttl)));
      }
      return answer;
    } finally {
      if (epoch == _epoch) {
        final removed = _pending.remove(host);
        if (removed != null) {
          unawaited(removed.then<void>((_) {}, onError: (Object _) {}));
        }
      }
    }
  }

  HttpClient createHttpClient({
    SecurityContext? context,
    Future<ConnectionTask<Socket>> Function(List<InternetAddress>, int)?
    connect,
  }) {
    final client = _OwnedHttpOverrides().createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 10)
      ..findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (!owns(uri.host)) {
        if (proxyHost == null && uri.scheme == 'https') {
          return SecureSocket.startConnect(
            uri.host,
            uri.port,
            context: context,
          );
        }
        return Socket.startConnect(
          proxyHost ?? uri.host,
          proxyPort ?? uri.port,
        );
      }
      if (proxyHost != null) throw const SocketException('Owned DNS proxy');
      final addresses = await resolve(uri.host);
      if (connect != null) {
        return _secureTask(await connect(addresses, uri.port), uri, context);
      }
      return _connect(addresses, uri, context);
    };
    return client;
  }

  static Future<ConnectionTask<Socket>> _connect(
    List<InternetAddress> addresses,
    Uri uri,
    SecurityContext? context,
  ) async {
    final result = Completer<Socket>();
    var cancelled = false;
    ConnectionTask<Socket>? active;
    Socket? activeSocket;
    unawaited(() async {
      Object failure = const SocketException('Owned DNS dial failed');
      for (final address in addresses) {
        if (cancelled) return;
        try {
          final task = await Socket.startConnect(address, uri.port);
          active = task;
          var socket = await task.socket.timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              task.cancel();
              throw TimeoutException('Owned DNS dial');
            },
          );
          activeSocket = socket;
          if (uri.scheme == 'https') {
            socket = await SecureSocket.secure(
              socket,
              host: uri.host,
              context: context,
            ).timeout(const Duration(seconds: 4));
            activeSocket = socket;
          }
          if (cancelled) {
            socket.destroy();
            return;
          }
          result.complete(socket);
          return;
        } catch (error) {
          activeSocket?.destroy();
          failure = error;
        }
      }
      if (!result.isCompleted) result.completeError(failure);
    }());
    return ConnectionTask.fromSocket(result.future, () {
      cancelled = true;
      active?.cancel();
      activeSocket?.destroy();
      if (!result.isCompleted) {
        result.completeError(const SocketException('Owned DNS cancelled'));
      }
    });
  }

  static String _host(String value) {
    final host = value.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.length > 253 ||
        !RegExp(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(host) ||
        host.split('.').any((label) => label.isEmpty || label.length > 63) ||
        InternetAddress.tryParse(host) != null) {
      throw const FormatException('Invalid owned DNS hostname');
    }
    return host;
  }
}

Future<ConnectionTask<Socket>> _secureTask(
  ConnectionTask<Socket> task,
  Uri uri,
  SecurityContext? context,
) async {
  if (uri.scheme != 'https') return task;
  Socket? socket;
  var cancelled = false;
  final secured = task.socket.then<Socket>((raw) async {
    socket = raw;
    if (cancelled) {
      raw.destroy();
      throw const SocketException('Owned DNS cancelled');
    }
    try {
      final tls = await SecureSocket.secure(
        raw,
        host: uri.host,
        context: context,
      ).timeout(const Duration(seconds: 8));
      socket = tls;
      if (cancelled) {
        tls.destroy();
        throw const SocketException('Owned DNS cancelled');
      }
      return tls;
    } catch (_) {
      raw.destroy();
      rethrow;
    }
  });
  return ConnectionTask.fromSocket(secured, () {
    cancelled = true;
    task.cancel();
    socket?.destroy();
  });
}

class _OwnedHttpOverrides extends HttpOverrides {}

final class OwnedDnsBinding {
  OwnedDnsBinding._(
    this.config,
    Future<OwnedDnsAnswer?> Function(String)? sdkLookup,
  ) {
    final hosts = (config['hosts'] as List).cast<String>().toSet();
    _rawResolver = OwnedDnsResolver(
      hosts: hosts,
      strict: config['strict'] != false,
      lookup: _fetchRaw,
    );
    _loopback = OwnedDnsSdkLoopback(
      hosts: hosts,
      rawLookup: _rawResolver.resolveAnswer,
      adapter: ownedDnsSdkAdapter,
    );
    _sdkLookup = sdkLookup ?? _loopback.lookup;
    resolver = OwnedDnsResolver(
      hosts: (config['hosts'] as List).cast<String>().toSet(),
      strict: config['strict'] != false,
      lookup: _lookup,
    );
  }
  final Map<String, dynamic> config;
  late final Future<OwnedDnsAnswer?> Function(String) _sdkLookup;
  late final OwnedDnsResolver _rawResolver;
  late final OwnedDnsSdkLoopback _loopback;
  late final OwnedDnsResolver resolver;
  String? _authorization;
  Map<String, dynamic> get coreConfig => {
    ...config,
    if (_authorization != null) 'authorization': _authorization,
  };
  void setAuthorization(String? value) {
    if (_authorization == value) return;
    _authorization = value;
    resolver.clear();
    _rawResolver.clear();
    _loopback.invalidate();
  }

  Future<bool> configureSdkDiagnostic({
    required String accountId,
    required String accessKeyId,
    required String accessKeySecret,
  }) async => false;

  Future<void> disableSdkDiagnostic() async {
    resolver.clear();
    await _loopback.close();
  }

  static OwnedDnsBinding? fromEnvironment() {
    const raw = String.fromEnvironment('ZOLNIT_OWNED_DNS');
    const clientBuild =
        bool.fromEnvironment('ZOLNIT_NATIVE_UI') ||
        bool.fromEnvironment('ZOLNIT_CLIENT_BUNDLE') ||
        String.fromEnvironment('ZOLNIT_DISTRIBUTION') == 'direct';
    if (raw.isEmpty && !clientBuild) return null;
    final binding = fromJson(
      jsonDecode(raw.isEmpty ? zolnitReleaseOwnedDns : raw)
          as Map<String, dynamic>,
    );
    if (const bool.fromEnvironment('dart.vm.product') &&
        clientBuild &&
        !binding.resolver.strict) {
      throw const FormatException('Release owned DNS must be strict');
    }
    return binding;
  }

  static OwnedDnsBinding fromJson(
    Map<String, dynamic> config, {
    Future<OwnedDnsAnswer?> Function(String)? sdkLookup,
  }) {
    final relay = Uri.parse(config['relay'] as String);
    final hosts = (config['hosts'] as List).cast<String>().toSet();
    if (relay !=
            Uri.parse('https://link.zolmid.com/api/v1/zolnit/client/httpdns') ||
        !hosts.contains('link.zolmid.com') ||
        hosts.length > 256 ||
        hosts.any(
          (host) =>
              host != 'link.zolmid.com' &&
              (!host.endsWith('.nodes.zolmid.com') || host.contains('*')),
        ) ||
        (config['strict'] != null && config['strict'] is! bool) ||
        config.keys.any((key) => !{'relay', 'hosts', 'strict'}.contains(key))) {
      throw const FormatException('Invalid owned DNS relay binding');
    }
    return OwnedDnsBinding._(
      Map.unmodifiable({...config, 'strict': config['strict'] != false}),
      sdkLookup,
    );
  }

  Future<OwnedDnsAnswer> _lookup(String host) => lookupWithOwnedDnsSdk(
    host,
    sdk: _sdkLookup,
    fallback: _rawResolver.resolveAnswer,
  );

  Future<OwnedDnsAnswer> _fetchRaw(String host) async {
    if (host == 'link.zolmid.com') return bootstrapZolnitOrigin();
    final authorization = _authorization;
    if (authorization == null) {
      throw const SocketException('Owned DNS unauthenticated');
    }
    final client = _rawResolver.createHttpClient();
    try {
      final relay = Uri.parse(config['relay'] as String);
      final req = await client.getUrl(
        relay.replace(queryParameters: {'host': host}),
      );
      req.followRedirects = false;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, authorization);
      final response = await req.close();
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType != 'application/json') {
        throw const FormatException('Owned DNS relay status');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 8192) {
          throw const FormatException('Owned DNS response size');
        }
        bytes.addAll(chunk);
      }
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return OwnedDnsAnswer(
        (data['addresses'] as List).cast<String>(),
        data['ttl'] as int,
      );
    } finally {
      client.close(force: true);
    }
  }
}

Future<OwnedDnsAnswer> lookupWithOwnedDnsSdk(
  String host, {
  required Future<OwnedDnsAnswer?> Function(String) sdk,
  required OwnedDnsLookup fallback,
}) async {
  try {
    final answer = await sdk(host).timeout(const Duration(seconds: 3));
    if (answer != null) {
      return OwnedDnsAnswer(
        answer.addresses.map((ip) => ip.address).toList(),
        answer.ttl,
      );
    }
  } catch (_) {}
  return fallback(host);
}

Future<OwnedDnsAnswer> bootstrapZolnitOrigin({
  Future<OwnedDnsAnswer> Function(int)? query,
}) async {
  Future<OwnedDnsAnswer?> family(int type) async {
    try {
      return await (query ?? _queryOwnedBootstrapFamily)(type);
    } catch (_) {
      return null;
    }
  }

  final answers = await Future.wait([family(1), family(28)]);
  final addresses = <String>[];
  var ttl = 86400;
  for (final answer in answers) {
    if (answer == null || answer.addresses.isEmpty) continue;
    addresses.addAll(answer.addresses.map((ip) => ip.address));
    if (answer.ttl < ttl) ttl = answer.ttl;
  }
  return OwnedDnsAnswer(addresses, ttl);
}

const ownedDnsBootstrapLiterals = [
  '223.5.5.5',
  '2400:3200::1',
  '223.6.6.6',
  '2400:3200:baba::1',
];

Future<OwnedDnsAnswer> raceOwnedDnsBootstrapEndpoints({
  required Future<OwnedDnsAnswer> Function(String) exchange,
  Duration stagger = const Duration(milliseconds: 150),
}) {
  final result = Completer<OwnedDnsAnswer>();
  var pending = ownedDnsBootstrapLiterals.length;
  Future<void> attempt(int index) async {
    await Future<void>.delayed(stagger * index);
    if (result.isCompleted) return;
    try {
      final answer = await exchange(
        ownedDnsBootstrapLiterals[index],
      ).timeout(const Duration(seconds: 2));
      if (!result.isCompleted) result.complete(answer);
    } catch (_) {
      pending--;
      if (pending == 0 && !result.isCompleted) {
        result.completeError(
          const SocketException('Owned DNS bootstrap failed'),
        );
      }
    }
  }

  for (var i = 0; i < ownedDnsBootstrapLiterals.length; i++) {
    unawaited(attempt(i));
  }
  return result.future;
}

Future<OwnedDnsAnswer> _queryOwnedBootstrapFamily(int type) async {
  final wire = <int>[0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0];
  for (final label in 'link.zolmid.com'.split('.')) {
    wire.add(label.length);
    wire.addAll(ascii.encode(label));
  }
  wire.addAll([0, 0, type, 0, 1]);

  final clients = <HttpClient>{};
  try {
    return await raceOwnedDnsBootstrapEndpoints(
      exchange: (literal) async {
        final client = _OwnedHttpOverrides().createHttpClient(null)
          ..connectionTimeout = const Duration(seconds: 3)
          ..findProxy = (_) => 'DIRECT';
        client.connectionFactory = (uri, proxyHost, proxyPort) async =>
            _secureTask(
              await Socket.startConnect(InternetAddress(literal), 443),
              uri,
              null,
            );

        clients.add(client);
        try {
          final req = await client.getUrl(
            Uri.https('dns.alidns.com', '/dns-query', {
              'dns': base64Url.encode(wire).replaceAll('=', ''),
            }),
          );
          req.followRedirects = false;
          req.headers.set(HttpHeaders.acceptHeader, 'application/dns-message');
          final response = await req.close().timeout(
            const Duration(seconds: 4),
          );
          if (response.statusCode != 200 ||
              response.headers.contentType?.mimeType !=
                  'application/dns-message') {
            throw const FormatException('Invalid bootstrap response');
          }
          final bytes = <int>[];
          await for (final chunk in response.timeout(
            const Duration(seconds: 4),
          )) {
            if (bytes.length + chunk.length > 65535) {
              throw const FormatException('Bootstrap size');
            }
            bytes.addAll(chunk);
          }
          return decodeOwnedBootstrap(Uint8List.fromList(bytes), type);
        } finally {
          clients.remove(client);
          client.close(force: true);
        }
      },
    );
  } finally {
    for (final client in clients.toList()) {
      client.close(force: true);
    }
  }
}

OwnedDnsAnswer decodeOwnedBootstrap(Uint8List bytes, int type) {
  final data = ByteData.sublistView(bytes);
  int u16(int offset) => data.getUint16(offset);
  var offset = 12;
  String name() {
    final labels = <String>[];
    var cursor = offset;
    var jumped = false;
    final visited = <int>{};
    while (true) {
      if (cursor >= bytes.length || !visited.add(cursor)) {
        throw const FormatException('DNS name');
      }
      final size = bytes[cursor++];
      if (size == 0) {
        if (!jumped) offset = cursor;
        break;
      }
      if (size & 192 == 192) {
        if (cursor >= bytes.length) throw const FormatException('DNS pointer');
        final target = ((size & 63) << 8) | bytes[cursor++];
        if (!jumped) offset = cursor;
        jumped = true;
        cursor = target;
        continue;
      }
      if (size > 63 || cursor + size > bytes.length) {
        throw const FormatException('DNS label');
      }
      labels.add(
        ascii.decode(bytes.sublist(cursor, cursor + size)).toLowerCase(),
      );
      cursor += size;
    }
    return labels.join('.');
  }

  if (bytes.length < 12 ||
      u16(0) != 0 ||
      u16(2) & 0x820f != 0x8000 ||
      u16(4) != 1 ||
      name() != 'link.zolmid.com' ||
      u16(offset) != type ||
      u16(offset + 2) != 1) {
    throw const FormatException('DNS bootstrap header');
  }
  offset += 4;
  final aliases = <String>{'link.zolmid.com'};
  final records = <(String, int, int, Uint8List)>[];
  var ttl = 86400;
  for (var i = 0; i < u16(6); i++) {
    final owner = name();
    final rrType = u16(offset), rrClass = u16(offset + 2);
    final recordTtl = data.getUint32(offset + 4), size = u16(offset + 8);
    offset += 10;
    final end = offset + size;
    if (end > bytes.length) throw const FormatException('DNS record');
    if (rrClass == 1 && aliases.contains(owner)) {
      if (recordTtl < ttl) ttl = recordTtl;
      if (rrType == 5) aliases.add(name());
      if (rrType == type && size == (type == 1 ? 4 : 16)) {
        records.add((
          owner,
          rrType,
          recordTtl,
          Uint8List.sublistView(bytes, offset, end),
        ));
      }
    }
    offset = end;
  }
  final addresses = records
      .map((rr) => InternetAddress.fromRawAddress(rr.$4).address)
      .toList();
  // A family may legitimately have no records; the combined A/AAAA result must not be empty.
  return addresses.isEmpty
      ? _emptyBootstrapAnswer(ttl)
      : OwnedDnsAnswer(addresses, ttl);
}

OwnedDnsAnswer _emptyBootstrapAnswer(int ttl) => OwnedDnsAnswer._empty(ttl);

final ownedDnsBinding = OwnedDnsBinding.fromEnvironment();
