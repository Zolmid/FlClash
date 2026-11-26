import 'dart:async';

import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/models/models.dart' show ProxyState;
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';

class _FakeProxy implements Proxy {
  @override
  List<String> get restoreFailures => const [];
  final List<String> calls = [];
  Future<bool>? held;
  Error? failure;

  Future<bool> _call(String name) async {
    calls.add(name);
    final error = failure;
    failure = null;
    if (error != null) {
      throw error;
    }
    final result = held ?? Future.value(true);
    held = null;
    return result;
  }

  @override
  Future<bool> startProxy(int port, [List<String> bypassDomain = const []]) {
    return _call('start $port');
  }

  @override
  Future<bool> stopProxy() => _call('stop');
}

ProxyState _state({required bool isStart}) {
  return ProxyState(
    isStart: isStart,
    systemProxy: true,
    bassDomain: const [],
    port: 7890,
  );
}

void main() {
  test('applies changes in the order they come', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);

    unawaited(queue.apply(_state(isStart: true)));
    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['start 7890', 'stop']);
  });

  test('close stops last and drops the starts queued before it', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);
    final inFlight = Completer<bool>();
    proxy.held = inFlight.future;

    unawaited(queue.apply(_state(isStart: false)));
    await pumpEventQueue();
    unawaited(queue.apply(_state(isStart: true)));
    final closed = queue.close();
    await pumpEventQueue();
    expect(proxy.calls, ['stop']);

    inFlight.complete(true);
    await closed;
    await queue.apply(_state(isStart: true));

    expect(proxy.calls, ['stop', 'stop']);
  });

  test('a failing call does not stall the queue', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);
    proxy.failure = StateError('channel gone');

    await queue.apply(_state(isStart: true));
    await queue.apply(_state(isStart: false));

    expect(proxy.calls, ['start 7890', 'stop']);
  });

  test(
    'reports both rejected and thrown starts without warning on stop',
    () async {
      final proxy = _FakeProxy();
      final queue = SystemProxyQueue(proxy);
      var failures = 0;
      void report() => failures++;

      proxy.held = Future.value(false);
      await queue.apply(_state(isStart: true), onStartFailed: report);
      proxy.failure = StateError('command interrupted');
      await queue.apply(_state(isStart: true), onStartFailed: report);
      proxy.held = Future.value(false);
      await queue.apply(_state(isStart: false), onStartFailed: report);

      expect(failures, 2);
      expect(proxy.calls, ['start 7890', 'start 7890', 'stop']);
    },
  );

  test('reports a failed restore and permits a retry', () async {
    final proxy = _FakeProxy();
    final queue = SystemProxyQueue(proxy);
    var failures = 0;
    proxy.held = Future.value(false);
    await queue.apply(_state(isStart: false), onStopFailed: () => failures++);
    await queue.apply(_state(isStart: false), onStopFailed: () => failures++);
    expect(failures, 1);
    expect(proxy.calls, ['stop', 'stop']);
  });
}
