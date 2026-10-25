import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'routing_http_health.dart';
import 'routing_manifest.dart';

final class RoutingProbeReply {
  const RoutingProbeReply({
    required this.statusCode,
    required this.latencyMs,
    this.body = '',
    this.error = '',
    this.retryAfter = '',
  });
  final int statusCode;
  final int? latencyMs;
  final String body;
  final String error;
  final String retryAfter;
}

final class RoutingProbeObservation {
  const RoutingProbeObservation(
    this.reply,
    this.health,
    this.sequence,
    this.observedAt,
  );
  final RoutingProbeReply reply;
  final RoutingHttpHealth health;
  final int sequence;
  final DateTime observedAt;
}

typedef _Key = (Object, String, String, String);

final class _Job {
  _Job(this.key, this.origin, this.provider, this.send, this.current);
  final _Key key;
  final String origin;
  final String provider;
  final Future<RoutingProbeReply?> Function() send;
  final bool Function() current;
  final done = Completer<RoutingProbeObservation?>();
}

final class _Origin {
  Duration until = Duration.zero;
  int failures = 0;
}

final class RoutingProbeScheduler {
  RoutingProbeScheduler({
    Duration Function()? elapsed,
    DateTime Function()? wallClock,
    this.maximumRequests = 30,
    this.maximumConcurrent = 2,
    this.activeInterval = const Duration(seconds: 30),
    this.idleInterval = const Duration(seconds: 60),
    this.cacheLifetime = const Duration(seconds: 30),
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter,
       _wallClock = wallClock ?? DateTime.now {
    if (maximumRequests < 1 ||
        maximumConcurrent < 1 ||
        activeInterval.isNegative ||
        idleInterval.isNegative ||
        cacheLifetime.isNegative) {
      throw ArgumentError('invalid probe limits');
    }
  }
  final Duration Function() _elapsed;
  final DateTime Function() _wallClock;
  final int maximumRequests;
  final int maximumConcurrent;
  final Duration activeInterval;
  final Duration idleInterval;
  final Duration cacheLifetime;
  final _starts = ListQueue<Duration>();
  final _pending = <_Job>[];
  final _flights = <_Key, Future<RoutingProbeObservation?>>{};
  final _cache = <_Key, (Duration, RoutingProbeObservation)>{};
  final _origins = <String, _Origin>{};
  final _runningOrigins = <String>{};
  Duration _lastTime = Duration.zero;
  Duration _nextCycle = Duration.zero;
  int _sequence = 0;
  int _running = 0;
  int _failedCycles = 0;
  bool _disposed = false;
  bool _draining = false;

  Duration get _now {
    final value = _elapsed();
    if (value > _lastTime) _lastTime = value;
    return _lastTime;
  }

  int get requestsInWindow {
    _prune(_now);
    return _starts.length;
  }

  int get activeRequests => _running;
  void _prune(Duration now) {
    while (_starts.isNotEmpty &&
        now - _starts.first >= const Duration(minutes: 1)) {
      _starts.removeFirst();
    }
    _cache.removeWhere((_, entry) => now - entry.$1 >= cacheLifetime);
  }

  bool beginCycle({required bool activeDemand}) {
    final now = _now;
    if (_disposed || now < _nextCycle) return false;
    _nextCycle = now + (activeDemand ? activeInterval : idleInterval);
    return true;
  }

  void finishCycle({
    required bool usableObservation,
    bool attemptedObservation = true,
  }) {
    if (!attemptedObservation) return;
    if (usableObservation) {
      _failedCycles = 0;
    } else {
      final seconds = math.min(300, 30 * (1 << math.min(_failedCycles++, 4)));
      final next = _now + Duration(seconds: seconds);
      if (next > _nextCycle) _nextCycle = next;
    }
  }

  Future<RoutingProbeObservation?> request({
    required Object scope,
    required String nodeId,
    required String provider,
    required String semantics,
    required Future<RoutingProbeReply?> Function() send,
    required bool Function() isCurrent,
  }) {
    final url = routingProviderProbeUrls[provider];
    if (_disposed || !isCurrent() || nodeId.isEmpty || url == null) {
      return Future.value();
    }
    final origin = Uri.parse(url).origin;
    final now = _now;
    _prune(now);
    if (now < (_origins[origin]?.until ?? Duration.zero)) return Future.value();
    final key = (scope, nodeId, url, semantics);
    final active = _flights[key];
    if (active != null) return active;
    final cached = _cache[key];
    if (cached != null) return Future.value(cached.$2);
    if (_pending.length >= maximumRequests) return Future.value();
    final job = _Job(key, origin, provider, send, isCurrent);
    _pending.add(job);
    _flights[key] = job.done.future;
    _drain();
    return job.done.future;
  }

  void _finish(_Job job, RoutingProbeObservation? value) {
    _flights.remove(job.key);
    if (!job.done.isCompleted) job.done.complete(value);
  }

  void _drain() {
    if (_draining) return;
    _draining = true;
    try {
      for (var index = 0; index < _pending.length;) {
        final job = _pending[index];
        final now = _now;
        _prune(now);
        if (_disposed ||
            !job.current() ||
            _starts.length >= maximumRequests ||
            now < (_origins[job.origin]?.until ?? Duration.zero)) {
          _pending.removeAt(index);
          _finish(job, null);
          continue;
        }
        if (_running >= maximumConcurrent ||
            _runningOrigins.contains(job.origin)) {
          index++;
          continue;
        }
        _pending.removeAt(index);
        _starts.add(now);
        _running++;
        _runningOrigins.add(job.origin);
        final sequence = ++_sequence;
        unawaited(_perform(job, sequence));
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _perform(_Job job, int sequence) async {
    RoutingProbeObservation? observation;
    try {
      final reply = await job.send();
      final origin = _origins.putIfAbsent(job.origin, _Origin.new);
      if (reply != null) {
        final health = assessRoutingHttpHealth(
          provider: job.provider,
          statusCode: reply.statusCode,
          latencyMs: reply.latencyMs,
          error: reply.error,
          body: reply.body,
        );
        observation = RoutingProbeObservation(
          reply,
          health,
          sequence,
          _wallClock(),
        );
        if (reply.statusCode == 429) {
          origin.failures++;
          final delay =
              retryDelay(reply.retryAfter, _wallClock()) ??
              Duration(
                seconds: math.min(
                  300,
                  60 * (1 << math.min(origin.failures - 1, 3)),
                ),
              );
          final until = _now + delay;
          if (until > origin.until) origin.until = until;
        } else if (health.usableTransportSample) {
          origin.failures = 0;
        } else if (++origin.failures >= 2) {
          final delay = Duration(
            seconds: math.min(
              300,
              30 * (1 << math.min(origin.failures - 2, 4)),
            ),
          );
          final until = _now + delay;
          if (until > origin.until) origin.until = until;
        }
        if (!_disposed && job.current()) {
          _cache[job.key] = (_now, observation);
          while (_cache.length > 64) {
            _cache.remove(_cache.keys.first);
          }
        }
      }
    } catch (_) {
      observation = null;
    } finally {
      _running--;
      _runningOrigins.remove(job.origin);
      _finish(job, !_disposed && job.current() ? observation : null);
      _drain();
    }
  }

  static Duration? retryDelay(String header, DateTime wallNow) {
    final value = header.trim();
    if (value.isEmpty || value.length > 128) return null;
    final maximum = DateTime.utc(9999, 12, 31).difference(wallNow);
    Duration delay;
    if (RegExp(r'^[0-9]+$').hasMatch(value)) {
      final seconds = BigInt.parse(value);
      delay = seconds > BigInt.from(maximum.inSeconds)
          ? maximum
          : Duration(seconds: seconds.toInt());
    } else {
      try {
        delay = HttpDate.parse(value).difference(wallNow);
      } on HttpException {
        return null;
      } on FormatException {
        return null;
      }
    }
    return delay < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : delay;
  }

  void dispose() {
    _disposed = true;
    for (final job in _pending) {
      _finish(job, null);
    }
    _pending.clear();
    _cache.clear();
  }
}

extension on Stopwatch {
  Duration Function() get elapsedGetter =>
      () => elapsed;
}
