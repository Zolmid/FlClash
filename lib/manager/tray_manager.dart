import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray/tray.dart';

class TrayManager extends ConsumerStatefulWidget {
  final Widget child;
  @visibleForTesting
  final AppTray? testTray;
  @visibleForTesting
  final void Function(String)? onDelayTargetVisited;

  const TrayManager({
    super.key,
    required this.child,
    this.testTray,
    this.onDelayTargetVisited,
  });

  @override
  ConsumerState<TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends ConsumerState<TrayManager> {
  StreamSubscription<TrayEvent>? _subscription;
  bool _isUpdating = false;
  bool _hasPendingUpdate = false;
  Timer? _delayTimer;
  bool _isUpdatingDelays = false;
  final _changedDelayTargets = <String>{};
  bool _allDelayTargets = false;

  @override
  void initState() {
    super.initState();
    _subscription = Tray.instance.events.listen(_handleTrayEvent);
    ref.listenManual(profilesProvider, (_, _) => _requestUpdate());
    ref.listenManual(currentProfileIdProvider, (_, _) => _requestUpdate());
    ref.listenManual(updatingKeysProvider, (_, _) => _requestUpdate());
    ref.listenManual(currentBrightnessProvider, (_, _) => _requestUpdate());
    ref.listenManual(
      groupsProvider.select(
        (groups) => {for (final group in groups) group.name: group.now ?? ''},
      ),
      (previous, next) {
        if (!mapEquals(previous, next)) _requestUpdate();
      },
    );
    ref.listenManual(
      appSettingProvider.select((state) => state.showTrayProxySelection),
      (_, _) => _requestUpdate(),
    );
    ref.listenManual(delayDataSourceProvider, (_, next) {
      _requestDelayUpdate(
        next is DelayChangeMap ? (next as DelayChangeMap).changedTargets : null,
      );
    });
    ref.listenManual(pendingDelayTestsProvider, (_, next) {
      _requestDelayUpdate(
        next is DelayChangeMap ? (next as DelayChangeMap).changedTargets : null,
      );
    });
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        _requestUpdate();
      }
    });
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next) {
        _requestUpdate();
      }
    });
    if (system.isMacOS) {
      ref.listenManual(trayTitleStateProvider, (prev, next) {
        if (prev != next) {
          _reportFailure(
            appTray?.updateTitle(
              showTrayTitle: next.showTrayTitle,
              traffic: next.traffic,
            ),
          );
        }
      });
    }
  }

  void _requestDelayUpdate(Set<String>? changed) {
    if (changed == null) {
      _allDelayTargets = true;
      _changedDelayTargets.clear();
    } else if (!_allDelayTargets) {
      if (changed.isEmpty) return;
      _changedDelayTargets.addAll(changed);
    }
    _scheduleDelayUpdate();
  }

  void _scheduleDelayUpdate() {
    _delayTimer ??= Timer(renderThrottleDuration, () {
      _delayTimer = null;
      _reportFailure(_drainDelayUpdates());
    });
  }

  Future<void> _drainDelayUpdates() async {
    if (_isUpdatingDelays) return;
    _isUpdatingDelays = true;
    try {
      while ((_allDelayTargets || _changedDelayTargets.isNotEmpty) && mounted) {
        final changed = _allDelayTargets
            ? null
            : Set<String>.of(_changedDelayTargets);
        _allDelayTargets = false;
        _changedDelayTargets.clear();
        await (widget.testTray ?? appTray)?.updateDelays(
          read: ref.read,
          changedTargets: changed,
          onTargetVisited: widget.onDelayTargetVisited,
        );
      }
    } finally {
      _isUpdatingDelays = false;
      if (mounted && (_allDelayTargets || _changedDelayTargets.isNotEmpty)) {
        _scheduleDelayUpdate();
      }
    }
  }

  /// A delay test changes the menu per proxy, so updates in flight coalesce.
  void _requestUpdate() {
    if (_isUpdating) {
      _hasPendingUpdate = true;
      return;
    }
    _isUpdating = true;
    _reportFailure(_drainUpdates());
  }

  Future<void> _drainUpdates() async {
    try {
      do {
        _hasPendingUpdate = false;
        await ref.read(systemActionProvider.notifier).updateTray();
      } while (_hasPendingUpdate && mounted);
    } finally {
      _isUpdating = false;
      if (_hasPendingUpdate && mounted) {
        _requestUpdate();
      }
    }
  }

  void _reportFailure(Future<void>? operation) {
    if (operation == null) {
      return;
    }
    unawaited(
      operation.onError<Object>((error, stackTrace) {
        commonPrint.log(
          'Tray operation failed: ${compactError(error)}',
          logLevel: LogLevel.error,
        );
      }),
    );
  }

  void _handleTrayEvent(TrayEvent event) {
    switch (event) {
      case TrayIconActivated(
        :final activationTimestamp,
        :final activationToken,
      ):
        if (system.isMacOS) {
          _reportFailure(Tray.instance.openMenu());
        } else {
          _reportFailure(
            window?.show(
              activationTimestamp: activationTimestamp,
              activationToken: activationToken,
            ),
          );
        }
      case TrayMenuRequested():
        _reportFailure(Tray.instance.openMenu());
      case TrayMenuItemSelected():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
