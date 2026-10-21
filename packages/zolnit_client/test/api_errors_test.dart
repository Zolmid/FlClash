import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

const _plugin = '/api/v1/zolnit-stripe/subscribe';
const _native = '/api/v1/user/order/save';

XboardClient _client(
  Future<http.Response> Function(http.Request) handler, {
  String Function()? language,
}) {
  final api = XboardClient(
    origin: Uri.parse('https://panel.example'),
    contentLanguage: language,
    client: MockClient(handler),
  )..setAuthorization('Bearer fixture');
  addTearDown(api.close);
  return api;
}

Future<ClientFailure> _failure(
  String path,
  int status,
  Object? body, {
  bool rawBody = false,
}) async {
  final api = _client(
    (_) async => http.Response.bytes(
      utf8.encode(rawBody ? body as String : jsonEncode(body)),
      status,
    ),
  );
  try {
    await api.request(path);
  } on ClientFailure catch (error) {
    return error;
  }
  throw StateError('request unexpectedly succeeded');
}

void main() {
  group('plugin messages share the website mapping', () {
    final cases = {
      'Resolve pending orders before subscribing': 'pending_order',
      'You have an unpaid order': 'pending_order',
      'FX quote expired or mismatched; refresh and consent again':
          'quote_expired',
      'An automatic billing contract already exists': 'checkout_exists',
      'Checkout session is still processing': 'checkout_processing',
      'Too many requests: rate limit': 'rate_limited',
    };
    cases.forEach((message, code) {
      test('409 "$message" becomes $code without exposing the text', () async {
        final error = await _failure(_plugin, 409, {'message': message});
        expect(error.code, code);
        expect(error.statusCode, 409);
        expect(error.serverMessage, isNull);
      });
    });

    test(
      'a Chinese reason is kept; an unknown English one is dropped',
      () async {
        const reason = '请先在个人中心取消原套餐的自动续费，再开通新的连续包月。';
        final chinese = await _failure(_plugin, 409, {'message': reason});
        expect(chinese.code, 'api_error');
        expect(chinese.serverMessage, reason);
        final english = await _failure(_plugin, 409, {
          'message': 'Boom happened',
        });
        expect(english.code, 'api_error');
        expect(english.serverMessage, isNull);
      },
    );

    test('5xx plugin bodies are never read', () async {
      final error = await _failure(_plugin, 500, {'message': '请稍后重试。'});
      expect(error.code, 'api_error');
      expect(error.serverMessage, isNull);
    });
  });

  group('native XBoard messages', () {
    test('business errors reported as HTTP 500 keep their reason', () async {
      const reason =
          'You have an unpaid or pending order, please try again later or '
          'cancel it';
      final error = await _failure(_native, 500, {
        'status': 'fail',
        'message': reason,
        'data': null,
      });
      expect(error.code, 'api_error');
      expect(error.statusCode, 500);
      expect(error.serverMessage, reason);
    });

    test('validation reasons are kept for 4xx', () async {
      final error = await _failure(_native, 422, {'message': '邮箱格式不正确'});
      expect(error.serverMessage, '邮箱格式不正确');
    });

    test('generic, oversized or internal text is dropped', () async {
      for (final message in [
        'Server Error',
        '',
        '   ',
        'x' * 301,
        'SQLSTATE[HY000] [2002] Connection refused',
        'Error in /www/app/Http/Controllers/V1/User/OrderController.php',
        'Call to undefined method App\\Models\\Order::boom()',
        'bad\u0000text',
      ]) {
        final error = await _failure(_native, 500, {'message': message});
        expect(error.serverMessage, isNull, reason: message);
      }
    });

    test('malformed, empty or non-object bodies keep the plain code', () async {
      for (final body in ['', 'not json', '[1]', '{"message":7}']) {
        final error = await _failure(_native, 500, body, rawBody: true);
        expect(error.code, 'api_error', reason: body);
        expect(error.serverMessage, isNull, reason: body);
      }
    });
  });

  test('authentication failures never expose the server text', () async {
    for (final status in [401, 403]) {
      for (final path in [_native, _plugin]) {
        final error = await _failure(path, status, {
          'message': 'PRIVATE_DO_NOT_RENDER',
        });
        expect(error.code, 'unauthenticated');
        expect(error.statusCode, status);
        expect(error.serverMessage, isNull);
      }
    }
  });

  test('toString never includes the server message', () async {
    final error = await _failure(_native, 500, {'message': '订单未支付'});
    expect(error.serverMessage, '订单未支付');
    expect(error.toString(), 'ClientFailure(api_error)');
  });

  test('a changed account still wins over an error body', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = _client((_) {
      started.complete();
      return response.future;
    });
    final result = api.request(_native);
    final assertion = expectLater(
      result,
      throwsA(isA<ClientFailure>().having((e) => e.code, 'code', 'superseded')),
    );
    await started.future;
    api.setAuthorization('Bearer other');
    response.complete(
      http.Response.bytes(utf8.encode('{"message":"订单未支付"}'), 500),
    );
    await assertion;
  });

  group('Content-Language', () {
    Future<String?> sent(String Function()? language) async {
      String? header;
      final api = _client((request) async {
        header = request.headers['Content-Language'];
        return http.Response('{"data":{}}', 200);
      }, language: language);
      await api.request(_native);
      return header;
    }

    test('is sent for a valid tag and omitted otherwise', () async {
      expect(await sent(() => 'zh-CN'), 'zh-CN');
      expect(await sent(() => 'en-US'), 'en-US');
      expect(await sent(() => ''), isNull);
      expect(await sent(() => 'zh_CN'), isNull);
      expect(await sent(() => 'zh-CN\r\nX-Evil: 1'), isNull);
      expect(await sent(null), isNull);
    });
  });
}
