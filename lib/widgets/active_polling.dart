import 'dart:async';

import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/inherited.dart';
import 'package:flutter/widgets.dart';

typedef PollGuard = bool Function();

mixin ActivePollingMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _isForeground = false;
  bool _isPageActive = true;
  bool _isPolling = false;
  int _pollGeneration = 0;
  bool _isUnfocused = false;
  ProviderContainer? _pollContainer;
  ProviderSubscription<AppSettingProps>? _pollSettings;
  AppSettingProps _settings = const AppSettingProps();

  bool get _supportsIdlePolling => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  Duration get _effectivePollInterval {
    if (_pollContainer == null) return pollInterval;
    final seconds = _isUnfocused && _settings.foregroundTickerIdleWhenUnfocused
        ? _settings.foregroundTickerIdleInterval
        : _settings.foregroundTickerInterval;
    final configured = Duration(seconds: seconds.clamp(1, 1 << 30));
    return configured > pollInterval ? configured : pollInterval;
  }

  void _rescheduleTimer() {
    if (_pollTimer == null) return;
    _pollTimer!.cancel();
    _pollTimer = null;
    if (_isPolling && canPoll) _schedulePoll(_pollGeneration);
  }

  Duration get pollInterval;

  bool get pollOnStart => true;

  Future<void> poll(PollGuard isCurrent);

  bool get canPoll => mounted && _isForeground && _isPageActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isUnfocused =
        lifecycleState == AppLifecycleState.inactive && _supportsIdlePolling;
    _isForeground =
        lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed ||
        _isUnfocused;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncPolling();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .findAncestorWidgetOfExactType<UncontrolledProviderScope>();
    final container = scope == null ? null : ProviderScope.containerOf(context);
    if (!identical(container, _pollContainer)) {
      _pollSettings?.close();
      _pollContainer = container;
      _pollSettings = container?.listen(appSettingProvider, (_, next) {
        _settings = next;
        _rescheduleTimer();
      }, fireImmediately: true);
    }
    final isPageActive =
        PageActivityScope.isActiveOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_isPageActive == isPageActive) {
      return;
    }
    _isPageActive = isPageActive;
    _syncPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isUnfocused = state == AppLifecycleState.inactive && _supportsIdlePolling;
    final isForeground = state == AppLifecycleState.resumed || _isUnfocused;
    _rescheduleTimer();
    if (_isForeground == isForeground) {
      return;
    }
    _isForeground = isForeground;
    _syncPolling();
  }

  @override
  void dispose() {
    _pollSettings?.close();
    WidgetsBinding.instance.removeObserver(this);
    _isForeground = false;
    stopPolling();
    super.dispose();
  }

  void startPolling() {
    if (!canPoll || _isPolling) {
      return;
    }
    _isPolling = true;
    final generation = ++_pollGeneration;
    if (pollOnStart) {
      unawaited(_runPoll(generation));
      return;
    }
    _schedulePoll(generation);
  }

  void stopPolling() {
    _isPolling = false;
    _pollGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void restartPolling() {
    stopPolling();
    _syncPolling();
  }

  void _syncPolling() {
    if (canPoll) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  bool _isCurrentPoll(int generation) =>
      canPoll && _isPolling && generation == _pollGeneration;

  void _schedulePoll(int generation) {
    _pollTimer = Timer(_effectivePollInterval, () {
      _pollTimer = null;
      if (_isCurrentPoll(generation)) {
        unawaited(_runPoll(generation));
      }
    });
  }

  Future<void> _runPoll(int generation) async {
    try {
      await poll(() => _isCurrentPoll(generation));
    } catch (error) {
      commonPrint.log(
        '$runtimeType poll error: $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      if (_isCurrentPoll(generation)) {
        _schedulePoll(generation);
      }
    }
  }
}

typedef TickWidgetBuilder = Widget Function(BuildContext context, int tick);

class TickBuilder extends StatefulWidget {
  final Duration duration;
  final TickWidgetBuilder builder;

  const TickBuilder({super.key, required this.duration, required this.builder})
    : assert(duration > Duration.zero);

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder>
    with WidgetsBindingObserver, ActivePollingMixin<TickBuilder> {
  int _tick = 0;

  @override
  Duration get pollInterval => widget.duration;

  @override
  bool get pollOnStart => false;

  @override
  Future<void> poll(PollGuard isCurrent) async {
    setState(() {
      _tick++;
    });
  }

  // Resuming restarts the interval, so a desktop window that loses focus more
  // often than that would otherwise never tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final couldPoll = canPoll;
    super.didChangeAppLifecycleState(state);
    if (!couldPoll && canPoll) {
      setState(() {
        _tick++;
      });
    }
  }

  @override
  void didUpdateWidget(covariant TickBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      restartPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _tick);
  }
}
