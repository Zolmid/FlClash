import 'dart:io';

import 'package:flutter_app_packager/src/makers/exe/app_package_maker_exe.dart';
import 'package:path/path.dart' as p;

Future<void> compileInstaller({
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
    // The provider getter creates staging before ownership can be checked.
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

Future<void> main(List<String> arguments) async {
  if (!Platform.isWindows || arguments.isNotEmpty) {
    stderr.writeln('Run this compile-only check on Windows without arguments.');
    exitCode = 64;
    return;
  }
  try {
    await compileInstaller(
      repository: Directory.fromUri(Platform.script.resolve('../../../../../')),
    );
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
