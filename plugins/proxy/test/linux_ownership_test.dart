import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/src/linux_proxy.dart';
import 'package:proxy/src/proxy_command.dart';

class FakeSettings {
  final values = <String, String>{
    'org.gnome.system.proxy:mode': "'auto'",
    'org.gnome.system.proxy:ignore-hosts': "['local']",
    for (final k in ['http', 'https', 'socks']) ...{
      'org.gnome.system.proxy.$k:host': "'old.$k'",
      'org.gnome.system.proxy.$k:port': '8080',
    },
  };
  String? failKey;
  bool ignoreWrites = false;
  bool failNextReadAfterWrite = false;
  bool _failedReadPending = false;
  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    bool runInShell = false,
  }) async {
    final key = '${args[1]}:${args[2]}';
    if (args[0] == 'get') {
      if (_failedReadPending) {
        _failedReadPending = false;
        return ProcessResult(0, 1, '', 'read failed');
      }
      return ProcessResult(0, 0, values[key], '');
    }
    if (failKey == key) {
      failKey = null;
      return ProcessResult(0, 1, '', '');
    }
    if (ignoreWrites) return ProcessResult(0, 0, '', '');
    var value = args[3];
    if (args[2] == 'host' || args[2] == 'mode') {
      if (!value.startsWith("'")) value = "'$value'";
    }
    values[key] = value;
    if (failNextReadAfterWrite) {
      failNextReadAfterWrite = false;
      _failedReadPending = true;
    }
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  test(
    'readback failure after a write can still restore the old value',
    () async {
      final fake = FakeSettings()..failNextReadAfterWrite = true;
      final proxy = LinuxProxy(
        commandRunner: ProxyCommandRunner(fake.run),
        executableChecker: (_) async => true,
      );
      expect(
        await proxy.start(
          7890,
          ['localhost'],
          desktop: 'GNOME',
          homeDir: '/tmp',
        ),
        isFalse,
      );
      expect(fake.values['org.gnome.system.proxy:ignore-hosts'], "['local']");
    },
  );
  test('rejects a successful command when readback did not change', () async {
    final fake = FakeSettings()..ignoreWrites = true;
    final proxy = LinuxProxy(
      commandRunner: ProxyCommandRunner(fake.run),
      executableChecker: (_) async => true,
    );
    expect(
      await proxy.start(7890, ['localhost'], desktop: 'GNOME', homeDir: '/tmp'),
      isFalse,
    );
  });
  test(
    'GNOME restores a partial write and preserves a later user edit',
    () async {
      final fake = FakeSettings()
        ..failKey = 'org.gnome.system.proxy.https:port';
      final proxy = LinuxProxy(
        commandRunner: ProxyCommandRunner(fake.run),
        executableChecker: (_) async => true,
      );
      expect(
        await proxy.start(
          7890,
          ['localhost'],
          desktop: 'GNOME',
          homeDir: '/tmp',
        ),
        isFalse,
      );
      expect(fake.values['org.gnome.system.proxy.http:host'], "'old.http'");
      expect(
        await proxy.start(
          7890,
          ['localhost'],
          desktop: 'GNOME',
          homeDir: '/tmp',
        ),
        isTrue,
      );
      fake.values['org.gnome.system.proxy.http:host'] = "'user'";
      expect(await proxy.stop(desktop: 'GNOME', homeDir: '/tmp'), isTrue);
      expect(fake.values['org.gnome.system.proxy.http:host'], "'user'");
      expect(fake.values['org.gnome.system.proxy:mode'], "'auto'");
    },
  );
  test(
    'KDE restores existing keys and removes keys introduced by takeover',
    () async {
      final fake = FakeKde();
      final proxy = LinuxProxy(
        commandRunner: ProxyCommandRunner(fake.run),
        executableChecker: (_) async => true,
      );
      expect(
        await proxy.start(7890, ['localhost'], desktop: 'KDE', homeDir: '/tmp'),
        isTrue,
      );
      expect(await proxy.stop(desktop: 'KDE', homeDir: '/tmp'), isTrue);
      expect(fake.values, {'ProxyType': '2', 'httpProxy': 'http://old:8080'});
    },
  );
}

class FakeKde {
  final values = <String, String>{
    'ProxyType': '2',
    'httpProxy': 'http://old:8080',
  };
  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    bool runInShell = false,
  }) async {
    if (executable == 'dbus-send') return ProcessResult(0, 0, '', '');
    final key = args[args.indexOf('--key') + 1];
    if (executable.startsWith('kreadconfig'))
      return ProcessResult(0, 0, values[key] ?? '__ZOLNIT_MISSING__', '');
    if (args.last == '--delete') {
      values.remove(key);
    } else {
      values[key] = args.last;
    }
    return ProcessResult(0, 0, '', '');
  }
}
