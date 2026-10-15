import 'package:fl_clash/common/launch.dart';
import 'package:fl_clash/common/windows_autostart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class _FakeLauncher implements LaunchAtStartup {
  bool enabled = false;
  final calls = <String>[];

  @override
  void setup({
    required String appName,
    required String appPath,
    String? packageName,
    List<String> args = const [],
  }) {
    calls.add('setup');
  }

  @override
  Future<bool> isEnabled() async {
    calls.add('isEnabled');
    return enabled;
  }

  @override
  Future<bool> enable() async {
    calls.add('enable');
    enabled = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    calls.add('disable');
    enabled = false;
    return true;
  }
}

class _GuardedRegistration implements AutostartRegistration {
  int calls = 0;

  @override
  Future<bool> isEnabled() async {
    calls++;
    return false;
  }

  @override
  Future<bool> enable() async {
    calls++;
    return true;
  }

  @override
  Future<bool> disable() async {
    calls++;
    return true;
  }
}

void main() {
  late _FakeLauncher launcher;
  late AutoLaunch autoLaunch;

  setUp(() {
    launcher = _FakeLauncher();
    AutoLaunch.launcher = launcher;
    autoLaunch = AutoLaunch();
    launcher.calls.clear();
  });

  tearDownAll(() {
    AutoLaunch.launcher = launchAtStartup;
  });

  test('AutoLaunch is a singleton', () {
    expect(AutoLaunch(), same(autoLaunch));
  });

  test('each call delegates straight to the launcher', () async {
    launcher.enabled = true;
    expect(await autoLaunch.isEnable, isTrue);

    expect(await autoLaunch.disable(), isTrue);
    expect(launcher.enabled, isFalse);

    expect(await autoLaunch.enable(), isTrue);
    expect(launcher.enabled, isTrue);

    expect(launcher.calls, ['isEnabled', 'disable', 'enable']);
  });

  test('a debug build never registers autostart', () async {
    expect(
      kDebugMode,
      isTrue,
      reason: 'flutter test runs in debug; the guard below assumes it.',
    );

    await autoLaunch.updateStatus(
      isAutoLaunch: true,
      isHighPriorityAutoLaunch: true,
    );
    await autoLaunch.updateStatus(isAutoLaunch: false);

    expect(
      launcher.calls,
      isEmpty,
      reason:
          'updateStatus must return before reading or writing the autostart '
          'entry, or every debug run would register the running binary.',
    );
  });
  test(
    'safe mode never queries or changes either Windows autostart mode',
    () async {
      final regular = _GuardedRegistration();
      final scheduled = _GuardedRegistration();
      final guarded = AutoLaunch.forTesting(
        regular: regular,
        scheduled: scheduled,
        safeMode: true,
        onFailure: (error) => fail('No OS call was expected: $error'),
      );
      await guarded.updateStatus(
        isAutoLaunch: true,
        isHighPriorityAutoLaunch: true,
      );
      await guarded.updateStatus(isAutoLaunch: false);
      expect(regular.calls, 0);
      expect(scheduled.calls, 0);
    },
  );
}
