import 'routing_http_health.dart';
import 'routing_manifest.dart';

final class RoutingProviderAssessment {
  const RoutingProviderAssessment({
    required this.usableTransportSample,
    required this.transportFailure,
    this.observedAt,
    this.validUntil,
    this.latencyMs,
  });

  final bool usableTransportSample;
  final bool transportFailure;
  final DateTime? observedAt;
  final DateTime? validUntil;
  final int? latencyMs;
}

final class RoutingProviderHealthStore {
  RoutingProviderHealthStore({this.lifetime = const Duration(seconds: 90)}) {
    if (lifetime <= Duration.zero) {
      throw ArgumentError.value(lifetime, 'lifetime', 'Must be positive');
    }
  }

  final Duration lifetime;
  final _nodes = <String, Map<String, Map<String, _ProviderState>>>{};
  int? _generation;

  void resetGeneration(int generation) {
    _generation = generation;
    _nodes.clear();
  }

  bool observe({
    required int generation,
    required String nodeId,
    required String provider,
    required int sequence,
    required DateTime observedAt,
    required RoutingHttpHealth health,
    String semantics = '',
  }) {
    if (generation != _generation ||
        sequence < 0 ||
        !_validScope(nodeId, semantics) ||
        !routingProviderProbeUrls.containsKey(provider)) {
      return false;
    }
    var policies = _nodes[nodeId];
    if (policies == null) {
      if (_nodes.length >= 4096) return false;
      policies = _nodes[nodeId] = {};
    }
    var providers = policies[semantics];
    if (providers == null) {
      if (policies.length >= 16) return false;
      providers = policies[semantics] = {};
    }
    final state = providers.putIfAbsent(provider, _ProviderState.new);
    if (sequence <= state.sequence) return false;
    // Retain dispatch order even when the newer result has an older clock time.
    state.sequence = sequence;
    if (state.watermark != null && observedAt.isBefore(state.watermark!)) {
      return false;
    }
    state.watermark = observedAt;
    if (health.probeBlocked) return true;
    if (health.transportFailure) {
      state.sampleAt = observedAt;
      state.failure = true;
      state.latencyMs = null;
    } else if (health.usableTransportSample &&
        health.latencyMs != null &&
        health.latencyMs! >= 0) {
      state.sampleAt = observedAt;
      state.failure = false;
      state.latencyMs = health.latencyMs;
    }
    return true;
  }

  RoutingProviderAssessment assess({
    required String nodeId,
    required Iterable<String> providers,
    required DateTime now,
    String semantics = '',
  }) {
    const unknown = RoutingProviderAssessment(
      usableTransportSample: false,
      transportFailure: false,
    );
    if (!_validScope(nodeId, semantics)) return unknown;
    final requested = <String>{};
    for (final provider in providers) {
      if (!routingProviderProbeUrls.containsKey(provider)) return unknown;
      requested.add(provider);
    }
    if (requested.isEmpty) return unknown;
    final states = _nodes[nodeId]?[semantics];
    var complete = true;
    DateTime? newest;
    DateTime? earliestExpiration;
    DateTime? failureAt;
    int? latency;
    for (final provider in requested) {
      final state = states?[provider];
      final at = state?.sampleAt;
      if (at == null || at.isAfter(now) || !now.isBefore(at.add(lifetime))) {
        complete = false;
        continue;
      }
      if (state!.failure) {
        if (failureAt == null || at.isAfter(failureAt)) failureAt = at;
        complete = false;
        continue;
      }
      final expiration = at.add(lifetime);
      if (newest == null || at.isAfter(newest)) newest = at;
      if (earliestExpiration == null ||
          expiration.isBefore(earliestExpiration)) {
        earliestExpiration = expiration;
      }
      final sampleLatency = state.latencyMs!;
      if (latency == null || sampleLatency > latency) latency = sampleLatency;
    }
    if (failureAt != null) {
      return RoutingProviderAssessment(
        usableTransportSample: false,
        transportFailure: true,
        observedAt: failureAt,
        validUntil: failureAt.add(lifetime),
      );
    }
    if (!complete) return unknown;
    return RoutingProviderAssessment(
      usableTransportSample: true,
      transportFailure: false,
      observedAt: newest,
      validUntil: earliestExpiration,
      latencyMs: latency,
    );
  }

  bool _validScope(String nodeId, String semantics) =>
      nodeId.isNotEmpty && nodeId.length <= 128 && semantics.length <= 4096;
}

final class _ProviderState {
  int sequence = -1;
  DateTime? watermark;
  DateTime? sampleAt;
  bool failure = false;
  int? latencyMs;
}
