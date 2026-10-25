import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/routing_probe_scheduler.dart';

const ok = RoutingProbeReply(statusCode: 200, latencyMs: 10);

void main() {
  test(
    'all scopes share a rolling hard budget and bounded origin concurrency',
    () async {
      var elapsed = Duration.zero;
      var wall = DateTime.utc(2026);
      final scheduler = RoutingProbeScheduler(
        elapsed: () => elapsed,
        wallClock: () => wall,
      );
      final pending = <Completer<RoutingProbeReply?>>[];
      var running = 0;
      var peak = 0;
      var calls = 0;
      final byOrigin = <String, int>{};
      final futures = <Future<RoutingProbeObservation?>>[];
      for (var i = 0; i < 80; i++) {
        final provider = i.isEven ? 'chatgpt' : 'claude';
        futures.add(
          scheduler.request(
            scope: Object(),
            nodeId: 'node-$i',
            provider: provider,
            semantics: 'same-policy',
            isCurrent: () => true,
            send: () {
              calls++;
              running++;
              if (running > peak) peak = running;
              byOrigin[provider] = (byOrigin[provider] ?? 0) + 1;
              expect(byOrigin[provider], 1);
              final complete = Completer<RoutingProbeReply?>();
              pending.add(complete);
              return complete.future.whenComplete(() {
                running--;
                byOrigin[provider] = byOrigin[provider]! - 1;
              });
            },
          ),
        );
      }
      expect(scheduler.activeRequests, 2);
      for (var i = 0; i < pending.length; i++) {
        pending[i].complete(ok);
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(futures);
      expect(calls, 30);
      expect(peak, 2);
      expect(scheduler.requestsInWindow, 30);
      wall = wall.add(const Duration(days: 1));
      expect(
        await scheduler.request(
          scope: Object(),
          nodeId: 'extra',
          provider: 'chatgpt',
          semantics: 'different-policy',
          isCurrent: () => true,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNull,
      );
      expect(calls, 30);
      elapsed = const Duration(minutes: 1);
      expect(
        await scheduler.request(
          scope: Object(),
          nodeId: 'next',
          provider: 'chatgpt',
          semantics: 'policy',
          isCurrent: () => true,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNotNull,
      );
      expect(calls, 31);
      expect(scheduler.requestsInWindow, 1);
    },
  );

  test(
    'sharing requires same outbound scope URL and policy; cached time is original',
    () async {
      var elapsed = Duration.zero;
      var wall = DateTime.utc(2026);
      final scheduler = RoutingProbeScheduler(
        elapsed: () => elapsed,
        wallClock: () => wall,
      );
      final scope = Object();
      final first = Completer<RoutingProbeReply?>();
      var calls = 0;
      Future<RoutingProbeObservation?> request(String node, String policy) =>
          scheduler.request(
            scope: scope,
            nodeId: node,
            provider: 'chatgpt',
            semantics: policy,
            isCurrent: () => true,
            send: () {
              calls++;
              return calls == 1 ? first.future : Future.value(ok);
            },
          );
      final a = request('a', 'policy');
      final shared = request('a', 'policy');
      final otherNode = request('b', 'policy');
      final otherPolicy = request('a', 'different');
      expect(calls, 1);
      first.complete(ok);
      final observations = await Future.wait([
        a,
        shared,
        otherNode,
        otherPolicy,
      ]);
      expect(calls, 3);
      expect(observations[0]!.sequence, observations[1]!.sequence);
      expect(observations[0]!.sequence, isNot(observations[2]!.sequence));
      expect(observations[0]!.sequence, isNot(observations[3]!.sequence));
      final observedAt = observations.first!.observedAt;
      wall = wall.add(const Duration(seconds: 20));
      elapsed = const Duration(seconds: 20);
      expect((await request('a', 'policy'))!.observedAt, observedAt);
      expect(calls, 3);
      expect(
        await scheduler.request(
          scope: scope,
          nodeId: 'cancelled',
          provider: 'claude',
          semantics: 'policy',
          isCurrent: () => false,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNull,
      );
      expect(calls, 3);
    },
  );

  test(
    '429 closes the origin across nodes policies and scopes including cancelled replies',
    () async {
      var elapsed = Duration.zero;
      final wall = DateTime.utc(2026);
      final scheduler = RoutingProbeScheduler(
        elapsed: () => elapsed,
        wallClock: () => wall,
      );
      final response = Completer<RoutingProbeReply?>();
      var current = true;
      var calls = 0;
      final first = scheduler.request(
        scope: Object(),
        nodeId: 'a',
        provider: 'chatgpt',
        semantics: 'a',
        isCurrent: () => current,
        send: () {
          calls++;
          return response.future;
        },
      );
      final queued = scheduler.request(
        scope: Object(),
        nodeId: 'b',
        provider: 'chatgpt',
        semantics: 'b',
        isCurrent: () => true,
        send: () async {
          calls++;
          return ok;
        },
      );
      current = false;
      response.complete(
        const RoutingProbeReply(
          statusCode: 429,
          latencyMs: 5,
          retryAfter: '120',
        ),
      );
      expect(await first, isNull);
      expect(await queued, isNull);
      expect(calls, 1);
      expect(
        await scheduler.request(
          scope: Object(),
          nodeId: 'c',
          provider: 'claude',
          semantics: 'c',
          isCurrent: () => true,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNotNull,
      );
      elapsed = const Duration(seconds: 119);
      expect(
        await scheduler.request(
          scope: Object(),
          nodeId: 'd',
          provider: 'chatgpt',
          semantics: 'new',
          isCurrent: () => true,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNull,
      );
      expect(calls, 2);
      elapsed = const Duration(seconds: 120);
      expect(
        await scheduler.request(
          scope: Object(),
          nodeId: 'e',
          provider: 'chatgpt',
          semantics: 'new',
          isCurrent: () => true,
          send: () async {
            calls++;
            return ok;
          },
        ),
        isNotNull,
      );
      expect(calls, 3);
      expect(
        RoutingProbeScheduler.retryDelay(
          HttpDate.format(wall.add(const Duration(minutes: 3))),
          wall,
        ),
        const Duration(minutes: 3),
      );
      expect(RoutingProbeScheduler.retryDelay('invalid', wall), isNull);
      expect(
        RoutingProbeScheduler.retryDelay('0', wall),
        const Duration(seconds: 30),
      );
      expect(
        RoutingProbeScheduler.retryDelay(
          '9999999999999999999999999',
          wall,
        )!.inDays,
        greaterThan(365),
      );
    },
  );

  test(
    'cycle admission shares activation cadence and backs off idle or persistent failures',
    () {
      var elapsed = Duration.zero;
      final scheduler = RoutingProbeScheduler(elapsed: () => elapsed);
      expect(scheduler.beginCycle(activeDemand: false), isTrue);
      expect(scheduler.beginCycle(activeDemand: true), isFalse);
      elapsed = const Duration(seconds: 59);
      expect(scheduler.beginCycle(activeDemand: true), isFalse);
      elapsed = const Duration(seconds: 60);
      expect(scheduler.beginCycle(activeDemand: true), isTrue);
      scheduler.finishCycle(usableObservation: false);
      elapsed = const Duration(seconds: 90);
      expect(scheduler.beginCycle(activeDemand: true), isTrue);
      scheduler.finishCycle(usableObservation: false);
      elapsed = const Duration(seconds: 120);
      expect(scheduler.beginCycle(activeDemand: true), isFalse);
      elapsed = const Duration(seconds: 150);
      expect(scheduler.beginCycle(activeDemand: true), isTrue);
      final deferred = RoutingProbeScheduler(elapsed: () => elapsed);
      expect(deferred.beginCycle(activeDemand: true), isTrue);
      deferred.finishCycle(
        usableObservation: false,
        attemptedObservation: false,
      );
      elapsed = const Duration(seconds: 180);
      expect(deferred.beginCycle(activeDemand: true), isTrue);
      deferred.finishCycle(
        usableObservation: false,
        attemptedObservation: false,
      );
      elapsed = const Duration(seconds: 210);
      expect(deferred.beginCycle(activeDemand: true), isTrue);
    },
  );
}
