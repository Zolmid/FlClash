import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/windows_autostart.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _sid = 'S-1-5-21-123-456-789-1001';
const _executable = r'C:\Apps & Tools\ZolNit\ZolNit.exe';

class _Scheduler {
  final calls = <(String, List<String>)>[];
  final tasks = <String, String>{};
  final xmlPaths = <String>[];
  bool queryUtf16 = false;
  bool failCreate = false;
  bool failDelete = false;
  int? queryFailure;
  bool failIdentity = false;

  Future<ProcessResult> run(String executable, List<String> arguments) async {
    calls.add((executable, [...arguments]));
    if (executable == 'whoami.exe') {
      return ProcessResult(
        0,
        failIdentity ? 1 : 0,
        '"DOMAIN\\User","$_sid"',
        '',
      );
    }
    expect(executable, 'schtasks.exe');
    final task = arguments[arguments.indexOf('/TN') + 1];
    expect(task, startsWith('ZolNit_AutoLaunch_${_sid}_'));
    switch (arguments.first) {
      case '/Query':
        expect(arguments, contains('/XML'));
        expect(arguments, contains('/HRESULT'));
        return ProcessResult(
          0,
          queryFailure ?? (tasks.containsKey(task) ? 0 : 0x80070002),
          queryUtf16 && tasks[task] != null
              ? [
                  0xff,
                  0xfe,
                  for (final unit in tasks[task]!.codeUnits) ...[
                    unit & 0xff,
                    unit >> 8,
                  ],
                ]
              : tasks[task] ?? '',
          '',
        );
      case '/Create':
        final file = File(arguments[arguments.indexOf('/XML') + 1]);
        xmlPaths.add(file.path);
        final bytes = await file.readAsBytes();
        expect(bytes.take(2), [0xff, 0xfe]);
        final xml = String.fromCharCodes([
          for (var index = 2; index < bytes.length; index += 2)
            bytes[index] | (bytes[index + 1] << 8),
        ]);
        if (!failCreate) tasks[task] = xml;
        return ProcessResult(0, failCreate ? 1 : 0, '', '');
      case '/Delete':
        if (!failDelete) tasks.remove(task);
        return ProcessResult(0, failDelete ? 1 : 0, '', '');
      default:
        fail('Unexpected command: $arguments');
    }
  }
}

class _Registration implements AutostartRegistration {
  _Registration(this.name, this.calls);

  final String name;
  final List<String> calls;
  bool enabled = false;
  bool failEnable = false;
  bool failDisable = false;
  bool failAfterDisable = false;
  Completer<void>? enableGate;
  Completer<void>? enableEntered;

  @override
  Future<bool> isEnabled() async {
    calls.add('$name.read');
    return enabled;
  }

  @override
  Future<bool> enable() async {
    calls.add('$name.enable');
    enableEntered?.complete();
    await enableGate?.future;
    if (failEnable) return false;
    enabled = true;
    return true;
  }

  @override
  Future<bool> disable() async {
    calls.add('$name.disable');
    if (failDisable) return false;
    enabled = false;
    return !failAfterDisable;
  }
}

void main() {
  group('Windows scheduled autostart', () {
    late _Scheduler scheduler;
    late WindowsScheduledAutostart task;
    late Directory temporary;

    setUp(() {
      scheduler = _Scheduler();
      temporary = Directory.systemTemp.createTempSync('autostart_test_');
      task = WindowsScheduledAutostart(
        executable: _executable,
        runProcess: scheduler.run,
        temporaryDirectory: temporary,
      );
    });
    tearDown(() => temporary.deleteSync(recursive: true));

    test(
      'creates a scoped, least-privilege current-user task and escapes XML',
      () async {
        expect(await task.enable(), isTrue);
        final xml = scheduler.tasks.values.single;
        final document = XmlDocument.parse(xml);
        final values = {
          for (final element in document.descendants.whereType<XmlElement>())
            element.name.local: element.innerText,
        };
        expect(values['Command'], _executable);
        expect(values['WorkingDirectory'], r'C:\Apps & Tools\ZolNit');
        expect(values['RunLevel'], 'LeastPrivilege');
        expect(values['LogonType'], 'InteractiveToken');
        expect(values['UserId'], _sid);
        expect(values['Delay'], 'PT0S');
        expect(xml, contains('Apps &amp; Tools'));
        expect(
          scheduler.calls.expand((call) => call.$2),
          isNot(contains('/RU')),
        );
        expect(
          scheduler.calls.expand((call) => call.$2),
          isNot(contains('/F')),
        );
        expect(
          scheduler.calls.map((call) => call.$1),
          isNot(contains('cmd.exe')),
        );
        expect(temporary.listSync(), isEmpty);
      },
    );

    test(
      'decodes UTF-16 task queries without losing non-ASCII executable names',
      () async {
        scheduler.queryUtf16 = true;
        final unicodeTask = WindowsScheduledAutostart(
          executable: r'C:\应用 & Tools\FlClash.exe',
          runProcess: scheduler.run,
          temporaryDirectory: temporary,
        );
        expect(await unicodeTask.enable(), isTrue);
        expect(await unicodeTask.isEnabled(), isTrue);
        expect(await unicodeTask.disable(), isTrue);
      },
    );

    test('an already enabled owned task needs no replacement', () async {
      await task.enable();
      scheduler.calls.clear();
      expect(await task.enable(), isTrue);
      expect(scheduler.calls.map((call) => call.$2.first), ['/Query']);
    });

    test('only an owned disabled task can be force-replaced', () async {
      await task.enable();
      final name = scheduler.tasks.keys.single;
      scheduler.tasks[name] = scheduler.tasks[name]!.replaceFirst(
        '<Enabled>true</Enabled>',
        '<Enabled>false</Enabled>',
      );
      scheduler.calls.clear();
      expect(await task.enable(), isTrue);
      final create = scheduler.calls.singleWhere(
        (call) => call.$2.first == '/Create',
      );
      expect(create.$2, contains('/F'));
    });

    test('a conflicting task is never replaced or deleted', () async {
      await task.enable();
      final name = scheduler.tasks.keys.single;
      scheduler.tasks[name] = scheduler.tasks[name]!.replaceFirst(
        'com.zolmid.zolnit.autostart.v1',
        'other.application',
      );
      scheduler.calls.clear();
      await expectLater(task.enable(), throwsA(isA<AutostartException>()));
      await expectLater(task.disable(), throwsA(isA<AutostartException>()));
      expect(scheduler.calls.map((call) => call.$2.first), [
        '/Query',
        '/Query',
      ]);
    });

    test(
      'matching ownership labels do not admit a different account or command',
      () async {
        await task.enable();
        final name = scheduler.tasks.keys.single;
        final original = scheduler.tasks[name]!;
        for (final changed in [
          original.replaceFirst(
            '<UserId>$_sid</UserId>',
            '<UserId>S-1-5-18</UserId>',
          ),
          original.replaceFirst(
            '</Command>',
            '</Command><Arguments>--other</Arguments>',
          ),
          original.replaceFirst('LeastPrivilege', 'HighestAvailable'),
          original.replaceFirst('ZolNit.exe', 'Other.exe'),
        ]) {
          scheduler.tasks[name] = changed;
          await expectLater(task.disable(), throwsA(isA<AutostartException>()));
        }
        expect(
          scheduler.calls.where((call) => call.$2.first == '/Delete'),
          isEmpty,
        );
      },
    );

    test('access denial is not treated as a missing task', () async {
      for (final failure in [0x80070005, 0x8004130f]) {
        scheduler.queryFailure = failure;
        await expectLater(task.enable(), throwsA(isA<AutostartException>()));
      }
      expect(
        scheduler.calls.where((call) => call.$2.first == '/Create'),
        isEmpty,
      );
    });

    test(
      'missing task removal is a no-op; owned removal uses the exact name',
      () async {
        expect(await task.disable(), isTrue);
        expect(
          scheduler.calls.where((call) => call.$2.first == '/Delete'),
          isEmpty,
        );
        await task.enable();
        final name = scheduler.tasks.keys.single;
        expect(await task.disable(), isTrue);
        expect(scheduler.tasks, isEmpty);
        final delete = scheduler.calls.singleWhere(
          (call) => call.$2.first == '/Delete',
        );
        expect(delete.$2, ['/Delete', '/TN', name, '/F']);
      },
    );

    test(
      'failed registrations use unique files and always remove their XML',
      () async {
        scheduler.failCreate = true;
        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(task.enable(), throwsA(isA<AutostartException>()));
        }
        expect(scheduler.xmlPaths.toSet(), hasLength(2));
        expect(temporary.listSync(), isEmpty);
      },
    );

    test(
      'identity failure does not query or mutate any scheduled task',
      () async {
        scheduler.failIdentity = true;
        await expectLater(task.enable(), throwsA(isA<AutostartException>()));
        expect(scheduler.calls.map((call) => call.$1), ['whoami.exe']);
      },
    );
  });

  group('Autostart convergence', () {
    late List<String> calls;
    late List<Object> errors;
    late _Registration regular;
    late _Registration scheduled;
    late AutostartController controller;

    setUp(() {
      calls = [];
      errors = [];
      regular = _Registration('regular', calls);
      scheduled = _Registration('scheduled', calls);
      controller = AutostartController(
        regular: regular,
        scheduled: scheduled,
        onFailure: errors.add,
      );
    });

    test('creates the task before removing the existing Run entry', () async {
      regular.enabled = true;
      await controller.update(enabled: true, useScheduled: true);
      expect(calls, [
        'regular.read',
        'scheduled.read',
        'scheduled.enable',
        'regular.disable',
      ]);
      expect(regular.enabled, isFalse);
      expect(scheduled.enabled, isTrue);
      expect(errors, isEmpty);
    });

    test(
      'a task registration failure preserves the existing Run entry and reports it',
      () async {
        regular.enabled = true;
        scheduled.failEnable = true;
        await controller.update(enabled: true, useScheduled: true);
        expect(regular.enabled, isTrue);
        expect(scheduled.enabled, isFalse);
        expect(calls, isNot(contains('regular.disable')));
        expect(errors, hasLength(1));
      },
    );

    test('a Run registration failure preserves the existing task', () async {
      scheduled.enabled = true;
      regular.failEnable = true;
      await controller.update(enabled: true, useScheduled: false);
      expect(regular.enabled, isFalse);
      expect(scheduled.enabled, isTrue);
      expect(calls, isNot(contains('scheduled.disable')));
      expect(errors, hasLength(1));
    });

    test(
      'failure to remove the old mode rolls back the newly enabled mode',
      () async {
        regular.enabled = true;
        regular.failDisable = true;
        await controller.update(enabled: true, useScheduled: true);
        expect(regular.enabled, isTrue);
        expect(scheduled.enabled, isFalse);
        expect(calls.last, 'scheduled.disable');
        expect(errors, hasLength(1));
      },
    );

    test(
      'a cleanup that already removed the old entry does not remove the new mode',
      () async {
        regular.enabled = true;
        regular.failAfterDisable = true;
        await controller.update(enabled: true, useScheduled: true);
        expect(regular.enabled, isFalse);
        expect(scheduled.enabled, isTrue);
        expect(calls, isNot(contains('scheduled.disable')));
        expect(errors, hasLength(1));
      },
    );

    test(
      'a toggle during task creation converges to the newest disabled intent',
      () async {
        regular.enabled = true;
        scheduled.enableGate = Completer<void>();
        scheduled.enableEntered = Completer<void>();
        final first = controller.update(enabled: true, useScheduled: true);
        await scheduled.enableEntered!.future;
        final latest = controller.update(enabled: false, useScheduled: false);
        scheduled.enableGate!.complete();
        await Future.wait([first, latest]);
        expect(regular.enabled, isFalse);
        expect(scheduled.enabled, isFalse);
        expect(calls.where((call) => call == 'regular.disable'), hasLength(1));
        expect(errors, isEmpty);
      },
    );

    test(
      'a newer regular intent keeps Run and removes a superseded newly created task',
      () async {
        regular.enabled = true;
        scheduled.enableGate = Completer<void>();
        scheduled.enableEntered = Completer<void>();
        final first = controller.update(enabled: true, useScheduled: true);
        await scheduled.enableEntered!.future;
        final latest = controller.update(enabled: true, useScheduled: false);
        scheduled.enableGate!.complete();
        await Future.wait([first, latest]);
        expect(regular.enabled, isTrue);
        expect(scheduled.enabled, isFalse);
        expect(calls, isNot(contains('regular.disable')));
      },
    );

    test(
      'turning autostart off removes both pre-existing owned modes',
      () async {
        regular.enabled = scheduled.enabled = true;
        await controller.update(enabled: false, useScheduled: true);
        expect(regular.enabled, isFalse);
        expect(scheduled.enabled, isFalse);
      },
    );

    test(
      'platforms without scheduled tasks continue using the regular launcher',
      () async {
        final controller = AutostartController(
          regular: regular,
          onFailure: errors.add,
        );
        await controller.update(enabled: true, useScheduled: true);
        expect(regular.enabled, isTrue);
        expect(calls, ['regular.read', 'regular.enable']);
      },
    );
  });
}
