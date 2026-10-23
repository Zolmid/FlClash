import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'http_client.dart';

typedef Json = Map<String, dynamic>;

const _pluginPrefix = '/api/v1/zolnit-stripe/';
final _cjkRange = RegExp(r'[\u3400-\u9fff]');
final _controlChars = RegExp(r'[\x00-\x1f\x7f]');
final _internalDetail = RegExp(
  r'SQLSTATE|Stack trace|\.php|/www/|vendor/|Illuminate\\|App\\',
  caseSensitive: false,
);

class ClientFailure implements Exception {
  const ClientFailure(this.code, {this.statusCode, this.serverMessage});

  final String code;
  final int? statusCode;
  final String? serverMessage;

  @override
  String toString() => 'ClientFailure($code)';
}

class XboardClient {
  XboardClient({
    required Uri origin,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
    this.clientPlatform,
    this.distribution,
    this.userAgent = 'ZolNit/0',
    this.contentLanguage,
  }) : _client = client ?? createClient(),
       origin = _validateOrigin(origin) {
    if ((clientPlatform != null &&
            !{
              'android',
              'ios',
              'macos',
              'windows',
              'linux',
              'web',
            }.contains(clientPlatform)) ||
        (distribution != null &&
            !{'direct', 'apple-app-store'}.contains(distribution))) {
      throw const ClientFailure('invalid_client_context');
    }
  }

  final Uri origin;
  final http.Client _client;
  final Duration timeout;
  final String? clientPlatform;
  final String? distribution;
  final String userAgent;
  final String Function()? contentLanguage;
  String? _authorization;
  int _generation = 0;
  bool _closed = false;

  int get generation => _generation;

  static Uri _validateOrigin(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !{'', '/'}.contains(uri.path)) {
      throw const ClientFailure('invalid_origin');
    }
    return uri;
  }

  void setAuthorization(String? value) {
    if (_closed) throw const ClientFailure('closed');
    if (value != null &&
        !RegExp(r'^Bearer [A-Za-z0-9._~+/=|-]+$').hasMatch(value)) {
      throw const ClientFailure('invalid_authorization');
    }
    _authorization = value;
    _generation++;
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool unwrap = true,
  }) async {
    if (_closed) throw const ClientFailure('closed');
    if (!RegExp(r'^/api/v1/[A-Za-z0-9_/-]+$').hasMatch(path) ||
        path.contains('..')) {
      throw const ClientFailure('invalid_path');
    }
    final generation = _generation;
    final authorization = _authorization;
    if (authenticated && authorization == null) {
      throw const ClientFailure('unauthenticated');
    }
    final request = http.Request(
      method,
      origin.replace(path: path, queryParameters: query),
    )..followRedirects = false;
    final lang = contentLanguage?.call() ?? '';
    request.headers.addAll({
      'Accept': 'application/json',
      'User-Agent': userAgent,
      'X-ZolNit-Platform': ?clientPlatform,
      'X-ZolNit-Distribution': ?distribution,
      if (authenticated) 'Authorization': authorization!,
      if (body != null) 'Content-Type': 'application/json',
      if (lang.isNotEmpty && _validLang.hasMatch(lang))
        'Content-Language': lang,
    });
    if (body != null) request.body = jsonEncode(body);
    int? statusCode;
    try {
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      statusCode = response.statusCode;
      if (_closed || generation != _generation) {
        throw const ClientFailure('superseded');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _classifyError(
          path: path,
          statusCode: response.statusCode,
          bodyBytes: response.bodyBytes,
        );
      }
      final body = utf8.decode(response.bodyBytes);
      final value = response.bodyBytes.length > 65536
          ? await compute(jsonDecode, body)
          : jsonDecode(body);
      if (_closed || generation != _generation) {
        throw const ClientFailure('superseded');
      }
      if (value is! Map<String, dynamic> ||
          (unwrap && !value.containsKey('data'))) {
        throw ClientFailure('invalid_response', statusCode: statusCode);
      }
      return unwrap ? value['data'] : value;
    } catch (error) {
      if (_closed || generation != _generation) {
        throw const ClientFailure('superseded');
      }
      if (error is ClientFailure) rethrow;
      if (error is TimeoutException) throw const ClientFailure('timeout');
      if (error is FormatException) {
        throw ClientFailure('invalid_response', statusCode: statusCode);
      }
      throw const ClientFailure('network');
    }
  }

  static final _validLang = RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$');

  static final _pluginPatterns = <(RegExp, String)>[
    (
      RegExp(
        r'Resolve pending orders|unpaid.*order|pending order',
        caseSensitive: false,
      ),
      'pending_order',
    ),
    (RegExp(r'quote|报价|expired|过期', caseSensitive: false), 'quote_expired'),
    (
      RegExp(
        r'already exists|contract|already.*checkout|已有.*会话',
        caseSensitive: false,
      ),
      'checkout_exists',
    ),
    (
      RegExp(
        r'creating|pending|processing|reconcil|正在处理|准备中',
        caseSensitive: false,
      ),
      'checkout_processing',
    ),
    (
      RegExp(r'401|unauthori|Bearer|登录', caseSensitive: false),
      'unauthenticated',
    ),
    (RegExp(r'429|throttl|rate limit', caseSensitive: false), 'rate_limited'),
  ];

  static ClientFailure _classifyError({
    required String path,
    required int statusCode,
    required List<int> bodyBytes,
  }) {
    final isPlugin = path.startsWith(_pluginPrefix);
    if (statusCode == 401 ||
        (statusCode == 403 && path == '/api/v1/user/info')) {
      return ClientFailure('unauthenticated', statusCode: statusCode);
    }
    // XBoard reports business errors such as an unpaid order as HTTP 500; the
    // plugin only speaks 4xx for them, so its 5xx bodies stay unread.
    final message = isPlugin && statusCode >= 500
        ? null
        : _readMessage(bodyBytes);
    if (!isPlugin) {
      return ClientFailure(
        'api_error',
        statusCode: statusCode,
        serverMessage: message,
      );
    }
    if (message == null) {
      return ClientFailure('api_error', statusCode: statusCode);
    }
    for (final (pattern, mapped) in _pluginPatterns) {
      if (pattern.hasMatch(message)) {
        return ClientFailure(mapped, statusCode: statusCode);
      }
    }
    return ClientFailure(
      'api_error',
      statusCode: statusCode,
      serverMessage: _cjkRange.hasMatch(message) ? message : null,
    );
  }

  static String? _readMessage(List<int> bodyBytes) {
    try {
      final json = jsonDecode(utf8.decode(bodyBytes));
      final message = json is Map<String, dynamic> ? json['message'] : null;
      if (message is! String) return null;
      final text = message.trim();
      if (text.isEmpty ||
          text.length > 300 ||
          text == 'Server Error' ||
          _controlChars.hasMatch(text) ||
          _internalDetail.hasMatch(text)) {
        return null;
      }
      return text;
    } on FormatException {
      return null;
    }
  }

  Future<Json> login(String email, String password) async =>
      await request(
            '/api/v1/passport/auth/login',
            method: 'POST',
            body: {'email': email, 'password': password},
            authenticated: false,
          )
          as Json;

  Future<dynamic> register(Json fields) => request(
    '/api/v1/passport/auth/register',
    method: 'POST',
    body: fields,
    authenticated: false,
  );

  Future<dynamic> sendEmailCode(String email) => request(
    '/api/v1/passport/comm/sendEmailVerify',
    method: 'POST',
    body: {'email': email},
    authenticated: false,
  );

  Future<dynamic> resetPassword(Json fields) => request(
    '/api/v1/passport/auth/forget',
    method: 'POST',
    body: fields,
    authenticated: false,
  );

  Future<dynamic> account() => request('/api/v1/user/info');
  Future<dynamic> subscription() => request('/api/v1/user/getSubscribe');
  Future<dynamic> plans() => request('/api/v1/user/plan/fetch');
  Future<dynamic> nodes() => request('/api/v1/user/server/fetch');
  Future<dynamic> notices() => request('/api/v1/user/notice/fetch');
  Future<dynamic> orders() => request('/api/v1/user/order/fetch');
  Future<dynamic> paymentMethods() =>
      request('/api/v1/user/order/getPaymentMethod');

  Future<String> createOrder({
    required int planId,
    required String period,
    String? coupon,
  }) async =>
      await request(
            '/api/v1/user/order/save',
            method: 'POST',
            body: {'plan_id': planId, 'period': period, 'coupon_code': ?coupon},
          )
          as String;

  Future<dynamic> order(String tradeNo) =>
      request('/api/v1/user/order/detail', query: {'trade_no': tradeNo});

  Future<int> orderStatus(String tradeNo) async =>
      await request('/api/v1/user/order/check', query: {'trade_no': tradeNo})
          as int;

  Future<dynamic> cancelOrder(String tradeNo) => request(
    '/api/v1/user/order/cancel',
    method: 'POST',
    body: {'trade_no': tradeNo},
  );

  Future<Json> checkout(String tradeNo, int methodId) async =>
      await request(
            '/api/v1/user/order/checkout',
            method: 'POST',
            body: {'trade_no': tradeNo, 'method': methodId},
            unwrap: false,
          )
          as Json;

  Future<dynamic> checkCoupon(String code, int planId) => request(
    '/api/v1/user/coupon/check',
    method: 'POST',
    body: {'code': code, 'plan_id': planId},
  );

  Future<dynamic> tickets({int? id}) => request(
    '/api/v1/user/ticket/fetch',
    query: id == null ? null : {'id': '$id'},
  );

  Future<dynamic> createTicket({
    required String subject,
    required String message,
    int level = 1,
  }) => request(
    '/api/v1/user/ticket/save',
    method: 'POST',
    body: {'subject': subject, 'message': message, 'level': level},
  );

  Future<dynamic> replyTicket(int id, String message) => request(
    '/api/v1/user/ticket/reply',
    method: 'POST',
    body: {'id': id, 'message': message},
  );

  Future<dynamic> closeTicket(int id) =>
      request('/api/v1/user/ticket/close', method: 'POST', body: {'id': id});

  Future<dynamic> invite() => request('/api/v1/user/invite/fetch');
  Future<dynamic> createInviteCode() => request('/api/v1/user/invite/save');

  /// The panel answers this one as `{data: [...], total: n}`, so it is not unwrapped.
  Future<Json> inviteDetails({int page = 1, int pageSize = 10}) async =>
      await request(
            '/api/v1/user/invite/details',
            query: {'current': '$page', 'page_size': '$pageSize'},
            unwrap: false,
          )
          as Json;

  Future<dynamic> traffic() => request('/api/v1/user/stat/getTrafficLog');

  Future<dynamic> changePassword({
    required String oldPassword,
    required String newPassword,
  }) => request(
    '/api/v1/user/changePassword',
    method: 'POST',
    body: {'old_password': oldPassword, 'new_password': newPassword},
  );

  Future<dynamic> updateReminders({bool? expiry, bool? traffic}) => request(
    '/api/v1/user/update',
    method: 'POST',
    body: {
      'remind_expire': ?(expiry == null ? null : (expiry ? 1 : 0)),
      'remind_traffic': ?(traffic == null ? null : (traffic ? 1 : 0)),
    },
  );

  Future<dynamic> activeSessions() => request('/api/v1/user/getActiveSession');

  Future<dynamic> removeActiveSession(String id) => request(
    '/api/v1/user/removeActiveSession',
    method: 'POST',
    body: {'session_id': id},
  );

  void close() {
    _closed = true;
    _authorization = null;
    _generation++;
    _client.close();
  }
}
