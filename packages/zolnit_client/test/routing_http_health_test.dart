import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  RoutingHttpHealth assess({
    String provider = 'chatgpt',
    int status = 200,
    int? latency = 12,
    String error = '',
    String body = '',
  }) => assessRoutingHttpHealth(
    provider: provider,
    statusCode: status,
    latencyMs: latency,
    error: error,
    body: body,
  );

  void expectDenied(RoutingHttpHealth result, String reason) {
    expect(result.usableTransportSample, isFalse);
    expect(result.reason, reason);
    expect(result.latencyMs, isNull);
  }

  test('all known public probes require their exact HTTP status', () {
    for (final provider in routingProviderProbeUrls.keys) {
      final expected = provider == 'operator' ? 204 : 200;
      final result = assess(provider: provider, status: expected);
      expect(result.usableTransportSample, isTrue, reason: provider);
      expect(result.reason, 'public_http_transport');
      expect(result.latencyMs, 12);
      for (final status in [201, 202, 205, 206, expected == 204 ? 200 : 204]) {
        expectDenied(
          assess(provider: provider, status: status),
          'unexpected_status',
        );
      }
    }
  });

  test('zero latency is valid and missing or negative latency is rejected', () {
    expect(assess(latency: 0).usableTransportSample, isTrue);
    expect(assess(latency: 0).latencyMs, 0);
    expectDenied(assess(latency: null), 'invalid_latency');
    expectDenied(assess(latency: -1), 'invalid_latency');
  });

  test(
    'unknown provider, absent response and transport errors fail closed',
    () {
      expectDenied(assess(provider: 'unknown'), 'unknown_provider');
      expectDenied(assess(provider: 'ChatGPT'), 'unknown_provider');
      expectDenied(assess(status: 0), 'no_response');
      expectDenied(
        assess(error: 'timeout with sensitive details'),
        'transport_error',
      );
      expectDenied(assess(error: ' '), 'transport_error');
      for (final status in [-1, 100, 400, 418, 600]) {
        expectDenied(assess(status: status), 'unexpected_status');
      }
    },
  );

  test('HTTP failures remain unhealthy even with a positive RTT', () {
    const failures = {
      301: 'redirect',
      302: 'redirect',
      307: 'redirect',
      308: 'redirect',
      399: 'redirect',
      401: 'auth_required',
      403: 'blocked_or_forbidden',
      404: 'endpoint_unknown',
      429: 'rate_limited',
      500: 'upstream_error',
      502: 'upstream_error',
      503: 'upstream_error',
      599: 'upstream_error',
    };
    for (final provider in routingProviderProbeUrls.keys) {
      for (final entry in failures.entries) {
        expectDenied(
          assess(provider: provider, status: entry.key, latency: 25),
          entry.value,
        );
      }
    }
  });

  test('API root authentication and missing endpoints are not readiness', () {
    for (final provider in ['openai_api', 'gemini_api']) {
      expectDenied(assess(provider: provider, status: 401), 'auth_required');
      expectDenied(assess(provider: provider, status: 404), 'endpoint_unknown');
    }
  });

  test('HTTP 200 challenge pages cannot supply a usable sample', () {
    for (final marker in [
      '<script src="/cdn-cgi/challenge-platform/test"></script>',
      '<div id="CF-CHL-widget">test</div>',
      '<title>Just a moment...</title>',
      'justamoment',
      'Verify human',
      'verifyhuman',
      'Verify you are human',
      "Verify you're human",
      'Verify that you are human',
      'Just a\n moment',
    ]) {
      expectDenied(assess(body: marker), 'challenge');
    }
  });

  test('top-level JSON error is rejected without retaining its payload', () {
    for (final body in [
      '{"error":{"message":"private payload"}}',
      '{"error":"blocked"}',
      '{"error":null}',
      '{"error":false}',
    ]) {
      expectDenied(assess(body: body), 'response_error');
    }
    for (final body in [
      '<html>Welcome</html>',
      '{"ok":true}',
      '{"data":{"error":null}}',
      '[{"error":"nested"}]',
      'invalid json',
      '',
    ]) {
      expect(assess(body: body).usableTransportSample, isTrue);
    }
  });

  test(
    'documented anonymous API auth responses can measure transport without credentials',
    () {
      for (final input in [
        (
          'openai_api',
          '{"error":{"type":"invalid_request_error","message":"Missing bearer authentication"}}',
        ),
        ('gemini_api', '{"error":{"code":401,"status":"UNAUTHENTICATED"}}'),
      ]) {
        final result = assess(provider: input.$1, status: 401, body: input.$2);
        expect(result.usableTransportSample, isTrue);
        expect(result.reason, 'expected_anonymous_auth');
        expect(result.probeBlocked, isFalse);
        expect(result.transportFailure, isFalse);
      }
    },
  );
  test(
    'unknown auth, permission, endpoint and quota responses do not punish a node',
    () {
      for (final result in [
        assess(status: 401),
        assess(status: 404),
        assess(status: 302),
        assess(status: 429),
        assess(status: 429, error: 'timeout after response'),
        assess(status: 503),
        assess(
          provider: 'gemini_api',
          status: 403,
          body: '{"error":{"code":403,"status":"PERMISSION_DENIED"}}',
        ),
      ]) {
        expect(result.usableTransportSample, isFalse);
        expect(result.probeBlocked, isFalse);
        expect(result.transportFailure, isFalse);
      }
      for (final blocked in [
        assess(status: 403, body: '<html>edge blocked</html>'),
        assess(status: 200, body: '<title>Just a moment...</title>'),
      ]) {
        expect(blocked.probeBlocked, isTrue);
        expect(blocked.transportFailure, isFalse);
        expect(blocked.usableTransportSample, isFalse);
      }
    },
  );

  test('gstatic 204 supplies transport only and cannot qualify AI', () {
    final operator = assess(provider: 'operator', status: 204, latency: 0);
    expect(operator.usableTransportSample, isTrue);
    expect(operator.reason, 'public_http_transport');
    expect(operator.latencyMs, 0);
    for (final provider in routingAiProviders) {
      expectDenied(
        assess(provider: provider, status: 204),
        'unexpected_status',
      );
    }
  });
}
