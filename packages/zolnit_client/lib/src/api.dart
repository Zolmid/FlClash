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
  const ClientFailure(
    this.code, {
    this.statusCode,
    this.serverMessage,
    this.retryAfter,
  });

  final String code;
  final int? statusCode;
  final String? serverMessage;
  final Duration? retryAfter;

  @override
  String toString() => 'ClientFailure($code)';
}

class ZolnitClientDevice {
  const ZolnitClientDevice({
    required this.deviceId,
    required this.installationId,
  });

  final String deviceId;
  final String installationId;

  Map<String, String> get headers => {
    'X-ZolNit-Device-Id': deviceId,
    'X-ZolNit-Installation': installationId,
  };
}

final class ZolnitRealtimeTicket {
  const ZolnitRealtimeTicket({required this.ticket, required this.subject});
  final String ticket;
  final String subject;
}

final class ZolnitRealtimeInbox {
  const ZolnitRealtimeInbox({
    required this.subject,
    required this.events,
    this.withdrawn = const [],
  });
  final String subject;
  final List<Json> events;
  final List<String> withdrawn;

  static ZolnitRealtimeInbox? parse(Object? value) {
    if (value is! Json ||
        value['subject'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['subject'] as String) ||
        value['events'] is! List ||
        (value['withdrawn'] != null &&
            (value['withdrawn'] is! List ||
                (value['withdrawn'] as List).length > 8192 ||
                !(value['withdrawn'] as List).every(
                  (id) =>
                      id is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(id),
                )))) {
      return null;
    }
    return ZolnitRealtimeInbox(
      subject: value['subject'] as String,
      withdrawn: List<String>.unmodifiable(
        (value['withdrawn'] as List?)?.cast<String>() ?? const [],
      ),
      events: List<Json>.unmodifiable(value['events'].whereType<Json>()),
    );
  }
}

/// Typed reads served over a negotiated realtime channel. [read] completes
/// with null whenever the caller must use the canonical HTTP endpoint.
abstract interface class ZolnitLiveReads {
  bool supports(String method);
  Future<({Object? result})?> read(
    String method,
    Json data,
    bool Function(Object? result) valid,
  );
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
  }) : _client = client ?? createClient(origin: origin),
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
  ZolnitLiveReads? _liveReads;
  int? _liveGeneration;

  int get generation => _generation;

  ZolnitLiveReads? get liveReads =>
      !_closed && _liveGeneration == _generation ? _liveReads : null;

  void attachLiveReads(ZolnitLiveReads reads, int generation) {
    if (_closed || generation != _generation) return;
    _liveReads = reads;
    _liveGeneration = generation;
  }

  void detachLiveReads(ZolnitLiveReads reads) {
    if (!identical(_liveReads, reads)) return;
    _liveReads = null;
    _liveGeneration = null;
  }

  Future<T> _preferLive<T>(
    String method,
    Json data,
    T? Function(Object?) parse,
    Future<T> Function() http,
  ) async {
    final live = liveReads;
    if (live != null && live.supports(method)) {
      final generation = _generation;
      final reply = await live.read(method, data, (v) => parse(v) != null);
      if (_closed || generation != _generation) {
        throw const ClientFailure('superseded');
      }
      if (reply != null) {
        final value = parse(reply.result);
        if (value != null) return value;
      }
    }
    return http();
  }

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
    String? coreVersion,
    Map<String, String> extraHeaders = const {},
  }) async {
    if (_closed) throw const ClientFailure('closed');
    if (!RegExp(r'^/api/v1/[A-Za-z0-9_/-]+$').hasMatch(path) ||
        path.contains('..')) {
      throw const ClientFailure('invalid_path');
    }
    if (coreVersion != null &&
        (coreVersion.length > 128 ||
            !RegExp(
              r'^v?[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
            ).hasMatch(coreVersion))) {
      throw const ClientFailure('core_version_required');
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
      'X-ZolNit-Core-Version': ?coreVersion,
      if (authenticated) 'Authorization': authorization!,
      if (body != null) 'Content-Type': 'application/json',
      if (lang.isNotEmpty && _validLang.hasMatch(lang))
        'Content-Language': lang,
      ...extraHeaders,
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
        if (response.statusCode == 429 &&
            path.startsWith('/api/v1/zolnit/client/apple/')) {
          final seconds = int.tryParse(response.headers['retry-after'] ?? '');
          throw ClientFailure(
            'rate_limited',
            statusCode: 429,
            retryAfter: Duration(
              seconds: seconds != null && seconds > 0
                  ? seconds.clamp(1, 86400)
                  : 60,
            ),
          );
        }
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

  Future<Json> fetchClientBundle({required String coreVersion}) async {
    if (clientPlatform == null || distribution == null) {
      throw const ClientFailure('invalid_client_context');
    }
    if (coreVersion.isEmpty) throw const ClientFailure('core_version_required');
    final value = await request(
      '/api/v1/zolnit/client/bundle',
      coreVersion: coreVersion,
    );
    if (value is! Json) throw const ClientFailure('invalid_client_bundle');
    return value;
  }

  Future<ZolnitClientDevice> registerClientDevice({
    required String installationId,
    required String platform,
    String? label,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(installationId) ||
        !const {
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
        }.contains(platform) ||
        (label?.length ?? 0) > 40) {
      throw const ClientFailure('invalid_device_registration');
    }
    final value = await request(
      '/api/v1/zolnit/client/devices/register',
      method: 'POST',
      body: {
        'installation_id': installationId,
        'platform': platform,
        'label': ?label,
      },
    );
    if (value is! Json ||
        value['device_id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['device_id'] as String) ||
        value['platform'] != platform) {
      throw const ClientFailure('invalid_device_registration');
    }
    return ZolnitClientDevice(
      deviceId: value['device_id'] as String,
      installationId: installationId,
    );
  }

  Future<Json> fetchSignedClientBundle({
    required String coreVersion,
    required ZolnitClientDevice device,
  }) async {
    final value = await request(
      '/api/v1/zolnit/client/bundle',
      coreVersion: coreVersion,
      extraHeaders: {
        ...device.headers,
        'X-ZolNit-Subscription-Format': 'signed-v2',
      },
    );
    if (value is! Json) {
      throw const ClientFailure('invalid_signed_subscription');
    }
    return value;
  }

  Future<Json> fetchSignedSubscriptionState(ZolnitClientDevice device) async {
    return _preferLive<Json>(
      'subscription.state',
      {'device_id': device.deviceId},
      (value) => value is Json ? value : null,
      () async {
        final value = await request(
          '/api/v1/zolnit/client/subscription/state',
          extraHeaders: device.headers,
        );
        if (value is! Json) {
          throw const ClientFailure('invalid_signed_subscription');
        }
        return value;
      },
    );
  }

  Future<Json?> fetchOnlineClientDevices() {
    if (clientPlatform == null || distribution == null) {
      return Future.value();
    }
    Json? parse(Object? value) =>
        value is Json && value.containsKey('online') ? value : null;
    return _preferLive<Json?>('device.status', const {}, parse, () async {
      return parse(await request('/api/v1/zolnit/client/devices/online'));
    });
  }

  Future<String> authorizeWebSession() async {
    final value = await request(
      '/api/v1/zolnit/client/web-session/authorize',
      method: 'POST',
      body: const {},
    );
    if (value is! Json ||
        value['code'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value['code'] as String)) {
      throw const ClientFailure('invalid_web_session');
    }
    return value['code'] as String;
  }

  Future<ZolnitRealtimeTicket> realtimeTicket() async {
    final value = await request(
      '/api/v1/zolnit/client/realtime/ticket',
      method: 'POST',
      body: const {},
    );
    if (value is! Json ||
        value['ticket'] is! String ||
        value['subject'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value['ticket'] as String) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['subject'] as String)) {
      throw const ClientFailure('invalid_realtime_ticket');
    }
    return ZolnitRealtimeTicket(
      ticket: value['ticket'] as String,
      subject: value['subject'] as String,
    );
  }

  Future<ZolnitRealtimeInbox> realtimeInbox() => _preferLive(
    'inbox.list',
    const {},
    ZolnitRealtimeInbox.parse,
    () async =>
        ZolnitRealtimeInbox.parse(
          await request('/api/v1/zolnit/client/realtime/inbox'),
        ) ??
        (throw const ClientFailure('invalid_realtime_inbox')),
  );

  Future<void> markRealtimeInboxRead(String eventId) async {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(eventId)) {
      throw const ClientFailure('invalid_realtime_event');
    }
    final value = await request(
      '/api/v1/zolnit/client/realtime/read',
      method: 'POST',
      body: {'event_id': eventId},
    );
    if (value is! Json ||
        value['event_id'] != eventId ||
        value['read'] != true) {
      throw const ClientFailure('invalid_realtime_receipt');
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
    if (path == '/api/v1/passport/zolnit-registration/exchange' &&
        statusCode == 400) {
      return const ClientFailure('registration_return_expired');
    }
    final isPlugin = path.startsWith(_pluginPrefix);
    if (path.startsWith('/api/v1/zolnit/client/')) {
      String? code;
      if (bodyBytes.length <= 8192) {
        try {
          final body = jsonDecode(utf8.decode(bodyBytes));
          final error = body is Map ? body['error'] : null;
          final value = error is Map ? error['code'] : null;
          if (value is String) code = value;
        } catch (_) {}
      }
      final classified = switch ((statusCode, code)) {
        (401, 'unauthenticated') => 'unauthenticated',
        (403, 'entitlement_unavailable') => 'entitlement_unavailable',
        (429, _) => 'rate_limited',
        (400 || 426, 'core_version_required') => 'core_version_required',
        (503, 'bundle_unavailable') => 'bundle_unavailable',
        _ => 'client_api_unavailable',
      };
      return ClientFailure(classified, statusCode: statusCode);
    }
    if (statusCode == 401 ||
        (statusCode == 403 &&
            path == '/api/v1/user/info' &&
            _isExpiredAccountResponse(bodyBytes))) {
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

  static bool _isExpiredAccountResponse(List<int> bodyBytes) {
    try {
      final value = jsonDecode(utf8.decode(bodyBytes));
      if (value is! Map<String, dynamic> || value['status'] != 'fail') {
        return false;
      }
      final error = value['error'];
      final code = error is Map ? error['code'] : null;
      const codes = {'unauthenticated', 'session_expired'};
      const messages = {'未登录或登陆已过期', '未登录或登录已过期'};
      return value['data'] == null &&
          ((code is String && codes.contains(code)) ||
              (error == null && messages.contains(value['message'])));
    } catch (_) {
      return false;
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

  Future<Json> exchangeRegistration(String code, String codeVerifier) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(codeVerifier)) {
      throw const ClientFailure('invalid_registration_callback');
    }
    return await request(
          '/api/v1/passport/zolnit-registration/exchange',
          method: 'POST',
          body: {'code': code, 'code_verifier': codeVerifier},
          authenticated: false,
        )
        as Json;
  }

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
  Future<dynamic> notices() => _preferLive<dynamic>(
    'notice.list',
    const {},
    (v) => v is List && v.every((e) => e is Json) ? v : null,
    () => request('/api/v1/user/notice/fetch'),
  );
  Future<List<Json>> knowledge({required String language}) async {
    final value = await request(
      '/api/v1/user/knowledge/fetch',
      query: {'language': language},
    );
    if (value is! Map && value is! List) {
      throw const ClientFailure('invalid_response');
    }
    final groups = value is Map ? value.values : [value];
    return [
      for (final group in groups)
        if (group is List) ...group.whereType<Json>(),
    ];
  }

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

  Future<int> orderStatus(String tradeNo) => _preferLive(
    'order.status',
    {'trade_no': tradeNo},
    (v) => v is int ? v : null,
    () async =>
        await request('/api/v1/user/order/check', query: {'trade_no': tradeNo})
            as int,
  );

  Future<dynamic> cancelOrder(String tradeNo) => request(
    '/api/v1/user/order/cancel',
    method: 'POST',
    body: {'trade_no': tradeNo},
  );

  Future<Json> checkout(
    String tradeNo,
    int methodId, {
    String? nativeWallet,
  }) async =>
      await request(
            '/api/v1/user/order/checkout',
            method: 'POST',
            body: {
              'trade_no': tradeNo,
              'method': methodId,
              'zolnit_native_wallet': ?nativeWallet,
            },
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
    _liveReads = null;
    _generation++;
    _client.close();
  }
}
