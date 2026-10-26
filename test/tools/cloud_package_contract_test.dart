import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

String _step(String name) {
  final workflow =
      loadYaml(File('.github/workflows/cloud-build.yml').readAsStringSync())
          as YamlMap;
  final steps = workflow['jobs']['project']['steps'] as YamlList;
  return (steps.cast<YamlMap>().singleWhere((s) => s['name'] == name)['run']
          as String)
      .replaceAll(r'${{ steps.version.outputs.package }}', '0.9.1');
}

class _Fixture {
  _Fixture() {
    runner.createSync();
    for (final name in ['apksigner', 'aapt2']) {
      final file = File(p.join(sdk.path, 'build-tools', '36.0.0', name));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        name == 'apksigner'
            ? r'''#!/bin/bash
set -eu
if [[ " $* " != *" --verbose "* ]]; then exit 1; fi
if [[ "${APK_TEST_UNSIGNED:-false}" == true ]]; then exit 1; fi
echo 'Verified using v2 scheme: true'
echo 'Signer certificate SHA-256 digest: synthetic-fixture'
'''
            : r'''#!/bin/bash
set -eu
printf "package: name='%s' versionCode='1' versionName='%s'\n" "${APK_TEST_ID:-com.zolmid.zolnit}" "${APK_TEST_VERSION:-0.9.1}"
if [[ "${APK_TEST_DEBUG:-false}" == true ]]; then echo application-debuggable; fi
''',
      );
      final chmod = Process.runSync('chmod', ['+x', file.path]);
      if (chmod.exitCode != 0) throw StateError('Fixture chmod failed');
    }
    for (final mode in ['release', 'debug']) {
      final file = File(
        p.join(root.path, 'build/app/outputs/flutter-apk/app-$mode.apk'),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('synthetic-$mode-apk');
    }
  }

  final root = Directory.systemTemp.createTempSync('zolnit-workflow-contract-');
  late final runner = Directory(p.join(root.path, 'runner'));
  late final sdk = Directory(p.join(root.path, 'sdk'));
  late final jobEnv = File(p.join(root.path, 'job-env'));

  Map<String, String> get signing => {
    'ZOLNIT_ANDROID_KEYSTORE_BASE64': base64Encode(
      utf8.encode('synthetic-keystore'),
    ),
    'ZOLNIT_ANDROID_KEYSTORE_PASSWORD': 'fixture-store-value',
    'ZOLNIT_ANDROID_KEY_ALIAS': 'fixture-alias',
    'ZOLNIT_ANDROID_KEY_PASSWORD': 'fixture-key-value',
  };

  Future<ProcessResult> run(
    String name, [
    Map<String, String> environment = const {},
  ]) => Process.run(
    'bash',
    ['-e', '-u', '-o', 'pipefail', '-c', _step(name)],
    workingDirectory: root.path,
    environment: {
      'RUNNER_TEMP': runner.path,
      'ANDROID_HOME': sdk.path,
      'GITHUB_ENV': jobEnv.path,
      'ANDROID_RELEASE': 'true',
      ...environment,
    },
  );

  void dispose() => root.deleteSync(recursive: true);
}

void main() {
  late _Fixture fixture;
  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.dispose());

  for (final missing in [
    'ZOLNIT_ANDROID_KEYSTORE_BASE64',
    'ZOLNIT_ANDROID_KEYSTORE_PASSWORD',
    'ZOLNIT_ANDROID_KEY_ALIAS',
    'ZOLNIT_ANDROID_KEY_PASSWORD',
  ]) {
    test('missing $missing never materializes signing data', () async {
      final result = await fixture.run('Provision Android release signing', {
        ...fixture.signing,
        missing: '',
        'KEYSTORE': 'legacy-value',
      });
      expect(result.exitCode, isNot(0));
      expect(fixture.runner.listSync(), isEmpty);
      expect(result.stdout, isNot(contains('fixture-store-value')));
    }, testOn: '!windows');
  }

  test('signing staging is private and cleanup preserves other data', () async {
    final result = await fixture.run(
      'Provision Android release signing',
      fixture.signing,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final env = {
      for (final line in fixture.jobEnv.readAsLinesSync())
        line.split('=').first: line.substring(line.indexOf('=') + 1),
    };
    final store = File(env['ZOLNIT_ANDROID_KEYSTORE_PATH']!);
    expect(store.readAsStringSync(), 'synthetic-keystore');
    expect(store.statSync().mode & 0x1ff, 0x180);
    final sentinel = File(p.join(fixture.runner.path, 'keep'))
      ..writeAsStringSync('keep');
    expect(
      (await fixture.run('Clean Android signing material', env)).exitCode,
      0,
    );
    expect(store.existsSync(), isFalse);
    expect(sentinel.readAsStringSync(), 'keep');
  }, testOn: '!windows');

  test('cleanup cannot delete a directory outside its signing scope', () async {
    final protected = Directory(p.join(fixture.root.path, 'protected'))
      ..createSync();
    final file = File(p.join(protected.path, 'keep'))
      ..writeAsStringSync('keep');
    expect(
      (await fixture.run('Clean Android signing material', {
        'ZOLNIT_SIGNING_DIR': protected.path,
      })).exitCode,
      0,
    );
    expect(file.readAsStringSync(), 'keep');
  }, testOn: '!windows');

  final cases = <String, Map<String, String>>{
    'valid release': {},
    'unsigned': {'APK_TEST_UNSIGNED': 'true'},
    'wrong identity': {'APK_TEST_ID': 'com.follow.clash'},
    'debuggable': {'APK_TEST_DEBUG': 'true'},
    'wrong version': {'APK_TEST_VERSION': '9.9.9'},
  };
  for (final entry in cases.entries) {
    test('canonical APK collection validates ${entry.key}', () async {
      final result = await fixture.run('Collect Android APK', entry.value);
      final valid = entry.key == 'valid release';
      expect(
        result.exitCode == 0,
        valid,
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(
        File(
          p.join(fixture.root.path, 'dist/ZolNit-0.9.1-android-arm64-v8a.apk'),
        ).existsSync(),
        valid,
      );
    }, testOn: '!windows');
  }

  test('debug APK keeps its development filename', () async {
    final result = await fixture.run('Collect Android APK', {
      'ANDROID_RELEASE': 'false',
    });
    expect(result.exitCode, 0);
    expect(
      File(
        p.join(fixture.root.path, 'dist/FlClash-android-arm64-development.apk'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(fixture.root.path, 'dist/ZolNit-0.9.1-android-arm64-v8a.apk'),
      ).existsSync(),
      isFalse,
    );
  }, testOn: '!windows');
}
