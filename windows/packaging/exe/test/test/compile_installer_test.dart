import 'dart:io';

import 'package:flutter_app_packager/src/api/app_package_maker.dart';
import 'package:flutter_app_packager/src/makers/exe/app_package_maker_exe.dart';
import 'package:flutter_app_packager/src/makers/exe/make_exe_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/compile_installer.dart' as validation;

class _Maker extends AppPackageMakerExe {
  bool fail = false;
  MakeExeConfig? captured;

  @override
  Future<MakeResult> make(MakeConfig config) async {
    captured = config as MakeExeConfig;
    config.packagingDirectory.createSync(recursive: true);
    File('${config.packagingDirectory.path}.iss').writeAsStringSync('script');
    config.outputFile.writeAsStringSync('compile-only fixture');
    if (fail) throw StateError('compiler failed');
    return MakeResult(config);
  }
}

void main() {
  late Directory repository;
  late Directory previousDirectory;

  setUp(() {
    previousDirectory = Directory.current;
    repository = Directory(
      Directory.systemTemp
          .createTempSync('installer_compile_test_')
          .resolveSymbolicLinksSync(),
    );
    File(
      p.join(repository.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: fl_clash\nversion: 1.0.0+1\n');
    final config = File(
      p.join(repository.path, 'windows/packaging/exe/make_config.yaml'),
    );
    config.parent.createSync(recursive: true);
    config.writeAsStringSync(
      'app_id: test-installation\n'
      'executable_name: ZolNit.exe\n'
      'script_template: inno_setup.iss\n',
    );
    final executable = File(
      p.join(repository.path, 'build/windows/x64/runner/Release/ZolNit.exe'),
    );
    executable.parent.createSync(recursive: true);
    executable.writeAsStringSync('existing Flutter bundle');
    final retained = File(p.join(repository.path, 'dist/existing.zip'));
    retained.parent.createSync(recursive: true);
    retained.writeAsStringSync('keep');
  });

  tearDown(() {
    expect(Directory.current.path, previousDirectory.path);
    repository.deleteSync(recursive: true);
  });

  for (final fail in [false, true]) {
    test(
      'real config loader preserves bundle and cleans owned outputs $fail',
      () async {
        final maker = _Maker()..fail = fail;
        final result = validation.compileInstaller(
          repository: repository,
          maker: maker,
        );
        if (fail) {
          await expectLater(result, throwsStateError);
        } else {
          await result;
        }
        final config = maker.captured!;
        expect(config.arch, 'x64');
        expect(config.buildMode, 'release');
        expect(config.platform, 'windows');
        expect(config.packageFormat, 'exe');
        expect(config.isInstaller, isTrue);
        expect(config.appId, 'test-installation');
        expect(config.outputDirectory.path, p.join(repository.path, 'dist'));
        expect(config.buildOutputFiles, hasLength(1));
        expect(p.basename(config.buildOutputFiles.single.path), 'ZolNit.exe');
        expect(
          config.buildOutputDirectory.path,
          p.join(repository.path, 'build/windows/x64/runner/Release'),
        );
        expect(
          config.buildOutputFiles.single.readAsStringSync(),
          'existing Flutter bundle',
        );
        expect(
          Directory(
            p.join(repository.path, 'dist'),
          ).listSync().map((entity) => p.basename(entity.path)),
          ['existing.zip'],
        );
      },
    );
  }

  test('missing Release bundle fails before invoking the provider', () async {
    Directory(p.join(repository.path, 'build')).deleteSync(recursive: true);
    final maker = _Maker();
    await expectLater(
      validation.compileInstaller(repository: repository, maker: maker),
      throwsStateError,
    );
    expect(maker.captured, isNull);
    expect(Directory(p.join(repository.path, 'dist')).listSync(), hasLength(1));
  });

  test('retainAs copies the compiled EXE and still cleans staging', () async {
    final maker = _Maker();
    final retained = p.join(
      repository.path,
      'dist/ZolNit-1.0.0-windows-x64-setup.exe',
    );
    await validation.compileInstaller(
      repository: repository,
      retainAs: retained,
      maker: maker,
    );
    final distFiles = Directory(
      p.join(repository.path, 'dist'),
    ).listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(distFiles, ['ZolNit-1.0.0-windows-x64-setup.exe', 'existing.zip']);
    expect(File(retained).readAsStringSync(), 'compile-only fixture');
  });

  test('retainAs refuses when destination already exists', () async {
    final maker = _Maker();
    final retained = p.join(repository.path, 'dist/existing.zip');
    await expectLater(
      validation.compileInstaller(
        repository: repository,
        retainAs: retained,
        maker: maker,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        ),
      ),
    );
  });

  test('retainAs refuses path outside the repository', () async {
    final maker = _Maker();
    final outside = p.join(Directory.systemTemp.path, 'escape.exe');
    await expectLater(
      validation.compileInstaller(
        repository: repository,
        retainAs: outside,
        maker: maker,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('inside the repository'),
        ),
      ),
    );
    expect(File(outside).existsSync(), isFalse);
  });
}
