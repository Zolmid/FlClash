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
  Future<OwnedDnsAnswer?>? _remaining;
}

typedef OwnedDnsLookup = Future<OwnedDnsAnswer> Function(String host);

final class OwnedDnsResolver {
  OwnedDnsResolver({
    required Set<String> hosts,
    required this.lookup,
    this.strict = true,
    this.transportLookup,
    DateTime Function()? now,
  }) : hosts = Set.unmodifiable(hosts.map(_host)),
       _now = now ?? DateTime.now;

  final Set<String> hosts;
  final bool strict;
  final OwnedDnsLookup lookup;
  final OwnedDnsLookup? transportLookup;
  final invalidationListeners = <void Function()>{};
  final DateTime Function() _now;
  final _cache = <String, (OwnedDnsAnswer, DateTime)>{};
  final _pending = <String, Future<OwnedDnsAnswer>>{};
  bool owns(String host) =>
      hosts.contains(host.toLowerCase().replaceFirst(RegExp(r'\.$'), ''));
  int _epoch = 0;
  int get generation => _epoch;
  final _waiters = <Completer<OwnedDnsAnswer>>{};
  final _connections = <void Function()>{};
  void clear() {
    _epoch++;
    for (final listener in invalidationListeners.toList()) {
      listener();
    }
    for (final waiter in _waiters) {
      waiter.completeError(const SocketException('Owned DNS session changed'));
    }
    _waiters.clear();
    for (final cancel in _connections.toList()) {
      cancel();
    }
    _connections.clear();
    _cache.clear();
    _pending.clear();
  }

  Future<List<InternetAddress>> resolve(String name) async =>
      (await resolveAnswer(name)).addresses;

  Future<OwnedDnsAnswer> resolveAnswer(String name) async {
    final epoch = _epoch;
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
    final invalidated = Completer<OwnedDnsAnswer>();
    _waiters.add(invalidated);
    try {
      final answer = await Future.any([
        _pending[host] ??= _load(host),
        invalidated.future,
      ]);
      if (epoch != _epoch) {
        throw const SocketException('Owned DNS session changed');
      }
      return answer;
    } catch (_) {
      if (strict || epoch != _epoch) rethrow;
      final addresses = await InternetAddress.lookup(host);
      if (epoch != _epoch) {
        throw const SocketException('Owned DNS session changed');
      }
      return OwnedDnsAnswer(addresses.map((ip) => ip.address).toList(), 0);
    } finally {
      _waiters.remove(invalidated);
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

  Future<OwnedDnsAnswer> _resolveTransport(String host) async {
    final cached = _cache[host];
    if (transportLookup == null ||
        host != 'link.zolmid.com' ||
        cached != null && _now().isBefore(cached.$2)) {
      return resolveAnswer(host);
    }
    final invalidated = Completer<OwnedDnsAnswer>();
    _waiters.add(invalidated);
    try {
      return await Future.any([
        transportLookup!(host).timeout(const Duration(seconds: 3)),
        invalidated.future,
      ]);
    } finally {
      _waiters.remove(invalidated);
    }
  }

  HttpClient createHttpClient({
    SecurityContext? context,
    Future<ConnectionTask<Socket>> Function(List<InternetAddress>, int)?
    connect,
    Future<ConnectionTask<Socket>> Function(InternetAddress, int)? startConnect,
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
      final epoch = _epoch;
      final answer = await _resolveTransport(uri.host);
      final addresses = answer.addresses;
      if (epoch != _epoch) {
        throw const SocketException('Owned DNS session changed');
      }
      final task = connect != null
          ? await _secureTask(await connect(addresses, uri.port), uri, context)
          : await _connect(
              addresses,
              uri,
              context,
              startConnect,
              answer._remaining,
            );
      if (epoch != _epoch) {
        task.cancel();
      }
      void cancel() => task.cancel();
      _connections.add(cancel);
      final socket = task.socket
          .then<Socket>((socket) {
            if (epoch != _epoch) {
              socket.destroy();
              throw const SocketException('Owned DNS session changed');
            }
            return socket;
          })
          .whenComplete(() => _connections.remove(cancel));
      return ConnectionTask.fromSocket(socket, cancel);
    };
    return client;
  }

  static Future<ConnectionTask<Socket>> _connect(
    List<InternetAddress> addresses,
    Uri uri,
    SecurityContext? context,
    Future<ConnectionTask<Socket>> Function(InternetAddress, int)? startConnect,
    Future<OwnedDnsAnswer?>? remaining,
  ) async {
    final ordered = List<InternetAddress>.of(addresses);
    final opposite = ordered.indexWhere(
      (address) => address.type != ordered.first.type,
    );
    if (opposite > 1) ordered.insert(1, ordered.removeAt(opposite));
    final result = Completer<Socket>();
    final tasks = <ConnectionTask<Socket>>{};
    var finished = false;
    var next = 0;
    var active = 0;
    var waiting = remaining != null;
    Object lastError = const SocketException('Owned DNS dial failed');
    Timer? stagger;
    late final Timer deadline;
    void stop() {
      finished = true;
      stagger?.cancel();
      deadline.cancel();
      for (final task in tasks) {
        task.cancel();
      }
    }

    void fail(Object error) {
      if (finished) return;
      stop();
      result.completeError(error);
    }

    void launch() {
      if (finished || next >= ordered.length) return;
      final address = ordered[next++];
      active++;
      unawaited(() async {
        try {
          final task = await (startConnect ?? Socket.startConnect)(
            address,
            uri.port,
          );
          if (finished) {
            task.cancel();
            unawaited(
              task.socket.then<void>(
                (socket) => socket.destroy(),
                onError: (Object _) {},
              ),
            );
            return;
          }
          tasks.add(task);
          final socket = await task.socket;
          tasks.remove(task);
          if (finished) {
            socket.destroy();
            return;
          }
          stop();
          result.complete(socket);
        } catch (error) {
          active--;
          if (finished) return;
          lastError = error;
          if (active == 0) {
            if (next < ordered.length) {
              launch();
            } else if (!waiting) {
              fail(error);
            }
          }
        }
      }());
    }

    deadline = Timer(const Duration(seconds: 4), () {
      fail(TimeoutException('Owned DNS dial'));
    });
    stagger = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => launch(),
    );
    if (remaining != null) {
      unawaited(
        remaining.then<void>(
          (answer) {
            waiting = false;
            if (finished) return;
            if (answer != null) {
              for (final address in answer.addresses) {
                if (!ordered.any(
                  (existing) => existing.address == address.address,
                )) {
                  ordered.add(address);
                }
              }
            }
            if (active == 0) {
              if (next < ordered.length) {
                launch();
              } else {
                fail(lastError);
              }
            }
          },
          onError: (Object error) {
            waiting = false;
            if (!finished && active == 0 && next >= ordered.length) fail(error);
          },
        ),
      );
    }
    launch();
    return _secureTask(
      ConnectionTask.fromSocket(result.future, () {
        fail(const SocketException('Owned DNS cancelled'));
      }),
      uri,
      context,
    );
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
      transportLookup: (_) => bootstrapZolnitOrigin(firstUsable: true),
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
      transportLookup: (_) => bootstrapZolnitOrigin(firstUsable: true),
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
    invalidateNetwork();
  }

  void invalidateNetwork() {
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
  bool firstUsable = false,
}) async {
  Future<OwnedDnsAnswer?> family(int type) async {
    try {
      final answer = await (query ?? _queryOwnedBootstrapFamily)(
        type,
      ).timeout(const Duration(seconds: 3));
      return answer.addresses.isEmpty ? null : answer;
    } catch (_) {
      return null;
    }
  }

  final families = [family(1), family(28)];
  final ready = <OwnedDnsAnswer>[];
  final first = Completer<void>();
  final all = Future.wait(
    families.map((future) async {
      final answer = await future;
      if (answer != null) {
        ready.add(answer);
        if (!first.isCompleted) first.complete();
      }
    }),
  );
  unawaited(
    all.then((_) {
      if (!first.isCompleted) first.complete();
    }),
  );
  await first.future;
  if (firstUsable && ready.isNotEmpty) {
    await Future.any([
      all,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
  } else {
    await all;
  }
  OwnedDnsAnswer? combine() {
    if (ready.isEmpty) return null;
    return OwnedDnsAnswer(
      ready.expand((a) => a.addresses.map((ip) => ip.address)).toList(),
      ready.map((a) => a.ttl).reduce((a, b) => a < b ? a : b),
    );
  }

  final answer = combine();
  if (answer == null) {
    throw const SocketException('Owned DNS bootstrap unavailable');
  }
  answer._remaining = all.then((_) => combine());
  return answer;
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
