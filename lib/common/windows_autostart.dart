import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

typedef AutostartProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

abstract interface class AutostartRegistration {
  Future<bool> isEnabled();
  Future<bool> enable();
  Future<bool> disable();
}

class AutostartException implements Exception {
  const AutostartException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WindowsScheduledAutostart implements AutostartRegistration {
  WindowsScheduledAutostart({
    required this.executable,
    AutostartProcessRunner? runProcess,
    this.temporaryDirectory,
  }) : _runProcess = runProcess ?? _runWindowsProcess {
    if (!p.windows.isAbsolute(executable)) {
      throw ArgumentError.value(
        executable,
        'executable',
        'Expected an absolute path',
      );
    }
  }

  final String executable;
  final Directory? temporaryDirectory;
  final AutostartProcessRunner _runProcess;
  String? _sid;

  String get _installation => sha256
      .convert(utf8.encode(p.windows.normalize(executable).toLowerCase()))
      .toString()
      .substring(0, 16);

  Future<String> _currentSid() async {
    final cached = _sid;
    if (cached != null) return cached;
    final result = await _runProcess('whoami.exe', [
      '/USER',
      '/FO',
      'CSV',
      '/NH',
    ]);
    final match = RegExp(
      r'"(S-1-[0-9]+(?:-[0-9]+)+)"\s*$',
    ).firstMatch(_decodeWindowsOutput(result.stdout).trim());
    if (result.exitCode != 0 || match == null) {
      throw const AutostartException(
        'Unable to identify the current Windows user',
      );
    }
    return _sid = match.group(1)!;
  }

  String _taskName(String sid) => 'ZolNit_AutoLaunch_${sid}_$_installation';
  String _source(String sid) =>
      'com.zolmid.zolnit.autostart.v1/$sid/$_installation';

  Future<({String sid, bool exists, bool enabled})> _query() async {
    final sid = await _currentSid();
    final result = await _runProcess('schtasks.exe', [
      '/Query',
      '/TN',
      _taskName(sid),
      '/XML',
      '/HRESULT',
    ]);
    final code = result.exitCode & 0xffffffff;
    if (const {0x80070002, 0x80070003}.contains(code)) {
      return (sid: sid, exists: false, enabled: false);
    }
    if (result.exitCode != 0) {
      throw AutostartException(
        'Unable to query the autostart task (exit $code)',
      );
    }
    final XmlElement root;
    try {
      root = XmlDocument.parse(_decodeWindowsOutput(result.stdout)).rootElement;
    } on XmlParserException {
      throw const AutostartException(
        'Windows returned an invalid autostart task',
      );
    }
    final principals = _child(root, 'Principals')?.childElements.toList() ?? [];
    final triggers = _child(root, 'Triggers')?.childElements.toList() ?? [];
    final actions = _child(root, 'Actions')?.childElements.toList() ?? [];
    if (root.name.local != 'Task' ||
        principals.length != 1 ||
        principals.single.name.local != 'Principal' ||
        triggers.length != 1 ||
        triggers.single.name.local != 'LogonTrigger' ||
        actions.length != 1 ||
        actions.single.name.local != 'Exec' ||
        _text(_child(root, 'RegistrationInfo'), 'Source') != _source(sid) ||
        _text(principals.single, 'UserId') != sid ||
        _text(principals.single, 'LogonType') != 'InteractiveToken' ||
        _text(principals.single, 'RunLevel') != 'LeastPrivilege' ||
        _text(triggers.single, 'UserId') != sid ||
        p.windows.normalize(_text(actions.single, 'Command')).toLowerCase() !=
            p.windows.normalize(executable).toLowerCase() ||
        _text(actions.single, 'Arguments').isNotEmpty) {
      throw const AutostartException(
        'The autostart task is not owned by this installation',
      );
    }
    return (
      sid: sid,
      exists: true,
      enabled:
          _text(_child(root, 'Settings'), 'Enabled') != 'false' &&
          _text(triggers.single, 'Enabled') != 'false',
    );
  }

  @override
  Future<bool> isEnabled() async => (await _query()).enabled;

  @override
  Future<bool> enable() async {
    final current = await _query();
    if (current.enabled) return true;
    final temporary = await (temporaryDirectory ?? Directory.systemTemp)
        .createTemp('zolnit_autostart_');
    try {
      final file = File(p.join(temporary.path, 'task.xml'));
      final content = _taskXml(current.sid);
      await file.writeAsBytes([
        0xff,
        0xfe,
        for (final unit in content.codeUnits) ...[unit & 0xff, unit >> 8],
      ], flush: true);
      final result = await _runProcess('schtasks.exe', [
        '/Create',
        '/TN',
        _taskName(current.sid),
        '/XML',
        file.path,
        if (current.exists) '/F',
      ]);
      if (result.exitCode != 0) {
        throw AutostartException(
          'Unable to register the autostart task (exit ${result.exitCode})',
        );
      }
      return (await _query()).enabled;
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  @override
  Future<bool> disable() async {
    final current = await _query();
    if (!current.exists) return true;
    final result = await _runProcess('schtasks.exe', [
      '/Delete',
      '/TN',
      _taskName(current.sid),
      '/F',
    ]);
    if (result.exitCode != 0) {
      throw AutostartException(
        'Unable to remove the autostart task (exit ${result.exitCode})',
      );
    }
    return !(await _query()).exists;
  }

  String _taskXml(String sid) {
    String escape(String value) => XmlText(value).toXmlString();
    return '''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Source>${escape(_source(sid))}</Source></RegistrationInfo>
  <Principals><Principal id="Author"><UserId>${escape(sid)}</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>${escape(sid)}</UserId><Delay>PT0S</Delay></LogonTrigger></Triggers>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled><Hidden>false</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><Priority>7</Priority>
  </Settings>
  <Actions Context="Author"><Exec><Command>${escape(executable)}</Command><WorkingDirectory>${escape(p.windows.dirname(executable))}</WorkingDirectory></Exec></Actions>
</Task>''';
  }
}

Future<ProcessResult> _runWindowsProcess(
  String executable,
  List<String> arguments,
) => Process.run(
  executable,
  arguments,
  stdoutEncoding: null,
  stderrEncoding: null,
);

String _decodeWindowsOutput(Object output) {
  if (output is! List<int>) return output.toString();
  final littleEndian =
      output.length >= 2 &&
      ((output[0] == 0xff && output[1] == 0xfe) ||
          (output[0] == 0x3c && output[1] == 0));
  final bigEndian =
      output.length >= 2 &&
      ((output[0] == 0xfe && output[1] == 0xff) ||
          (output[0] == 0 && output[1] == 0x3c));
  if (littleEndian || bigEndian) {
    final start = output[0] == 0xff || output[0] == 0xfe ? 2 : 0;
    if ((output.length - start).isOdd) {
      throw const AutostartException(
        'Windows returned incomplete Unicode output',
      );
    }
    return String.fromCharCodes([
      for (var index = start; index < output.length; index += 2)
        littleEndian
            ? output[index] | (output[index + 1] << 8)
            : (output[index] << 8) | output[index + 1],
    ]);
  }
  try {
    return utf8.decode(output);
  } on FormatException {
    return systemEncoding.decode(output);
  }
}

XmlElement? _child(XmlElement? parent, String name) {
  for (final element in parent?.childElements ?? <XmlElement>[]) {
    if (element.name.local == name) return element;
  }
  return null;
}

String _text(XmlElement? parent, String name) =>
    _child(parent, name)?.innerText.trim() ?? '';

enum _AutostartMode { disabled, regular, scheduled }

class AutostartController {
  AutostartController({
    required this.regular,
    required this.onFailure,
    this.scheduled,
  });

  final AutostartRegistration regular;
  final AutostartRegistration? scheduled;
  final void Function(Object error) onFailure;
  _AutostartMode _desired = _AutostartMode.disabled;
  int _revision = 0;
  Future<void>? _pending;

  Future<void> update({required bool enabled, required bool useScheduled}) {
    _desired = !enabled
        ? _AutostartMode.disabled
        : useScheduled && scheduled != null
        ? _AutostartMode.scheduled
        : _AutostartMode.regular;
    _revision++;
    return _pending ??= _drain();
  }

  Future<void> _drain() async {
    var handled = -1;
    try {
      while (handled != _revision) {
        handled = _revision;
        try {
          await _apply(_desired, handled);
        } catch (error) {
          onFailure(error);
        }
      }
    } finally {
      _pending = null;
    }
  }

  Future<void> _apply(_AutostartMode mode, int revision) async {
    final regularEnabled = await regular.isEnabled();
    if (revision != _revision) return;
    final scheduledRegistration = scheduled;
    final scheduledEnabled = await scheduledRegistration?.isEnabled() ?? false;
    if (revision != _revision) return;
    if (mode == _AutostartMode.disabled) {
      if (regularEnabled) await _set(regular, false);
      if (revision != _revision) return;
      if (scheduledEnabled) await _set(scheduledRegistration!, false);
      return;
    }
    final prefersTask = mode == _AutostartMode.scheduled;
    final preferred = prefersTask ? scheduledRegistration! : regular;
    final previous = prefersTask ? regular : scheduledRegistration;
    final preferredEnabled = prefersTask ? scheduledEnabled : regularEnabled;
    final previousEnabled = prefersTask ? regularEnabled : scheduledEnabled;
    if (!preferredEnabled) await _set(preferred, true);
    if (revision != _revision || !previousEnabled) return;
    try {
      await _set(previous!, false);
    } catch (error) {
      if (!preferredEnabled) {
        final bool previousStillEnabled;
        try {
          previousStillEnabled = await previous!.isEnabled();
        } catch (verificationError) {
          throw AutostartException(
            '$error; unable to verify the previous mode, keeping the new mode enabled: $verificationError',
          );
        }
        if (previousStillEnabled) {
          try {
            await _set(preferred, false);
          } catch (rollbackError) {
            throw AutostartException(
              '$error; restoring the previous mode also failed: $rollbackError',
            );
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _set(AutostartRegistration registration, bool enabled) async {
    final success = await (enabled
        ? registration.enable()
        : registration.disable());
    if (!success) {
      throw AutostartException(
        'Unable to ${enabled ? 'enable' : 'disable'} autostart',
      );
    }
  }
}
