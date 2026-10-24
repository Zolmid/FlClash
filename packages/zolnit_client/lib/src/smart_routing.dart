import 'dart:collection';
import 'dart:math' as math;

import 'routing_regions.dart';

class SmartRouteNode {
  const SmartRouteNode({
    required this.id,
    required this.proxyName,
    required this.countryCode,
    required this.failureDomain,
    required this.services,
    this.enabled = true,
    this.verified = false,
    this.revision = '',
  });

  final String id;
  final String proxyName;
  final String? countryCode;
  final String failureDomain;
  final Set<String> services;
  final bool enabled;
  final bool verified;
  final String revision;

  Object get identity => (
    proxyName,
    countryCode,
    failureDomain,
    revision,
    enabled,
    verified,
    (services.toList()..sort()).join(','),
  );
}

class SmartRouteService {
  const SmartRouteService({
    required this.id,
    required this.groupName,
    required this.allowedCountries,
    this.isAi = false,
  });

  final String id;
  final String groupName;
  final Set<String> allowedCountries;
  final bool isAi;

  Object get identity =>
      (groupName, isAi, (allowedCountries.toList()..sort()).join(','));
}

class SmartProbeSample {
  const SmartProbeSample({
    required this.at,
    required this.success,
    this.latencyMs,
    this.packetLoss,
    this.hardFailure = false,
  });

  final DateTime at;
  final bool success;
  final double? latencyMs;
  final double? packetLoss;
  final bool hardFailure;
}

class SmartRouteDecision {
  const SmartRouteDecision(this.nodeId, this.reason, {this.manual = false});

  final String? nodeId;
  final String reason;
  final bool manual;
}

class SmartRoutingTuning {
  const SmartRoutingTuning({
    this.minimumHold = const Duration(seconds: 60),
    this.sampleLifetime = const Duration(seconds: 90),
    this.baseCooldown = const Duration(seconds: 15),
    this.maximumCooldown = const Duration(minutes: 5),
    this.failureConfirmation = 2,
    this.recoveryConfirmation = 2,
    this.improvementConfirmation = 2,
    this.minimumGainMs = 20,
    this.minimumGainRatio = 0.2,
    this.smoothing = 0.25,
    this.windowSize = 20,
  });

  final Duration minimumHold;
  final Duration sampleLifetime;
  final Duration baseCooldown;
  final Duration maximumCooldown;
  final int failureConfirmation;
  final int recoveryConfirmation;
  final int improvementConfirmation;
  final double minimumGainMs;
  final double minimumGainRatio;
  final double smoothing;
  final int windowSize;
}

class SmartRouteMetrics {
  const SmartRouteMetrics({
    required this.observations,
    required this.successRate,
    required this.consecutiveFailures,
    required this.smoothedLatencyMs,
    required this.packetLoss,
    required this.lastObserved,
    required this.cooldownUntil,
  });

  final int observations;
  final double? successRate;
  final int consecutiveFailures;
  final double? smoothedLatencyMs;
  final double? packetLoss;
  final DateTime? lastObserved;
  final DateTime? cooldownUntil;
}

class _Health {
  final samples = Queue<bool>();
  DateTime? at;
  DateTime? cooldownUntil;
  double? latency;
  double? packetLoss;
  int failures = 0;
  int recovered = 0;
  int outages = 0;
  bool recovering = false;

  double? get successRate => samples.isEmpty
      ? null
      : samples.where((value) => value).length / samples.length;
  double get score =>
      (latency ?? double.infinity) +
      (1 - (successRate ?? 1)) * 2000 +
      (packetLoss ?? 0) * 2000;
}

class _ServiceState {
  String? confirmed;
  DateTime? switchedAt;
  String? challenger;
  int improvements = 0;
  DateTime? examinedAt;
  bool manual = false;
  String? manualNode;
  String? manualProxy;
}

class SmartRoutingEngine {
  SmartRoutingEngine({this.tuning = const SmartRoutingTuning()});

  final SmartRoutingTuning tuning;
  final _nodes = <String, SmartRouteNode>{};
  final _services = <String, SmartRouteService>{};
  final _candidates = <String, List<SmartRouteNode>>{};
  final _health = <(String, String), _Health>{};
  final _states = <String, _ServiceState>{};
  final _domainCooldowns = <(String, String), DateTime>{};
  int? _generation;

  static const _builtins = {
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
  };

  void resetGeneration(int generation) {
    if (_generation == generation) return;
    _generation = generation;
    _health.clear();
    _domainCooldowns.clear();
    _states
      ..clear()
      ..addAll({for (final id in _services.keys) id: _ServiceState()});
  }

  void configure({
    required int generation,
    required List<SmartRouteNode> nodes,
    required List<SmartRouteService> services,
  }) {
    if (_generation != generation) {
      _health.clear();
      _states.clear();
      _domainCooldowns.clear();
      _nodes.clear();
      _services.clear();
      _generation = generation;
    }
    if (nodes.map((node) => node.id).toSet().length != nodes.length ||
        services.map((service) => service.id).toSet().length !=
            services.length) {
      throw ArgumentError('Routing identities must be unique');
    }
    final nextNodes = {for (final node in nodes) node.id: node};
    final nextServices = {for (final service in services) service.id: service};
    _health.removeWhere(
      (key, _) =>
          nextNodes[key.$2]?.identity != _nodes[key.$2]?.identity ||
          nextServices[key.$1]?.identity != _services[key.$1]?.identity,
    );
    _states.removeWhere((id, _) => !nextServices.containsKey(id));
    for (final service in services) {
      final state = _states[service.id];
      if (state != null &&
          service.identity != _services[service.id]?.identity) {
        state.confirmed = null;
        state.switchedAt = null;
        state.challenger = null;
        state.improvements = 0;
        state.examinedAt = null;
      }
    }
    final domains = nextNodes.values.map((n) => n.failureDomain).toSet();
    _domainCooldowns.removeWhere(
      (key, _) =>
          !nextServices.containsKey(key.$1) || !domains.contains(key.$2),
    );
    _nodes
      ..clear()
      ..addAll(nextNodes);
    _services
      ..clear()
      ..addAll(nextServices);
    for (final service in services) {
      _states.putIfAbsent(service.id, _ServiceState.new);
    }
    _candidates
      ..clear()
      ..addAll({
        for (final service in services)
          service.id: List.unmodifiable([
            for (final node in nodes)
              if (eligible(service.id, node.id)) node,
          ]),
      });
  }

  bool eligible(String serviceId, String nodeId) {
    final node = _nodes[nodeId];
    final service = _services[serviceId];
    if (node == null ||
        service == null ||
        !node.enabled ||
        !node.verified ||
        node.failureDomain.isEmpty ||
        node.countryCode == null ||
        !routingCountryCodes.contains(node.countryCode) ||
        _builtins.contains(node.proxyName.toUpperCase()) ||
        !node.services.contains(serviceId) ||
        !service.allowedCountries.contains(node.countryCode)) {
      return false;
    }
    return !service.isAi || node.countryCode != 'HK';
  }

  List<SmartRouteNode> candidates(String serviceId) =>
      _candidates[serviceId] ?? const [];

  DateTime? nextProbeAt(String serviceId, String nodeId) {
    final node = _nodes[nodeId];
    if (node == null) return null;
    final own = _health[(serviceId, nodeId)]?.cooldownUntil;
    final domain = _domainCooldowns[(serviceId, node.failureDomain)];
    if (own == null) return domain;
    if (domain == null) return own;
    return own.isAfter(domain) ? own : domain;
  }

  void observe({
    required String serviceId,
    required String nodeId,
    required SmartProbeSample sample,
    required int generation,
  }) {
    if (_generation != generation) return;
    if (!eligible(serviceId, nodeId)) return;
    final latency = sample.latencyMs;
    final loss = sample.packetLoss;
    if (sample.success &&
        (sample.hardFailure ||
            latency == null ||
            !latency.isFinite ||
            latency < 0)) {
      return;
    }
    if (loss != null && (!loss.isFinite || loss < 0 || loss > 1)) return;
    final health = _health.putIfAbsent((serviceId, nodeId), _Health.new);
    final domain = _domainCooldowns[(serviceId, _nodes[nodeId]!.failureDomain)];
    if (health.at == null && domain != null) {
      health.recovering = true;
      health.cooldownUntil = domain;
    }
    if (health.at != null && !sample.at.isAfter(health.at!)) return;
    health.at = sample.at;
    health.samples.add(sample.success);
    while (health.samples.length > tuning.windowSize) {
      health.samples.removeFirst();
    }
    if (loss != null) {
      health.packetLoss = _smooth(health.packetLoss, loss);
    }
    if (sample.success) {
      health.latency = _smooth(health.latency, latency!);
      health.failures = 0;
      if (!(health.cooldownUntil?.isAfter(sample.at) ?? false)) {
        health.recovered++;
      }
      if (health.recovering &&
          health.recovered >= tuning.recoveryConfirmation &&
          !(health.cooldownUntil?.isAfter(sample.at) ?? false)) {
        health.recovering = false;
        health.cooldownUntil = null;
        health.outages = 0;
      }
    } else {
      health.failures++;
      health.recovered = 0;
      if (sample.hardFailure || health.failures >= tuning.failureConfirmation) {
        health.recovering = true;
        final factor = math.pow(2, math.min(health.outages++, 5)).toInt();
        final cooldown = Duration(
          milliseconds: math.min(
            tuning.baseCooldown.inMilliseconds * factor,
            tuning.maximumCooldown.inMilliseconds,
          ),
        );
        health.cooldownUntil = sample.at.add(cooldown);
        if (sample.hardFailure) {
          final domain = _nodes[nodeId]!.failureDomain;
          _domainCooldowns[(serviceId, domain)] = health.cooldownUntil!;
          for (final sibling in _nodes.values.where(
            (node) => node.failureDomain == domain,
          )) {
            final related = _health.putIfAbsent((
              serviceId,
              sibling.id,
            ), _Health.new);
            related.recovering = true;
            related.recovered = 0;
            related.cooldownUntil = health.cooldownUntil;
          }
        }
      }
    }
  }

  double _smooth(double? previous, double sample) => previous == null
      ? sample
      : previous + tuning.smoothing * (sample - previous);

  SmartRouteMetrics? metrics(String serviceId, String nodeId) {
    final health = _health[(serviceId, nodeId)];
    if (health == null) return null;
    return SmartRouteMetrics(
      observations: health.samples.length,
      successRate: health.successRate,
      consecutiveFailures: health.failures,
      smoothedLatencyMs: health.latency,
      packetLoss: health.packetLoss,
      lastObserved: health.at,
      cooldownUntil: nextProbeAt(serviceId, nodeId),
    );
  }

  bool _healthy(String serviceId, SmartRouteNode node, DateTime now) {
    final health = _health[(serviceId, node.id)];
    return health != null &&
        health.latency != null &&
        !health.recovering &&
        health.failures < tuning.failureConfirmation &&
        !(nextProbeAt(serviceId, node.id)?.isAfter(now) ?? false) &&
        health.at != null &&
        !health.at!.isAfter(now) &&
        now.difference(health.at!) <= tuning.sampleLifetime;
  }

  SmartRouteDecision decide({
    required String serviceId,
    required DateTime now,
  }) {
    final state = _states[serviceId];
    if (state == null) return const SmartRouteDecision(null, 'unconfigured');
    if (state.manual) {
      final node = state.manualNode;
      return SmartRouteDecision(
        node == 'DIRECT' ||
                (_nodes[node]?.enabled == true &&
                    _nodes[node]?.proxyName == state.manualProxy)
            ? node
            : null,
        'manual',
        manual: true,
      );
    }
    final eligibleNodes = candidates(serviceId);
    if (eligibleNodes.isEmpty) {
      return const SmartRouteDecision(null, 'no_eligible');
    }
    final healthy =
        eligibleNodes.where((node) => _healthy(serviceId, node, now)).toList()
          ..sort((a, b) {
            final score = _health[(serviceId, a.id)]!.score.compareTo(
              _health[(serviceId, b.id)]!.score,
            );
            return score == 0 ? a.id.compareTo(b.id) : score;
          });
    if (healthy.isEmpty) {
      final unmeasured = eligibleNodes.any(
        (node) => _health[(serviceId, node.id)] == null,
      );
      return SmartRouteDecision(
        null,
        unmeasured ? 'awaiting_probe' : 'no_healthy',
      );
    }
    final best = healthy.first.id;
    final current = state.confirmed;
    final currentNode = _nodes[current];
    if (currentNode == null ||
        !eligible(serviceId, currentNode.id) ||
        !_healthy(serviceId, currentNode, now)) {
      return SmartRouteDecision(best, current == null ? 'initial' : 'failover');
    }
    if (best == current) {
      state.challenger = null;
      state.improvements = 0;
      return SmartRouteDecision(current, 'stable');
    }
    if (_health[(serviceId, current)]!.failures > 0) {
      return SmartRouteDecision(current, 'confirming_failure');
    }
    if (state.switchedAt != null &&
        now.difference(state.switchedAt!) < tuning.minimumHold) {
      return SmartRouteDecision(current, 'minimum_hold');
    }
    final currentScore = _health[(serviceId, current)]!.score;
    final gain = currentScore - _health[(serviceId, best)]!.score;
    if (gain < tuning.minimumGainMs ||
        gain < currentScore * tuning.minimumGainRatio) {
      state.challenger = null;
      state.improvements = 0;
      return SmartRouteDecision(current, 'hysteresis');
    }
    final challengerAt = _health[(serviceId, best)]!.at;
    if (state.challenger != best || state.examinedAt != challengerAt) {
      state.improvements = state.challenger == best
          ? state.improvements + 1
          : 1;
      state.challenger = best;
      state.examinedAt = challengerAt;
    }
    return state.improvements >= tuning.improvementConfirmation
        ? SmartRouteDecision(best, 'improved')
        : SmartRouteDecision(current, 'confirming_improvement');
  }

  void confirm({
    required String serviceId,
    required String? nodeId,
    required DateTime now,
    required int generation,
  }) {
    if (_generation != generation) return;
    final state = _states[serviceId];
    if (state == null || state.confirmed == nodeId) return;
    state.confirmed = nodeId;
    state.switchedAt = now;
    state.challenger = null;
    state.improvements = 0;
  }

  void setManual({required String serviceId, required String? nodeId}) {
    final state = _states[serviceId];
    if (state == null) return;
    state.manual = true;
    state.manualNode = nodeId;
    state.manualProxy = _nodes[nodeId]?.proxyName;
  }

  void resumeAutomatic(String serviceId) {
    final state = _states[serviceId];
    if (state == null) return;
    state.manual = false;
    state.manualNode = null;
    state.manualProxy = null;
    state.challenger = null;
    state.improvements = 0;
    state.examinedAt = null;
    state.confirmed = null;
    state.switchedAt = null;
  }
}
