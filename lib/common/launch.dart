import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../enum/enum.dart';
import 'app_localizations.dart';
import 'constant.dart';
import 'dialog.dart';
import 'print.dart';
import 'system.dart';
import 'windows_autostart.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal()
    : _debugMode = kDebugMode,
      _safeMode = safeModeBuild,
      _regular = _RunAutostart() {
    launcher.setup(appName: appName, appPath: Platform.resolvedExecutable);
    _controller = AutostartController(
      regular: _regular,
      scheduled: system.isWindows
          ? WindowsScheduledAutostart(executable: Platform.resolvedExecutable)
          : null,
      onFailure: _reportFailure,
    );
  }

  @visibleForTesting
  AutoLaunch.forTesting({
    required AutostartRegistration regular,
    AutostartRegistration? scheduled,
    required void Function(Object error) onFailure,
    bool debugMode = false,
    bool safeMode = false,
  }) : _regular = regular,
       _debugMode = debugMode,
       _safeMode = safeMode {
    _controller = AutostartController(
      regular: regular,
      scheduled: scheduled,
      onFailure: onFailure,
    );
  }

  factory AutoLaunch() => _instance ??= AutoLaunch._internal();

  @visibleForTesting
  static LaunchAtStartup launcher = launchAtStartup;

  final bool _debugMode;
  final bool _safeMode;
  final AutostartRegistration _regular;
  late final AutostartController _controller;

  Future<bool> get isEnable => _regular.isEnabled();
  Future<bool> enable() => _regular.enable();
  Future<bool> disable() => _regular.disable();

  Future<void> updateStatus({
    required bool isAutoLaunch,
    bool isHighPriorityAutoLaunch = false,
  }) async {
    if (_debugMode || _safeMode) return;
    await _controller.update(
      enabled: isAutoLaunch,
      useScheduled: isHighPriorityAutoLaunch,
    );
  }

  void _reportFailure(Object error) {
    final message =
        '${currentAppLocalizations.autoLaunch}: ${compactError(error)}';
    commonPrint.log(message, logLevel: LogLevel.warning);
    dialogs.showNotifier(message, level: MessageLevel.error);
  }
}

class _RunAutostart implements AutostartRegistration {
  @override
  Future<bool> isEnabled() => AutoLaunch.launcher.isEnabled();

  @override
  Future<bool> enable() => AutoLaunch.launcher.enable();

  @override
  Future<bool> disable() => AutoLaunch.launcher.disable();
}

final autoLaunch = system.isDesktop && !safeModeBuild ? AutoLaunch() : null;
