import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;

  const VpnManager({super.key, required this.child});

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager>
    with WidgetsBindingObserver {
  var _checkRevision = 0;
  VpnOptions? _lastNotifiedOptions;

  @override
  void initState() {
    super.initState();
    if (system.isMobile) {
      WidgetsBinding.instance.addObserver(this);
      service?.tunnelState.addListener(_checkActiveOptions);
      ref.listenManual(isStartProvider, (_, next) {
        if (!next) {
          _lastNotifiedOptions = null;
        }
        _checkActiveOptions();
      });
      ref.listenManual(vpnOptionsProvider, (_, _) => _checkActiveOptions());
      _checkActiveOptions();
      return;
    }
    ref.listenManual(
      vpnOptionsProvider.select((state) => state.value?.effective),
      (prev, next) {
        final running = ref.read(runningVpnOptionsProvider)?.effective;
        if (next != null &&
            prev != next &&
            running != null &&
            running != next) {
          _showRestartTip();
        }
      },
    );
  }

  void _checkActiveOptions() {
    unawaited(_refreshActiveOptions());
  }

  Future<void> _refreshActiveOptions() async {
    final revision = ++_checkRevision;
    if (!mounted ||
        !ref.read(isStartProvider) ||
        ref.read(safeModeProvider) ||
        (system.isIOS && service?.tunnelState.value != TunnelState.connected)) {
      return;
    }
    try {
      final active = await (system.isAndroid
          ? service?.getRequestedVpnOptions()
          : service?.getActiveVpnOptions());
      if (!mounted ||
          revision != _checkRevision ||
          !ref.read(isStartProvider) ||
          active == null) {
        return;
      }
      ref.read(runningVpnOptionsProvider.notifier).value = active;
      final options = ref.read(vpnOptionsProvider).value?.effective;
      if (options == null || options == active.effective) {
        _lastNotifiedOptions = null;
        return;
      }
      if (options != _lastNotifiedOptions) {
        _lastNotifiedOptions = options;
        _showRestartTip();
      }
    } catch (error) {
      commonPrint.log('Unable to read active VPN options: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveOptions();
    }
  }

  @override
  void dispose() {
    _checkRevision++;
    if (system.isMobile) {
      service?.tunnelState.removeListener(_checkActiveOptions);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  void _showRestartTip() {
    dialogs.showNotifier(
      currentAppLocalizations.vpnConfigChangeDetected,
      level: MessageLevel.warning,
      actionState: MessageActionState(
        actionText: currentAppLocalizations.restart,
        action: () async {
          await ref.read(setupActionProvider.notifier).restartVpn();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
