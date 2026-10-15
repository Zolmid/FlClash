import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('macos', null), 'dmg');
    });

    test('parses iOS bundle identifier override', () {
      final results = setup.createSetupArgParser().parse([
        'ios',
        '--ios-bundle-id',
        'com.example.flclash',
      ]);

      expect(results['ios-bundle-id'], 'com.example.flclash');
      expect(results.rest, ['ios']);
    });

    test('parses unsigned iOS packaging mode', () {
      final results = setup.createSetupArgParser().parse([
        'ios',
        '--no-codesign',
      ]);

      expect(results['no-codesign'], isTrue);
      expect(results.rest, ['ios']);
    });

    test('derives no-sign signing targets from their names', () {
      final targets = setup.createIOSNoSignSigningTargets(
        rootDir: p.join('workspace', 'flclash'),
        appBundlePath: p.join('build', 'Runner.app'),
        appBundleId: 'com.example.flclash',
      );

      expect(targets, [
        (
          bundle: p.join('build', 'Runner.app', 'PlugIns', 'NECore.appex'),
          bundleIdentifier: 'com.example.flclash.NECore',
          entitlements: p.join(
            'workspace',
            'flclash',
            'ios',
            'NECore',
            'NECore.entitlements',
          ),
        ),
        (
          bundle: p.join('build', 'Runner.app', 'PlugIns', 'Widget.appex'),
          bundleIdentifier: 'com.example.flclash.Widget',
          entitlements: p.join(
            'workspace',
            'flclash',
            'ios',
            'Widget',
            'Widget.entitlements',
          ),
        ),
        (
          bundle: p.join('build', 'Runner.app'),
          bundleIdentifier: 'com.example.flclash',
          entitlements: p.join(
            'workspace',
            'flclash',
            'ios',
            'Runner',
            'Runner.entitlements',
          ),
        ),
      ]);
    });

    test('creates matching application and app group identifiers', () {
      const source = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.\$(APP_BUNDLE_ID)</string>
  </array>
</dict>
</plist>
''';

      final content = setup.createIOSNoSignEntitlements(
        source: source,
        appBundleId: 'com.example.flclash',
        bundleIdentifier: 'com.example.flclash.NECore',
        teamIdentifier: 'ABCDE12345',
      );
      final document = XmlDocument.parse(content);
      final elements = document.rootElement
          .getElement('dict')!
          .childElements
          .toList();
      final values = <String, String>{};
      for (var index = 0; index + 1 < elements.length; index++) {
        if (elements[index].name.local == 'key') {
          values[elements[index].innerText] = elements[index + 1].innerText
              .trim();
        }
      }

      expect(
        values['application-identifier'],
        'ABCDE12345.com.example.flclash.NECore',
      );
      expect(values['com.apple.developer.team-identifier'], 'ABCDE12345');
      expect(
        values['com.apple.security.application-groups'],
        'group.com.example.flclash',
      );
    });

    test('falls back to unknown when replacing identity entitlements', () {
      const source = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>OLD.identifier</string>
  <key>com.apple.developer.team-identifier</key>
  <string>OLDTEAM</string>
</dict>
</plist>
''';

      final content = setup.createIOSNoSignEntitlements(
        source: source,
        appBundleId: 'com.example.flclash',
        bundleIdentifier: 'com.example.flclash',
      );

      expect(
        RegExp('<key>application-identifier</key>').allMatches(content),
        hasLength(1),
      );
      expect(content, contains('UNKNOWN000.com.example.flclash'));
      expect(
        content,
        contains(
          '<key>com.apple.developer.team-identifier</key>\n'
          '\t\t<string>UNKNOWN000</string>',
        ),
      );
      expect(content, isNot(contains('OLD.identifier')));
      expect(content, isNot(contains('OLDTEAM')));
    });

    test('writes generated iOS bundle config', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'flclash_setup_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await setup.writeIOSGeneratedBundleConfig(
        tempDir.path,
        'com.example.flclash',
        'ABCDE12345',
      );

      final configFile = File(
        p.join(
          tempDir.path,
          'ios',
          'Flutter',
          'GeneratedBundleConfig.xcconfig',
        ),
      );
      final content = await configFile.readAsString();
      expect(content, contains('APP_BUNDLE_ID = com.example.flclash'));
      expect(content, contains('DEVELOPMENT_TEAM = ABCDE12345'));
    });

    test('iOS export options override the default export method', () {
      expect(setup.createPackageTargets('ios', null), 'ipa');
      expect(setup.createFlutterBuildArgs(platform: 'ios', verbose: false), [
        'dart-define-from-file=env.json',
        'export-method=app-store',
      ]);
      expect(
        setup.createFlutterBuildArgs(
          platform: 'ios',
          verbose: true,
          iosExportMethod: 'development',
          iosExportOptionsPlist: 'ios/CIExportOptions.plist',
        ),
        [
          'verbose',
          'dart-define-from-file=env.json',
          'export-options-plist=ios/CIExportOptions.plist',
        ],
      );
    });

    test(
      'normalizes architecture names and rejects cross-host desktop builds',
      () {
        final v3 = setup.resolvePackageArchitecture(
          platform: 'windows',
          requested: 'x64-v3',
          hostArch: 'amd64',
        );
        expect(v3.name, 'x64-v3');
        expect(v3.flutterArch, 'x64');
        expect(v3.goamd64, 'v3');
        expect(setup.parsePackageArchitecture('amd64').name, 'x64');
        expect(setup.parsePackageArchitecture('amd64-v2').goamd64, 'v2');
        expect(
          () => setup.resolvePackageArchitecture(
            platform: 'linux',
            requested: 'arm64',
            hostArch: 'x64',
          ),
          throwsArgumentError,
        );
        expect(
          () => setup.resolvePackageArchitecture(
            platform: 'android',
            requested: 'x64-v3',
            hostArch: 'x64',
          ),
          throwsArgumentError,
        );
        expect(
          () => setup.resolvePackageArchitecture(
            platform: 'ios',
            requested: 'arm64',
            hostArch: 'arm64',
          ),
          throwsArgumentError,
        );
      },
    );

    test('records the actual package architecture for update selection', () {
      expect(setup.createBuildEnvironment('stable', arch: 'x64-v3'), {
        'APP_ENV': 'stable',
        'APP_ARCH': 'x64-v3',
      });
      expect(
        () => setup.createBuildEnvironment('stable', arch: 'x64-v4'),
        throwsArgumentError,
      );
    });

    test(
      'GOAMD64 overrides preserve CRLF and restore pubspec after failure',
      () async {
        const original =
            'name: x\r\nhooks:\r\n  user_defines:\r\n'
            '    setup:\r\n      build_assets: true\r\n';
        expect(
          setup.pubspecWithGoAmd64(original, 'v3'),
          contains('      goamd64: v3\r\n'),
        );
        final directory = await Directory.systemTemp.createTemp('setup_cpu_');
        addTearDown(() => directory.delete(recursive: true));
        final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
        await pubspec.writeAsString(original);
        await expectLater(
          setup.withGoAmd64UserDefine(directory.path, 'v3', () async {
            expect(await pubspec.readAsString(), contains('goamd64: v3'));
            throw StateError('failed package');
          }),
          throwsStateError,
        );
        expect(await pubspec.readAsString(), original);
      },
    );

    test(
      'Windows updates require the parent nonce acknowledgement before exit or replacement',
      () {
        final script = File(
          'windows/packaging/exe/inno_setup.iss',
        ).readAsStringSync();
        final prepare = script.substring(
          script.indexOf('function PrepareToInstall('),
          script.indexOf('procedure CurStepChanged('),
        );
        expect(
          prepare.indexOf('SignalUpdateReady'),
          lessThan(prepare.indexOf('WaitForParentAcknowledgement')),
        );
        expect(
          prepare.indexOf('WaitForParentAcknowledgement'),
          lessThan(prepare.indexOf('WaitForAppExit')),
        );
        expect(
          prepare.indexOf('WaitForAppExit'),
          lessThan(prepare.indexOf('UnregisterHelperService')),
        );
        expect(prepare, contains('if not SignalUpdateReady then'));
        expect(prepare, contains('if not WaitForParentAcknowledgement then'));
        expect(prepare, contains('if not WaitForAppExit then'));
        expect(
          script,
          contains("ExpandConstant('{srcexe}') + '.' + Nonce + '.ready'"),
        );
        expect(script, contains("TemporaryReadyFile := ReadyFile + '.tmp';"));
        expect(
          script,
          contains('Flags: runasoriginaluser nowait; Check: IsAppUpdate'),
        );
        expect(script, contains("ExpandConstant('{param:UPDATENONCE|}')"));
        expect(script, contains("ExpandConstant('{param:UPDATEPID|}')"));
        expect(
          script,
          contains('WaitForSingleObject(UpdateProcessHandle, 60000)'),
        );
        expect(prepare, contains('if not IsAppUpdate then\n    KillProcesses'));
        expect(
          script,
          contains(
            'WriteReadyFile(ReadyHandle, AnsiString(Nonce), Length(Nonce),',
          ),
        );
        expect(script, contains('RenameFile(TemporaryReadyFile, ReadyFile)'));
        expect(script, contains('CloseApplications=no'));
        final signal = script.substring(
          script.indexOf('function SignalUpdateReady'),
          script.indexOf('function WaitForAppExit'),
        );
        expect(
          signal.indexOf('QueryFullProcessImageName'),
          lessThan(signal.indexOf('WriteReadyFile')),
        );
        expect(
          signal.indexOf('CloseHandle(ReadyHandle)'),
          lessThan(signal.indexOf('RenameFile')),
        );
        expect(
          signal,
          contains(
            r'CreateReadyFile(TemporaryReadyFile, $40000000, 0, 0, 1, $80, 0)',
          ),
        );

        final acknowledgement = script.substring(
          script.indexOf('function WaitForParentAcknowledgement'),
          script.indexOf('function WaitForAppExit'),
        );
        expect(
          acknowledgement,
          contains("ExpandConstant('{param:UPDATEREADY|}') + '.ack'"),
        );
        expect(signal, contains("FileExists(ReadyFile + '.ack')"));
        expect(acknowledgement, contains('Result := False;'));
        expect(acknowledgement, contains('for i := 1 to 150 do'));
        expect(acknowledgement, contains('String(Contents) = Nonce'));
        expect(
          acknowledgement,
          contains('WaitForSingleObject(UpdateProcessHandle, 0) <> 258'),
        );
        expect(
          acknowledgement.indexOf('FileExists(AcknowledgementFile)'),
          lessThan(acknowledgement.indexOf('WaitForSingleObject')),
        );
        expect(script, isNot(contains('tasklist /FI')));
      },
    );

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
