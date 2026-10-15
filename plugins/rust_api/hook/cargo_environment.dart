import 'dart:io';

import 'package:code_assets/code_assets.dart';

Map<String, String> cargoEnvironment(
  CodeConfig code, {
  bool? windowsHost,
  Map<String, String>? hostEnvironment,
}) {
  if (code.targetOS == OS.iOS) {
    return _iosEnvironment(code);
  }
  if (code.targetOS == OS.macOS) {
    // Rust stripping can misalign Mach-O LINKEDIT (rust-lang/rust#157750).
    return const {'CARGO_PROFILE_RELEASE_STRIP': 'none'};
  }
  if (code.targetOS != OS.android) return const {};
  final compiler = code.cCompiler?.compiler;
  if (compiler == null) return const {};
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64', 'bin']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      final triple = _androidRustTriple(code.targetArchitecture);
      final clangTriple = code.targetArchitecture == Architecture.arm
          ? 'armv7a-linux-androideabi'
          : triple;
      final includeTriple = code.targetArchitecture == Architecture.arm
          ? 'arm-linux-androideabi'
          : triple;
      final sysroot = '${llvmRoot.path}/sysroot'.replaceAll(r'\', '/');
      return {
        'LIBCLANG_PATH': directory.path,
        'BINDGEN_EXTRA_CLANG_ARGS_${triple.replaceAll('-', '_')}':
            '--target=$clangTriple${code.android.targetNdkApi} '
            '--sysroot="$sysroot" -I"$sysroot/usr/include/$includeTriple"',
        if (windowsHost ?? Platform.isWindows)
          'PATH':
              '${llvmRoot.path}${Platform.pathSeparator}bin;'
              '${(hostEnvironment ?? Platform.environment)['PATH'] ?? ''}',
      };
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib, lib64, or bin); '
    'the NDK Flutter passed cannot run bindgen for rquickjs',
  );
}

Map<String, String> _iosEnvironment(CodeConfig code) {
  final sdk = code.iOS.targetSdk == IOSSdk.iPhoneOS
      ? 'iphoneos'
      : 'iphonesimulator';
  String xcrun(List<String> args) {
    final command = ['--sdk', sdk, ...args];
    final result = Process.runSync('xcrun', command);
    if (result.exitCode != 0) {
      throw ProcessException(
        'xcrun',
        command,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return (result.stdout as String).trim();
  }

  final sdkPath = xcrun(['--show-sdk-path']);
  final clang = xcrun(['--find', 'clang']);
  return {
    'LIBCLANG_PATH': '${File(clang).parent.parent.path}/lib',
    'BINDGEN_EXTRA_CLANG_ARGS': '-isysroot "$sdkPath"',
    'IPHONEOS_DEPLOYMENT_TARGET': '${code.iOS.targetVersion}.0',
    'CARGO_PROFILE_RELEASE_STRIP': 'none',
  };
}

bool _isLibclang(FileSystemEntity entity) =>
    entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');

String _androidRustTriple(Architecture architecture) => switch (architecture) {
  Architecture.arm64 => 'aarch64-linux-android',
  Architecture.arm => 'armv7-linux-androideabi',
  Architecture.x64 => 'x86_64-linux-android',
  _ => throw StateError('No Android Rust triple for $architecture'),
};
