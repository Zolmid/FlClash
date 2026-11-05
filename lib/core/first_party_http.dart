import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:zolnit_client/zolnit_client.dart' show ClientFailure;

import 'method.dart';

class CoreFirstPartyHttpClient extends http.BaseClient {
  CoreFirstPartyHttpClient({
    required Future<Map<String, dynamic>?> Function(Map<String, dynamic>)
    invoke,
    required Future<bool> Function(String, String) cancel,
    required bool Function() useCore,
    http.Client? fallback,
    this.requestTimeout = const Duration(seconds: 24),
  }) : _invoke = invoke,
       _cancel = cancel,
       _useCore = useCore,
       _fallback = fallback ?? _directClient();

  static const _allowedHeaders = {
    'accept',
    'authorization',
    'content-language',
    'content-type',
    'user-agent',
    'x-zolnit-core-version',
    'x-zolnit-distribution',
    'x-zolnit-platform',
  };
  static const _maxRequestBytes = 1024 * 1024;
  static const _maxResponseBytes = 8 * 1024 * 1024;
  static int _nextClient = 0;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic>) _invoke;
  final Future<bool> Function(String, String) _cancel;
  final bool Function() _useCore;
  final http.Client _fallback;
  final Duration requestTimeout;
  final String _clientId =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_nextClient++}';
  final _pending = <String, Completer<http.StreamedResponse>>{};
  int _nextRequest = 0;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _ensureOpen();
    _validate(request);
    if (_pending.length >= 16) {
      throw const ClientFailure('operation_in_progress');
    }
    final requestId = '${_nextRequest++}';
    final cancelled = Completer<http.StreamedResponse>();
    final iterator = StreamIterator(request.finalize());
    _pending[requestId] = cancelled;
    var dispatched = false;
    var finished = false;
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
      if (cancelled.isCompleted) throw const ClientFailure('superseded');
      final body = bytes.takeBytes();
      if (request.method == 'GET' && body.isNotEmpty) {
        throw const FormatException('GET body is not allowed');
      }
      if (!_useCore()) return _fallback.send(_copyRequest(request, body));
      dispatched = true;
      final value = await _invoke({
        'client-id': _clientId,
        'request-id': requestId,
        'method': request.method,
        'url': request.url.toString(),
        'headers': request.headers,
        'body': base64Encode(body),
        'timeout': requestTimeout.inMilliseconds,
      });
      _ensureOpen();
      if (value == null) throw const ClientFailure('network');
      return _decode(value, request);
    }

    try {
      final response = await Future.any([
        perform(),
        cancelled.future,
      ]).timeout(requestTimeout);
      finished = true;
      return response;
    } on CoreMethodException catch (error) {
      throw ClientFailure(switch (error.code) {
        'timeout' => 'timeout',
        'cancelled' => 'superseded',
        'busy' => 'operation_in_progress',
        'invalid_request' ||
        'request_too_large' ||
        'response_too_large' => 'invalid_response',
        _ => 'network',
      });
    } finally {
      if (!cancelled.isCompleted) {
        cancelled.completeError(const ClientFailure('superseded'));
      }
      if (dispatched && !finished) unawaited(_cancelSafely(requestId));
      _pending.remove(requestId);
      unawaited(iterator.cancel());
    }
  }

  Future<void> _cancelSafely(String id) =>
      _cancel(_clientId, id).then<void>((_) {}, onError: (_) {});

  void _validate(http.BaseRequest request) {
    if (!{'GET', 'POST'}.contains(request.method) ||
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
    var total = 0;
    for (final entry in request.headers.entries) {
      total += entry.key.length + entry.value.length;
      if (!_allowedHeaders.contains(entry.key.toLowerCase()) ||
          entry.value.length > 8192 ||
          entry.value.codeUnits.any((char) => char < 32 || char > 126)) {
        throw const FormatException('Invalid first-party request header');
      }
    }
    if (total > 16384) {
      throw const FormatException('First-party request headers are too large');
    }
  }

  http.StreamedResponse _decode(
    Map<String, dynamic> value,
    http.BaseRequest request,
  ) {
    final status = value['status'];
    final encoded = value['body'];
    final rawHeaders = value['headers'];
    if (status is! int ||
        status < 100 ||
        status > 599 ||
        encoded is! String ||
        encoded.length > ((_maxResponseBytes + 2) ~/ 3) * 4 ||
        rawHeaders is! Map) {
      throw const FormatException('Invalid Core HTTP response');
    }
    final body = base64Decode(encoded);
    if (body.length > _maxResponseBytes) {
      throw const FormatException('Invalid Core HTTP response body');
    }
    final headers = <String, String>{};
    var total = 0;
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid Core HTTP response header');
      }
      total += (entry.key as String).length + (entry.value as String).length;
      if (total > 16384) {
        throw const FormatException('Core HTTP response headers are too large');
      }
      headers[entry.key as String] = entry.value as String;
    }
    return http.StreamedResponse(
      Stream.value(body),
      status,
      headers: headers,
      request: request,
      contentLength: body.length,
      isRedirect: false,
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
    for (final entry in _pending.entries.toList()) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(const ClientFailure('superseded'));
      }
      unawaited(_cancelSafely(entry.key));
    }
    _fallback.close();
  }

  void _ensureOpen() {
    if (_closed) throw const ClientFailure('superseded');
  }

  static http.Client _directClient() {
    final client = _DirectHttpOverrides().createHttpClient(null);
    client.badCertificateCallback = (_, _, _) => false;
    client.findProxy = (_) => 'DIRECT';
    return IOClient(client);
  }
}

class _DirectHttpOverrides extends HttpOverrides {}
