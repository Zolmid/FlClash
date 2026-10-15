import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@visibleForTesting
SharedState? serviceStateUpdate(
  SharedState? previous,
  SharedState next, {
  required bool isIOS,
}) {
  final previousState = isIOS ? previous : previous?.needSyncSharedState;
  final nextState = isIOS ? next : next.needSyncSharedState;
  return previousState == nextState ? null : nextState;
}

class AndroidManager extends ConsumerStatefulWidget {
  final Widget child;

  const AndroidManager({super.key, required this.child});

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager>
    with ServiceListener {
  @override
  void initState() {
    super.initState();
    if (system.isAndroid) {
      ref.listenManual(appSettingProvider.select((state) => state.hidden), (
        prev,
        next,
      ) {
        app?.updateExcludeFromRecents(next);
      }, fireImmediately: true);
    }
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next && !safeModeBuild) {
        app?.initShortcuts();
      }
    });
    ref.listenManual(sharedStateProvider, (prev, next) {
      if (prev != next) {
        debouncer.call(FunctionTag.saveSharedFile, () async {
          await preferences.saveShareState(next);
        }, duration: const Duration(seconds: 1));
        final state = serviceStateUpdate(prev, next, isIOS: system.isIOS);
        if (state != null) {
          service?.syncState(state);
        }
      }
    });
    service?.addListener(this);
    app?.onPackagesChanged = _reloadPackages;
  }

  /// A reload reads every installed app's label, and a round of store updates
  /// reports each app on its own.
  void _reloadPackages() {
    if (ref.read(packagesProvider).isEmpty) {
      return;
    }
    debouncer.call(FunctionTag.reloadPackages, () async {
      if (mounted) {
        await ref.read(systemActionProvider.notifier).getPackages();
      }
    }, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    debouncer.cancel(FunctionTag.reloadPackages);
    if (app?.onPackagesChanged == _reloadPackages) {
      app?.onPackagesChanged = null;
    }
    service?.removeListener(this);
    super.dispose();
  }

  @override
  void onServiceEvent(CoreEvent event) {
    coreEventManager.sendEvent(event);
    super.onServiceEvent(event);
  }

  @override
  void onServiceStopped() {
    unawaited(ref.read(setupActionProvider.notifier).setRunning(false));
    super.onServiceStopped();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
