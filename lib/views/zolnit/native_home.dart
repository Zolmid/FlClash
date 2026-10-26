import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_return_route.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';
import 'package:zolnit_native_ui/zolnit_native_ui.dart';

class ZolnitNativeHome extends ConsumerStatefulWidget {
  const ZolnitNativeHome({
    super.key,
    required this.session,
    required this.destination,
    required this.preferencesVisible,
    required this.onConnection,
    required this.onNavigate,
    required this.onRefresh,
    required this.onPreferences,
    required this.onHelp,
    required this.child,
    this.connectionBuilder,
  });

  final ZolnitSessionController session;
  final int destination;
  final bool preferencesVisible;
  final Future<bool> Function(bool running) onConnection;
  final ValueChanged<int> onNavigate;
  final Future<void> Function() onRefresh;
  final VoidCallback onPreferences;
  final Future<void> Function() onHelp;
  final Widget child;
  final Widget Function(Widget connection)? connectionBuilder;

  @override
  ConsumerState<ZolnitNativeHome> createState() => _ZolnitNativeHomeState();
}

class _ZolnitNativeHomeState extends ConsumerState<ZolnitNativeHome> {
  static const _enabled = bool.fromEnvironment('ZOLNIT_NATIVE_UI');
  static int _clock = DateTime.now().microsecondsSinceEpoch;
  static const _destinations = ['connect', 'servers', 'plans', 'account'];
  NativeUiBridge? _bridge;
  bool? _available;
  bool? _connectionIntent;
  int? _observedGeneration;
  int _nativeGeneration = 0;
  int _connectionRequest = 0;
  String? _fingerprint;
  Map<String, dynamic>? _pending;
  Timer? _publishTimer;

  bool get _supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    if (_enabled && _supported) {
      _bridge = NativeUiBridge(onCommand: _command);
      unawaited(_checkAvailability());
    }
  }

  Future<void> _checkAvailability() async {
    if (mounted) setState(() => _available = null);
    final available = await _bridge!.isAvailable();
    if (mounted) {
      setState(() {
        _available = available;
        _fingerprint = null;
      });
    }
  }

  @override
  void didUpdateWidget(ZolnitNativeHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _observedGeneration = null;
      _fingerprint = null;
      _connectionIntent = null;
    }
  }

  Map<String, dynamic> _snapshot() {
    final session = widget.session;
    if (_observedGeneration != session.api.generation) {
      _observedGeneration = session.api.generation;
      _nativeGeneration = ++_clock;
      _connectionIntent = null;
    }
    final text = context.appLocalizations;
    final usage = session.usage;
    final groups = ref.watch(currentGroupsStateProvider).value;
    final profile = ref.watch(currentProfileProvider);
    final returnRoute = ref.watch(zolnitClientBundleTransportProvider)
        ? currentZolnitReturnRoute(session, profile, ref.watch(groupsProvider))
        : null;
    final names = session.nodeList.map((node) => node.name).toSet();
    final managed = profile?.label == zolnitProfileLabel(session);
    final selector = managed
        ? groups
              .where(
                (group) =>
                    group.type == GroupType.Selector &&
                    group.all.any((proxy) => names.contains(proxy.name)),
              )
              .firstOrNull
        : null;
    final members =
        selector?.all.map((proxy) => proxy.name).toSet() ?? <String>{};
    final selected = selector == null
        ? null
        : ref.watch(selectedProxyNameProvider(selector.name));
    final servers = <String, Map<String, dynamic>>{};
    for (final node in session.nodeList) {
      if (node.name.isEmpty || node.name.length > 512) continue;
      servers.putIfAbsent(
        node.name,
        () => {
          'id': node.name,
          'name': node.title,
          'available': members.contains(node.name) && node.online != false,
          'latencyMs': null,
        },
      );
    }
    final safe = ref.watch(safeModeProvider);
    final running = ref.watch(isStartProvider);
    final connectionState = safe
        ? 'disconnected'
        : _connectionIntent == true
        ? 'connecting'
        : _connectionIntent == false
        ? 'disconnecting'
        : running
        ? 'connected'
        : 'disconnected';
    final traffic = connectionState == 'connected'
        ? ref.watch(trafficsProvider).list.lastOrNull
        : null;
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    return {
      'schemaVersion': 1,
      'revision': 0,
      'accountGeneration': _nativeGeneration,
      'locale': Localizations.localeOf(context).toString(),
      'textDirection': Directionality.of(context) == TextDirection.rtl
          ? 'rtl'
          : 'ltr',
      'safeMode': safe,
      'sessionStatus': session.restoreState.name,
      'connectionState': connectionState,
      'destination': _destinations[widget.destination],
      'mode': mode == Mode.global ? 'global' : 'rule',
      'selectedServerId': servers.containsKey(selected) ? selected : null,
      'servers': servers.values.toList(growable: false),
      if (returnRoute != null)
        'returnRoute': {
          'title': text.zolnitReturnRoute,
          'selectedId': returnRoute.selectedId,
          'enabled':
              !safe && ref.watch(coreStatusProvider) == CoreStatus.connected,
          'options': [
            for (final option in returnRoute.options)
              {'id': option.id, 'label': option.label(text)},
          ],
        },
      'planName': usage?.planName,
      'planExpiresAt': usage?.expiresAt == null
          ? null
          : usage!.expiresAt!.millisecondsSinceEpoch ~/ 1000,
      'usage': {'usedBytes': usage?.usedBytes, 'totalBytes': usage?.totalBytes},
      'traffic': {
        'uploadBps': _bytes(traffic?.up),
        'downloadBps': _bytes(traffic?.down),
      },
      'labels': {
        'connect': text.zolnitConnectAction,
        'disconnect': text.zolnitDisconnectAction,
        'disconnected': text.disconnected,
        'connecting': text.connecting,
        'connected': text.connected,
        'disconnecting': text.zolnitDisconnecting,
        'connectionFailed': text.zolnitFailure,
        'smartMode': text.zolnitModeSmart,
        'globalMode': text.zolnitModeGlobal,
        'servers': text.zolnitAllNodes,
        'plans': text.zolnitPlans,
        'account': text.account,
        'refresh': text.zolnitRefresh,
        'preferences': text.zolnitPreferences,
        'help': text.zolnitHelpSupport,
        'trafficRemaining': text.zolnitTrafficLeft,
        'trafficUsed': text.zolnitTrafficUsed,
        'upload': text.upload,
        'download': text.download,
        'noPlan': text.zolnitNoPlan,
        'noServers': text.zolnitNoNodes,
        'signIn': text.zolnitSignIn,
        'restoringSession': text.zolnitRestoringSession,
        'offline': text.offline,
        'retry': text.retry,
        'safeMode': text.zolnitSafeModeConnect,
        'selectServer': text.zolnitSelectServer,
        'currentPlan': text.zolnitCurrentPlanLabel,
        'loading': text.loading,
      },
    };
  }

  static int? _bytes(num? value) =>
      value == null || !value.isFinite || value < 0 ? null : value.toInt();

  void _scheduleSnapshot(Map<String, dynamic> value) {
    final fingerprint = jsonEncode(value);
    if (fingerprint == _fingerprint) return;
    final previous = _pending;
    _fingerprint = fingerprint;
    _pending = value;
    final urgent =
        previous == null ||
        previous['accountGeneration'] != value['accountGeneration'] ||
        previous['connectionState'] != value['connectionState'] ||
        previous['sessionStatus'] != value['sessionStatus'];
    if (urgent) {
      _publishTimer?.cancel();
      _publishTimer = null;
      scheduleMicrotask(_publish);
    } else {
      _publishTimer ??= Timer(const Duration(milliseconds: 250), _publish);
    }
  }

  void _publish() {
    _publishTimer = null;
    if (!mounted || _pending == null || _bridge == null) return;
    final value = Map<String, dynamic>.from(_pending!);
    value['revision'] = ++_clock;
    unawaited(_bridge!.publishSnapshot(NativeUiSnapshot.fromJson(value)));
  }

  Future<NativeUiReceipt> _command(NativeUiCommand command) async {
    final session = widget.session;
    final generation = session.api.generation;
    if (command.accountGeneration != _nativeGeneration ||
        _observedGeneration != generation) {
      return NativeUiReceipt.rejected(command.id, 'stale_account');
    }
    if ({
          'connect',
          'disconnect',
          'selectServer',
          'selectReturnRoute',
          'setMode',
        }.contains(command.action) &&
        ref.read(safeModeProvider)) {
      return NativeUiReceipt.rejected(command.id, 'safe_mode');
    }
    if ({
          'connect',
          'selectServer',
          'selectReturnRoute',
          'setMode',
        }.contains(command.action) &&
        !session.authenticated) {
      return NativeUiReceipt.rejected(command.id, 'unauthenticated');
    }
    switch (command.action) {
      case 'selectReturnRoute':
        final applied = await selectZolnitReturnRoute(
          ref,
          session,
          command.payload['optionId'] as String,
        );
        if (!applied) {
          return NativeUiReceipt.rejected(command.id, 'unavailable');
        }
      case 'connect':
      case 'disconnect':
        final desired = command.action == 'connect';
        final request = ++_connectionRequest;
        setState(() => _connectionIntent = desired);
        try {
          final applied = await widget.onConnection(desired);
          if (!applied) return NativeUiReceipt.rejected(command.id, 'failed');
        } finally {
          if (mounted &&
              identical(widget.session, session) &&
              session.api.generation == generation &&
              _connectionRequest == request) {
            setState(() => _connectionIntent = null);
          }
        }
      case 'navigate':
        final target = command.payload['destination'] as String;
        widget.onNavigate(_destinations.indexOf(target));
      case 'refresh':
        await widget.onRefresh();
      case 'preferences':
        await _bridge?.hideSurface();
        widget.onPreferences();
      case 'help':
        await widget.onHelp();
      case 'setMode':
        final mode = command.payload['mode'] == 'global'
            ? Mode.global
            : Mode.rule;
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(mode: mode));
      case 'selectServer':
        final profile = ref.read(currentProfileProvider);
        if (profile?.label != zolnitProfileLabel(session)) {
          return NativeUiReceipt.rejected(command.id, 'unavailable');
        }
        final name = command.payload['serverId'] as String;
        final groups = ref.read(currentGroupsStateProvider).value;
        final group = groups
            .where(
              (entry) =>
                  entry.type == GroupType.Selector &&
                  entry.all.any((proxy) => proxy.name == name),
            )
            .firstOrNull;
        if (group == null) {
          return NativeUiReceipt.rejected(command.id, 'unavailable');
        }
        selectGroupProxy(
          ref,
          groupName: group.name,
          groupType: GroupType.Selector,
          proxyName: name,
        );
    }
    if (!mounted ||
        !identical(widget.session, session) ||
        session.api.generation != generation) {
      return NativeUiReceipt.rejected(command.id, 'stale_account');
    }
    return NativeUiReceipt.accepted(command.id);
  }

  @override
  Widget build(BuildContext context) {
    final bridge = _bridge;
    if (bridge == null || !_enabled || !_supported) return widget.child;
    _scheduleSnapshot(_snapshot());

    if (widget.destination != 0 || widget.preferencesVisible) {
      return widget.child;
    }
    Widget wrap(Widget connection) =>
        defaultTargetPlatform == TargetPlatform.macOS
        ? widget.connectionBuilder?.call(connection) ?? connection
        : connection;
    if (_available == null) {
      return wrap(const Center(child: CommonCircleLoading()));
    }
    if (_available != true) {
      final text = context.appLocalizations;
      return wrap(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(text.zolnitConnectionPageUnavailable),
                TextButton(
                  onPressed: _checkAvailability,
                  child: Text(text.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return wrap(
      ZolnitNativeSurface(
        bridge: bridge,
        brightness: Theme.of(context).brightness,
      ),
    );
  }

  @override
  void dispose() {
    _publishTimer?.cancel();
    _bridge?.dispose();
    super.dispose();
  }
}
