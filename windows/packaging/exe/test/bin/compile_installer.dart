import 'dart:io';

import 'package:flutter_app_packager/src/makers/exe/app_package_maker_exe.dart';
import 'package:path/path.dart' as p;

Future<void> compileInstaller({
  String? retainAs,
  required Directory repository,
  AppPackageMakerExe? maker,
}) async {
  final previousDirectory = Directory.current;
  final lease = await Directory.systemTemp.createTemp(
    'flclash_installer_validation_',
  );
  final owned = <FileSystemEntity>[];
  try {
    Directory.current = repository;
    final bundle = Directory('build/windows/x64/runner/Release').absolute;
    final executable = File(p.join(bundle.path, 'ZolNit.exe'));
    if (!await executable.exists()) {
      throw StateError('Compile the Windows Release bundle first');
    }
    final selectedMaker = maker ?? AppPackageMakerExe();
    final config = selectedMaker.configLoader.load(
      {
        'arch': 'x64',
        'build_mode': 'release',
        'artifact_name': '${p.basename(lease.path)}.exe',
      },
      Directory('dist').absolute,
      buildOutputDirectory: bundle,
      buildOutputFiles: [executable],
    );
    final output = config.outputFile;
    final packagingPath = output.path.replaceAll('.exe', '_exe');
    final candidates = <FileSystemEntity>[
      output,
      Directory(packagingPath),
      File('$packagingPath.iss'),
    ];
    for (final entity in candidates) {
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Validation output already exists: ${entity.path}');
      }
    }
    owned.addAll(candidates);
    final result = await selectedMaker.make(config);
    if (!await output.exists() ||
        await output.length() == 0 ||
        result.artifacts.length != 1 ||
        !p.equals(
          result.artifacts.single.absolute.path,
          output.absolute.path,
        )) {
      throw StateError(
        'Inno Setup did not produce the expected validation EXE',
      );
    }
    if (retainAs != null) {
      final destination = File(retainAs);
      if (!p.isWithin(repository.absolute.path, destination.absolute.path)) {
        throw StateError('Retention path must be inside the repository');
      }
      if (await destination.exists()) {
        throw StateError(
          'Retention destination already exists: ${destination.path}',
        );
      }
      await destination.parent.create(recursive: true);
      await output.copy(destination.path);
    }
    stdout.writeln('Inno Setup compile-only validation passed.');
  } finally {
    try {
      for (final entity in owned.reversed) {
        if (await FileSystemEntity.type(entity.path, followLinks: false) ==
            FileSystemEntityType.link) {
          await Link(entity.path).delete();
        } else if (await entity.exists()) {
          await entity.delete(recursive: true);
        }
      }
    } finally {
      Directory.current = previousDirectory;
      await lease.delete(recursive: true);
    }
  }
}

String? _retainPath(Directory repository, List<String> arguments) {
  if (arguments.isEmpty) return null;
  if (arguments.length == 1 && arguments.single == '--retain') {
    final pubspec = File(p.join(repository.path, 'pubspec.yaml'));
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    if (match == null) throw StateError('Cannot read version from pubspec');
    final version = match.group(1)!.split('+').first;
    return p.join(
      repository.path,
      'dist',
      'ZolNit-$version-windows-x64-setup.exe',
    );
  }
  if (arguments.length == 1) return arguments.single;
  throw StateError('Usage: compile_installer [--retain | <output-path>]');
}

Future<void> main(List<String> arguments) async {
  if (!Platform.isWindows) {
    stderr.writeln('Run this compile-only check on Windows.');
    exitCode = 64;
    return;
  }
  final repository = Directory.fromUri(
    Platform.script.resolve('../../../../../'),
  );
  try {
    await compileInstaller(
      repository: repository,
      retainAs: _retainPath(repository, arguments),
    );
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
