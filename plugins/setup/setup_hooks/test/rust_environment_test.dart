import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../rust_api/hook/cargo_environment.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync('rust_hook_');
  });
  tearDown(() => temporaryDirectory.deleteSync(recursive: true));

  CodeConfig config({
    OS os = OS.android,
    Architecture architecture = Architecture.arm64,
    String? libraryDirectory = 'lib',
  }) {
    final llvm = Directory(p.join(temporaryDirectory.path, 'NDK with spaces'));
    if (libraryDirectory != null) {
      final library = File(p.join(llvm.path, libraryDirectory, 'libclang.dll'));
      library.parent.createSync(recursive: true);
      library.writeAsStringSync('');
    }
    final builder = BuildInputBuilder()
      ..setupShared(
        packageRoot: temporaryDirectory.uri,
        packageName: 'rust_api',
        outputDirectoryShared: temporaryDirectory.uri,
        outputFile: temporaryDirectory.uri.resolve('output.json'),
      )
      ..setupBuildInput()
      ..config.setupBuild(linkingEnabled: false);
    CodeAssetExtension(
      targetArchitecture: architecture,
      targetOS: os,
      linkModePreference: LinkModePreference.dynamic,
      cCompiler: CCompilerConfig(
        compiler: Uri.file(p.join(llvm.path, 'bin', 'clang')),
        archiver: Uri.file(p.join(llvm.path, 'bin', 'llvm-ar')),
        linker: Uri.file(p.join(llvm.path, 'bin', 'ld.lld')),
      ),
      android: os == OS.android ? AndroidCodeConfig(targetNdkApi: 23) : null,
    ).setupBuildInput(builder);
    return builder.build().config.code;
  }

  test('macOS release leaves LINKEDIT alignment to Flutter packaging', () {
    expect(cargoEnvironment(config(os: OS.macOS)), {
      'CARGO_PROFILE_RELEASE_STRIP': 'none',
    });
    expect(cargoEnvironment(config(os: OS.linux)), isEmpty);
  });

  for (final directory in ['lib', 'lib64', 'bin']) {
    test('finds libclang in the NDK $directory directory', () {
      final environment = cargoEnvironment(config(libraryDirectory: directory));
      expect(p.basename(environment['LIBCLANG_PATH']!), directory);
      expect(environment, isNot(contains('PATH')));
    });
  }

  test('Windows can load libclang dependencies from the NDK bin directory', () {
    final environment = cargoEnvironment(
      config(libraryDirectory: 'bin'),
      windowsHost: true,
      hostEnvironment: const {'PATH': 'original-path'},
    );
    expect(environment['PATH'], endsWith('${p.separator}bin;original-path'));
  });

  test('bindgen receives the selected NDK API and quoted sysroot per ABI', () {
    for (final (architecture, triple, clang, include) in [
      (
        Architecture.arm64,
        'aarch64-linux-android',
        'aarch64-linux-android',
        'aarch64-linux-android',
      ),
      (
        Architecture.arm,
        'armv7-linux-androideabi',
        'armv7a-linux-androideabi',
        'arm-linux-androideabi',
      ),
      (
        Architecture.x64,
        'x86_64-linux-android',
        'x86_64-linux-android',
        'x86_64-linux-android',
      ),
    ]) {
      final environment = cargoEnvironment(config(architecture: architecture));
      final args =
          environment['BINDGEN_EXTRA_CLANG_ARGS_${triple.replaceAll('-', '_')}']!;
      expect(args, startsWith('--target=${clang}23 --sysroot="'));
      expect(args, contains('NDK with spaces/sysroot" -I"'));
      expect(args, endsWith('/usr/include/$include"'));
    }
  });

  test('reports an NDK without libclang before invoking Cargo', () {
    expect(
      () => cargoEnvironment(config(libraryDirectory: null)),
      throwsStateError,
    );
  });
}
