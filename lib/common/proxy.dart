import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' show ProxyState;
import 'package:proxy/proxy.dart';

final proxy = system.isDesktop && !safeModeBuild ? Proxy() : null;

final systemProxyQueue = proxy == null ? null : SystemProxyQueue(proxy!);

/// Exit's stop goes through the same queue as every other change, so a start
/// still waiting behind a slow call cannot turn the proxy back on after it.
class SystemProxyQueue {
  final Proxy _proxy;
  Future<void> _tail = Future.value();
  bool _closed = false;

  SystemProxyQueue(this._proxy);

  List<String> get restoreFailures => _proxy.restoreFailures;

  Future<void> apply(
    ProxyState state, {
    void Function()? onStartFailed,
    void Function()? onStopFailed,
  }) {
    return _enqueue(() async {
      if (_closed) {
        return;
      }
      final starting = state.isStart && state.systemProxy;
      final bool applied;
      try {
        applied = starting
            ? await _proxy.startProxy(state.port, state.bassDomain)
            : await _proxy.stopProxy();
      } catch (_) {
        if (starting && !_closed) onStartFailed?.call();
        if (!starting && !_closed) onStopFailed?.call();
        rethrow;
      }
      if (!applied) {
        commonPrint.log(
          'update system proxy failed',
          logLevel: LogLevel.warning,
        );
        if (starting && !_closed) onStartFailed?.call();
        if (!starting && !_closed) onStopFailed?.call();
      }
    });
  }

  Future<void> close() {
    _closed = true;
    return _enqueue(() async {
      await _proxy.stopProxy();
    });
  }

  Future<void> _enqueue(Future<void> Function() task) {
    return _tail = _tail.then((_) => task()).catchError((Object error) {
      commonPrint.log(
        'update system proxy failed: $error',
        logLevel: LogLevel.warning,
      );
    });
  }
}

String proxyEnvCommand(int port, {required bool isWindows}) {
  final url = 'http://127.0.0.1:$port';
  return isWindows ? 'set \$env:all_proxy=$url' : 'export all_proxy=$url';
}
