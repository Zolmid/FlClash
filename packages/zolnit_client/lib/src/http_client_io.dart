import 'dart:async';

import 'owned_dns.dart';

import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

typedef NativeRequestInvoker =
    Future<Object?> Function(String method, Map<String, Object?> arguments);

http.Client createClient({
  Uri? origin,
  NativeRequestInvoker? nativeRequest,
  bool? isAndroid,
}) {
  if ((isAndroid ?? Platform.isAndroid) &&
      origin == Uri.parse('https://link.zolmid.com')) {
    return AndroidFirstPartyClient(
      nativeRequest: nativeRequest ?? _invokeNativeRequest,
      fallback: _createDirectClient(),
    );
  }
  return _createDirectClient();
}

final _directClients = <DirectGenerationClient>{};

void notifyFirstPartyNetworkChanged() {
  ownedDnsBinding?.invalidateNetwork();
  for (final client in _directClients.toList()) {
    client.rotate();
  }
}

http.Client _createDirectClient() =>
    DirectGenerationClient(resolver: ownedDnsBinding?.resolver);

class DirectGenerationClient extends http.BaseClient {
  DirectGenerationClient({this.resolver}) {
    _directClients.add(this);
    resolver?.invalidationListeners.add(rotate);
  }

  final OwnedDnsResolver? resolver;
  _DirectGeneration? _current;
  final _draining = <_DirectGeneration>{};
  String? _authorization;
  bool _closed = false;

  void rotate() {
    final previous = _current;
    _current = null;
    if (previous == null) return;
    previous.retired = true;
    _draining.add(previous);
    _release(previous);
  }

  void _release(_DirectGeneration generation) {
    if (generation.retired && generation.sending == 0) {
      generation.inner.close();
    }
    if (generation.retired && generation.active == 0) {
      generation.client.close();
      _draining.remove(generation);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client is closed');
    final authorization = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .firstOrNull;
    if (_authorization != authorization) {
      rotate();
      _authorization = authorization;
    }
    final generation = _current ??= _DirectGeneration(
      (resolver?.createHttpClient() ??
            _DirectHttpOverrides().createHttpClient(null))
        ..badCertificateCallback = ((certificate, host, port) => false)
        ..findProxy = ((_) => 'DIRECT'),
    );
    generation.active++;
    generation.sending++;
    var sending = true;
    var released = false;
    void finish() {
      if (released) return;
      released = true;
      generation.active--;
      _release(generation);
    }

    try {
      final response = await generation.client.send(request);
      generation.sending--;
      sending = false;
      _release(generation);
      return http.StreamedResponse(
        _drainResponse(response.stream, finish),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      if (sending) generation.sending--;
      finish();
      rethrow;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _directClients.remove(this);
    resolver?.invalidationListeners.remove(rotate);
    _current?.client.close();
    _current = null;
    for (final generation in _draining) {
      generation.client.close();
    }
    _draining.clear();
  }
}

Stream<List<int>> _drainResponse(
  Stream<List<int>> stream,
  void Function() finish,
) async* {
  try {
    yield* stream;
  } finally {
    finish();
  }
}

class _DirectGeneration {
  _DirectGeneration(this.inner) : client = IOClient(inner);
  final HttpClient inner;
  final IOClient client;
  int active = 0;
  int sending = 0;
  bool retired = false;
}

Future<Object?> _invokeNativeRequest(
  String method,
  Map<String, Object?> arguments,
) => const MethodChannel(
  'com.zolmid.zolnit/service',
).invokeMethod<Object?>(method, arguments);

class AndroidFirstPartyClient extends http.BaseClient {
  AndroidFirstPartyClient({
    required NativeRequestInvoker nativeRequest,
    required http.Client fallback,
    this.requestTimeout = const Duration(seconds: 16),
  }) : _nativeRequest = nativeRequest,
       _fallback = fallback;

  static const _maxRequestBytes = 1024 * 1024;
  static const _maxResponseBytes = 8 * 1024 * 1024;
  static const _allowedMethods = {'GET', 'POST'};
  static const _allowedHeaders = {
    'accept',
    'authorization',
    'content-language',
    'content-type',
    'user-agent',
    'x-zolnit-core-version',
    'x-zolnit-distribution',
    'x-zolnit-platform',
    'x-zolnit-device-id',
    'x-zolnit-installation',
    'x-zolnit-subscription-format',
    'idempotency-key',
  };
  static final _instance = DateTime.now().microsecondsSinceEpoch.toRadixString(
    36,
  );
  static int _nextClient = 0;

  final NativeRequestInvoker _nativeRequest;
  final http.Client _fallback;
  final Duration requestTimeout;
  final String _clientId = '${_instance}_${_nextClient++}';
  final _pending = <String, Completer<http.StreamedResponse>>{};
  int _nextRequest = 0;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _ensureOpen();
    if (_pending.length >= 32) throw StateError('Too many pending requests');
    if (!_allowedMethods.contains(request.method) ||
        request.url.scheme != 'https' ||
        request.url.host != 'link.zolmid.com' ||
        request.url.port != 443 ||
        request.url.userInfo.isNotEmpty ||
        request.url.hasFragment ||
        !RegExp(r'^/api/v1/[A-Za-z0-9_/-]+$').hasMatch(request.url.path) ||
        request.url.path.contains('..') ||
        request.url.toString().length > 8192) {
      throw const FormatException('Invalid first-party request');
    }
    var headerBytes = 0;
    for (final entry in request.headers.entries) {
      headerBytes += entry.key.length + entry.value.length;
      if (!_allowedHeaders.contains(entry.key.toLowerCase()) ||
          entry.value.length > 8192 ||
          entry.value.codeUnits.any((byte) => byte < 32 || byte > 126)) {
        throw const FormatException('Invalid first-party request header');
      }
    }
    if (headerBytes > 16384) {
      throw const FormatException('First-party request headers are too large');
    }
    final requestId = '${_nextRequest++}';
    final cancelled = Completer<http.StreamedResponse>();
    final iterator = StreamIterator(request.finalize());
    _pending[requestId] = cancelled;
    var invoked = false;
    Future<http.StreamedResponse> perform() async {
      final bytes = BytesBuilder(copy: false);
      while (await iterator.moveNext()) {
        _ensureOpen();
        if (bytes.length + iterator.current.length > _maxRequestBytes) {
          throw const FormatException('First-party request is too large');
        }
        bytes.add(iterator.current);
      }
      _ensureOpen();
      if (cancelled.isCompleted) {
        throw http.ClientException('Request cancelled');
      }
      final body = bytes.takeBytes();
      if (request.method == 'GET' && body.isNotEmpty) {
        throw const FormatException('GET body is not allowed');
      }
      invoked = true;
      return _sendNative(request, body, requestId);
    }

    try {
      return await Future.any([
        perform(),
        cancelled.future,
      ]).timeout(requestTimeout);
    } catch (_) {
      if (!cancelled.isCompleted) {
        cancelled.completeError(http.ClientException('Request cancelled'));
      }
      if (invoked) unawaited(_cancelRequest(requestId));
      rethrow;
    } finally {
      _pending.remove(requestId);
      unawaited(iterator.cancel());
    }
  }

  Future<http.StreamedResponse> _sendNative(
    http.BaseRequest request,
    Uint8List body,
    String requestId,
  ) async {
    Object? value;
    try {
      final binding = ownedDnsBinding;
      final generation = binding?.resolver.generation;
      final addresses = await binding?.resolver.resolve(request.url.host);
      _ensureOpen();
      if (!_pending.containsKey(requestId) ||
          generation != binding?.resolver.generation) {
        throw http.ClientException('Request superseded');
      }
      value = await _nativeRequest('firstPartyHttpRequest', {
        'clientId': _clientId,
        'requestId': requestId,
        'url': request.url.toString(),
        'method': request.method,
        'headers': request.headers,
        'body': Uint8List.fromList(body),
        if (addresses != null)
          'addresses': addresses.map((ip) => ip.address).toList(),
      });
    } on MissingPluginException {
      _ensureOpen();
      if (!_pending.containsKey(requestId)) {
        throw http.ClientException('Request cancelled');
      }
      return _fallback.send(_copyRequest(request, body));
    }
    _ensureOpen();
    if (value is! Map ||
        value['status'] is! int ||
        (value['status'] as int) < 100 ||
        (value['status'] as int) > 599) {
      throw const FormatException('Invalid native HTTP response');
    }
    final responseBody = value['body'];
    if (responseBody is! Uint8List || responseBody.length > _maxResponseBytes) {
      throw const FormatException('Invalid native HTTP response body');
    }
    final rawHeaders = value['headers'];
    if (rawHeaders is! Map) {
      throw const FormatException('Invalid native HTTP response headers');
    }
    final headers = <String, String>{};
    var headerBytes = 0;
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid native HTTP response header');
      }
      headerBytes +=
          (entry.key as String).length + (entry.value as String).length;
      if (headerBytes > 16384) {
        throw const FormatException('Native HTTP headers are too large');
      }
      headers[entry.key as String] = entry.value as String;
    }
    return http.StreamedResponse(
      Stream.value(responseBody),
      value['status'] as int,
      headers: headers,
      request: request,
      isRedirect: false,
      contentLength: responseBody.length,
    );
  }

  http.Request _copyRequest(http.BaseRequest source, Uint8List body) =>
      http.Request(source.method, source.url)
        ..headers.addAll(source.headers)
        ..followRedirects = false
        ..bodyBytes = body;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(http.ClientException('Client is closed'));
      }
    }
    _fallback.close();
  }

  void _ensureOpen() {
    if (_closed) throw http.ClientException('Client is closed');
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await _nativeRequest('cancelFirstPartyHttpRequest', {
        'clientId': _clientId,
        'requestId': requestId,
      });
    } catch (_) {}
  }
}

class _DirectHttpOverrides extends HttpOverrides {}
