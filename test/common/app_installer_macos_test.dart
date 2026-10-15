import 'dart:io';

import 'package:fl_clash/common/app_installer.dart';
import 'package:test/test.dart';

const _plistBuddy = r'''
case "$2" in
  'Print :CFBundleIdentifier') sed -n 's/^id=//p' "$3" ;;
  'Print :CFBundleExecutable') sed -n 's/^executable=//p' "$3" ;;
  *) exit 1 ;;
esac
''';

const _hdiutil = r'''
case "$1" in
  attach)
    shift
    mount=''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -mountpoint) mount="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$mount" ] || exit 1
    cp -R "$TEST_VOLUME/." "$mount"
    ;;
  detach) rm -rf "$2"/*.app ;;
  *) exit 1 ;;
esac
''';

const _move = r'''
case "$1" in
  */new.app) [ "$TEST_FAIL_PROMOTION" = 0 ] || exit 1 ;;
  */previous.app) [ "$TEST_FAIL_RESTORE" = 0 ] || exit 1 ;;
esac
exec /bin/mv "$@"
''';

class _InstallHarness {
  _InstallHarness(this.directory);

  final Directory directory;

  Directory get application => Directory('${directory.path}/Installed App.app');
  Directory get volume => Directory('${directory.path}/volume');
  Directory get tools => Directory('${directory.path}/bin');
  File get dmg => File('${directory.path}/update.dmg');
  File get opened => File('${directory.path}/opened');
  Directory get previousBackup => Directory('${application.path}.previous');
  Directory get otherBackup =>
      Directory('${application.path}.update.untouched/previous.app');

  Future<void> initialize() async {
    await tools.create();
    await volume.create();
    await Directory('${directory.path}/mounts').create();
    await dmg.writeAsString('fixture');
    await bundle(application, build: 'old');
    await bundle(previousBackup, build: 'previous backup');
    await bundle(otherBackup, build: 'another operation');
    final scripts = {
      'plist-buddy': _plistBuddy,
      'hdiutil': _hdiutil,
      'lipo': r'''[ "$1" = -verify_arch ] && [ "$(cat "$3")" = "$2" ]''',
      'ditto': r'''cp -R "$1" "$2"''',
      'open': r'''printf '%s\n' "$1" > "$TEST_OPENED"''',
      'mv': _move,
    };
    for (final entry in scripts.entries) {
      final file = File('${tools.path}/${entry.key}');
      await file.writeAsString('#!/bin/sh\n${entry.value}\n');
      final result = await Process.run('/bin/chmod', ['755', file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
  }

  Future<Directory> bundle(
    Directory target, {
    required String build,
    String identifier = 'com.follow.clash',
    String arch = 'arm64',
  }) async {
    await Directory('${target.path}/Contents/MacOS').create(recursive: true);
    await File(
      '${target.path}/Contents/Info.plist',
    ).writeAsString('id=$identifier\nexecutable=FlClash\n');
    await File('${target.path}/Contents/MacOS/FlClash').writeAsString(arch);
    await File('${target.path}/build.txt').writeAsString(build);
    return target;
  }

  Future<void> install({
    bool failPromotion = false,
    bool failRestore = false,
  }) async {
    final script = macosInstallScript.replaceAll(
      '/usr/libexec/PlistBuddy',
      'plist-buddy',
    );
    final result = await Process.run(
      '/bin/sh',
      [
        '-c',
        script,
        'flclash-macos-install-test',
        '2147483647',
        dmg.path,
        application.path,
        'arm64',
      ],
      environment: {
        'PATH': '${tools.path}:/usr/bin:/bin:/usr/sbin:/sbin',
        'TMPDIR': '${directory.path}/mounts',
        'TEST_VOLUME': volume.path,
        'TEST_OPENED': opened.path,
        'TEST_FAIL_PROMOTION': failPromotion ? '1' : '0',
        'TEST_FAIL_RESTORE': failRestore ? '1' : '0',
      },
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await opened.readAsString(), '${application.path}\n');
    expect(await dmg.exists(), isFalse);
  }

  Future<void> expectOtherBackupsUntouched() async {
    expect(
      await File('${previousBackup.path}/build.txt').readAsString(),
      'previous backup',
    );
    expect(
      await File('${otherBackup.path}/build.txt').readAsString(),
      'another operation',
    );
  }
}

void main() {
  group('macOS installer shell state', () {
    late _InstallHarness harness;

    setUp(() async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-mac-install-',
      );
      addTearDown(() => directory.delete(recursive: true));
      harness = _InstallHarness(directory);
      await harness.initialize();
    });

    test(
      'selects the unique matching bundle after a wrong first app and excludes symlinks',
      () async {
        await harness.bundle(
          Directory('${harness.volume.path}/A Wrong.app'),
          build: 'wrong',
          identifier: 'another.application',
        );
        await harness.bundle(
          Directory('${harness.volume.path}/B Wrong Arch.app'),
          build: 'wrong arch',
          arch: 'x86_64',
        );
        final correct = await harness.bundle(
          Directory('${harness.volume.path}/Z Correct.app'),
          build: 'new',
        );
        await Link('${harness.volume.path}/C Alias.app').create(correct.path);

        await harness.install();

        expect(
          await File('${harness.application.path}/build.txt').readAsString(),
          'new',
        );
        await harness.expectOtherBackupsUntouched();
      },
    );

    test('refuses an image containing multiple matching apps', () async {
      await harness.bundle(
        Directory('${harness.volume.path}/One.app'),
        build: 'one',
      );
      await harness.bundle(
        Directory('${harness.volume.path}/Two.app'),
        build: 'two',
      );

      await harness.install();

      expect(
        await File('${harness.application.path}/build.txt').readAsString(),
        'old',
      );
      await harness.expectOtherBackupsUntouched();
    });

    test(
      'restores the old app after promotion fails and keeps other backups',
      () async {
        await harness.bundle(
          Directory('${harness.volume.path}/New.app'),
          build: 'new',
        );

        await harness.install(failPromotion: true);

        expect(
          await File('${harness.application.path}/build.txt').readAsString(),
          'old',
        );
        await harness.expectOtherBackupsUntouched();
      },
    );

    test(
      'retains this attempt backup when restoring the old app also fails',
      () async {
        await harness.bundle(
          Directory('${harness.volume.path}/New.app'),
          build: 'new',
        );

        await harness.install(failPromotion: true, failRestore: true);

        expect(await harness.application.exists(), isFalse);
        final attempts = await harness.directory
            .list()
            .where(
              (entry) =>
                  entry is Directory &&
                  entry.path.startsWith(
                    '${harness.application.path}.update.',
                  ) &&
                  entry.path != '${harness.application.path}.update.untouched',
            )
            .toList();
        expect(attempts, hasLength(1));
        expect(
          await File(
            '${attempts.single.path}/previous.app/build.txt',
          ).readAsString(),
          'old',
        );
        await harness.expectOtherBackupsUntouched();
      },
    );
  }, skip: Platform.isWindows ? 'requires a POSIX shell' : false);
}
