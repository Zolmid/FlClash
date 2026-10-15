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
  final Service? _service;
  final bool? _isAndroid;

  const VpnManager({super.key, required this.child})
    : _service = null,
      _isAndroid = null;

  @visibleForTesting
  const VpnManager.forTesting({
    super.key,
    required Service mobileService,
    required bool isAndroid,
    required this.child,
  }) : _service = mobileService,
       _isAndroid = isAndroid;

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager>
    with WidgetsBindingObserver {
  var _checkRevision = 0;
  VpnOptions? _lastNotifiedOptions;
  late final Service? _service;
  late final bool _isMobile;
  late final bool _isAndroid;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? service;
    _isMobile = widget._service != null || system.isMobile;
    _isAndroid = widget._isAndroid ?? system.isAndroid;
    if (_isMobile) {
      WidgetsBinding.instance.addObserver(this);
      _service?.tunnelState.addListener(_checkActiveOptions);
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
        (!_isAndroid && _service?.tunnelState.value != TunnelState.connected)) {
      return;
    }
    try {
      final active = await _service?.getActiveVpnOptions();
      final requested = _isAndroid
          ? await _service?.getRequestedVpnOptions()
          : active;
      if (!mounted ||
          revision != _checkRevision ||
          !ref.read(isStartProvider) ||
          active == null) {
        return;
      }
      ref.read(runningVpnOptionsProvider.notifier).value = active;
      final options = ref.read(vpnOptionsProvider).value?.effective;
      if (options == null || options == (requested ?? active).effective) {
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
    if (_isMobile) {
      _service?.tunnelState.removeListener(_checkActiveOptions);
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
