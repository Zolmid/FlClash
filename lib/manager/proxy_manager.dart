import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/dialog.dart';
import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;
  final SystemProxyQueue? queue;

  const ProxyManager({super.key, required this.child, this.queue});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  late final ProviderSubscription<ProxyState> _proxySubscription;

  @override
  void initState() {
    super.initState();
    _proxySubscription = ProviderScope.containerOf(context, listen: false)
        .listen(proxyStateProvider, (prev, next) {
          if (prev != next) {
            (widget.queue ?? systemProxyQueue)?.apply(
              next,
              onStartFailed: () {
                if (!mounted || ref.read(proxyStateProvider) != next) return;
                if (((widget.queue ?? systemProxyQueue)?.restoreFailures ??
                        const <String>[])
                    .isNotEmpty) {
                  _showRestoreFailure(next);
                  return;
                }
                if (system.isMacOS) {
                  dialogs.showNotifier(
                    currentAppLocalizations.systemProxyApplyFailed,
                    level: MessageLevel.warning,
                  );
                }
              },
              onStopFailed: () => _showRestoreFailure(next),
            );
          }
        }, fireImmediately: true);
  }

  @override
  void dispose() {
    _proxySubscription.close();
    super.dispose();
  }

  void _showRestoreFailure(ProxyState expected) {
    if (!mounted || ref.read(proxyStateProvider) != expected) return;
    final failures =
        (widget.queue ?? systemProxyQueue)?.restoreFailures ?? const <String>[];
    dialogs.showNotifier(
      '${currentAppLocalizations.systemProxyRestoreFailed}${failures.isEmpty ? '' : '\n${failures.join('\n')}'}',
      level: MessageLevel.warning,
      actionState: MessageActionState(
        actionText: currentAppLocalizations.retry,
        action: () async {
          if (!mounted || ref.read(proxyStateProvider) != expected) return;
          await (widget.queue ?? systemProxyQueue)?.apply(
            expected.copyWith(isStart: false),
            onStopFailed: () => _showRestoreFailure(expected),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
