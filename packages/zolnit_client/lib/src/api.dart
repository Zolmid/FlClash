import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'http_client.dart';

typedef Json = Map<String, dynamic>;

class ClientFailure implements Exception {
  const ClientFailure(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

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
    request.headers.addAll({
      'Accept': 'application/json',
      'X-ZolNit-Platform': ?clientPlatform,
      'X-ZolNit-Distribution': ?distribution,
      if (authenticated) 'Authorization': authorization!,
      if (body != null) 'Content-Type': 'application/json',
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
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ClientFailure('unauthenticated', statusCode: statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ClientFailure('api_error', statusCode: statusCode);
      }
      final value = response.bodyBytes.length > 65536
          ? await compute(jsonDecode, response.body)
          : jsonDecode(response.body);
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
  Future<dynamic> traffic() => request('/api/v1/user/stat/getTrafficLog');

  void close() {
    _closed = true;
    _authorization = null;
    _generation++;
    _client.close();
  }
}
