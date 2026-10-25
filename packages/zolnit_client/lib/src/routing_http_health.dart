import 'dart:convert';

import 'routing_manifest.dart';

/// A public HTTP transport observation, never product qualification.
final class RoutingHttpHealth {
  const RoutingHttpHealth({
    required this.usableTransportSample,
    required this.reason,
    required this.latencyMs,
    this.probeBlocked = false,
    this.transportFailure = false,
  });

  final bool usableTransportSample;
  final String reason;
  final int? latencyMs;
  final bool probeBlocked;
  final bool transportFailure;
}

RoutingHttpHealth assessRoutingHttpHealth({
  required String provider,
  required int statusCode,
  required int? latencyMs,
  String error = '',
  String body = '',
}) {
  RoutingHttpHealth deny(
    String reason, {
    bool blocked = false,
    bool failed = false,
  }) => RoutingHttpHealth(
    usableTransportSample: false,
    reason: reason,
    latencyMs: null,
    probeBlocked: blocked,
    transportFailure: failed,
  );

  if (!routingProviderProbeUrls.containsKey(provider)) {
    return deny('unknown_provider');
  }
  if (statusCode == 429) return deny('rate_limited');
  if (error.isNotEmpty) return deny('transport_error', failed: true);
  final isApi = provider == 'openai_api' || provider == 'gemini_api';
  Map? apiError;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      apiError = decoded['error'] as Map;
    }
  } on FormatException {
    apiError = null;
  }
  if (statusCode == 0) return deny('no_response');
  if (statusCode == 401) {
    final expected =
        isApi &&
        apiError != null &&
        latencyMs != null &&
        latencyMs >= 0 &&
        (provider == 'openai_api'
            ? apiError['type'] is String &&
                  (apiError['type'] as String).isNotEmpty
            : apiError['status'] == 'UNAUTHENTICATED' &&
                  apiError['code'] == 401);
    if (expected) {
      return RoutingHttpHealth(
        usableTransportSample: true,
        reason: 'expected_anonymous_auth',
        latencyMs: latencyMs,
      );
    }
    return deny('auth_required');
  }
  if (statusCode == 403) {
    if (isApi && apiError != null) return deny('qualification_unknown');
    return deny('blocked_or_forbidden', blocked: true);
  }
  if (statusCode >= 300 && statusCode < 400) return deny('redirect');
  if (statusCode == 404) return deny('endpoint_unknown');
  if (statusCode >= 500 && statusCode < 600) return deny('upstream_error');
  if (statusCode != (provider == 'operator' ? 204 : 200)) {
    return deny('unexpected_status');
  }
  if (latencyMs == null || latencyMs < 0) return deny('invalid_latency');
  if (statusCode == 200) {
    final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (const [
      'cf-chl',
      'challenge-platform',
      'justamoment',
      'verifyhuman',
      'verifyyouarehuman',
      "verifyyou'rehuman",
      'verifythatyouarehuman',
    ].any(normalized.contains)) {
      return deny('challenge', blocked: true);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded.containsKey('error')) {
        return deny('response_error');
      }
    } on FormatException {
      // Public web probes may return HTML rather than JSON.
    }
  }
  return RoutingHttpHealth(
    usableTransportSample: true,
    reason: 'public_http_transport',
    latencyMs: latencyMs,
  );
}
