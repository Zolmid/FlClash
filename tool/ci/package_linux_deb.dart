import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Builds the Debian package from an already compiled Linux bundle, with the
/// layout and field mapping of flutter_distributor's deb maker
/// (`/opt/<package_name>`, a `/usr/bin` symlink, a desktop entry), so the Helper
/// finds itself at the root-owned path it requires and no second Flutter
/// compile is needed.
class DebFiles {
  const DebFiles({
    required this.control,
    required this.desktop,
    required this.postinst,
    required this.postrm,
  });

  final String control;
  final String desktop;
  final String postinst;
  final String postrm;
}

List<String> _list(Object? value) => [
  for (final item in (value as YamlList?) ?? const []) item.toString(),
];

DebFiles buildDebFiles({
  required YamlMap config,
  required YamlMap pubspec,
  required String architecture,
  required int installedSizeKb,
}) {
  final name = config['package_name'] as String;
  final maintainer = config['maintainer'] as YamlMap;
  final control = <String, String?>{
    'Package': name.toLowerCase(),
    'Version': pubspec['version'] as String,
    'Section': config['section'] as String?,
    'Priority': config['priority'] as String?,
    'Architecture': architecture,
    'Installed-Size': '$installedSizeKb',
    'Maintainer': '${maintainer['name']} <${maintainer['email']}>',
    'Depends': _list(config['dependencies']).join(', '),
    'Recommends': _list(config['recommended_dependencies']).join(', '),
    'Description': (pubspec['description'] as String).replaceAll('\n', ' '),
  };
  String? listed(String key) {
    final value = _list(config[key]);
    return value.isEmpty ? null : '${value.join(';')};';
  }

  final desktop = <String, String?>{
    'Type': 'Application',
    'Name': config['display_name'] as String,
    'GenericName': config['generic_name'] as String?,
    'Icon': name,
    'Exec': '$name %U',
    'Terminal': 'false',
    'MimeType': listed('supported_mime_type'),
    'Categories': listed('categories'),
    'Keywords': listed('keywords'),
    'StartupNotify': config['startup_notify']?.toString(),
    'StartupWMClass': config['startup_wm_class'] as String?,
  };
  String render(Map<String, String?> fields, String separator) => [
    for (final entry in fields.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        '${entry.key}$separator${entry.value}',
  ].join('\n');

  return DebFiles(
    control: '${render(control, ': ')}\n',
    desktop: '[Desktop Entry]\n${render(desktop, '=')}\n',
    postinst: [
      '#!/bin/sh',
      'ln -sf /opt/$name/$name /usr/bin/$name',
      ..._list(config['postinstall_scripts']),
      'exit 0',
      '',
    ].join('\n'),
    postrm: [
      '#!/bin/sh',
      'rm -f /usr/bin/$name',
      ..._list(config['postuninstall_scripts']),
      'exit 0',
      '',
    ].join('\n'),
  );
}

/// Copies the bundle and metadata into a package tree; dpkg-deb builds it.
void stageDebTree({
  required Directory tree,
  required Directory bundle,
  required DebFiles files,
  required String packageName,
  required File icon,
}) {
  final app = Directory(p.join(tree.path, 'opt', packageName))
    ..createSync(recursive: true);
  final copy = Process.runSync('cp', ['-a', '${bundle.path}/.', app.path]);
  if (copy.exitCode != 0) {
    throw StateError('Copying the bundle failed: ${copy.stderr}');
  }
  void write(String relative, String content, {bool executable = false}) {
    final file = File(p.join(tree.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    if (executable) Process.runSync('chmod', ['755', file.path]);
  }

  write('DEBIAN/control', files.control);
  write('DEBIAN/postinst', files.postinst, executable: true);
  write('DEBIAN/postrm', files.postrm, executable: true);
  write('usr/share/applications/$packageName.desktop', files.desktop);
  final iconTarget = File(
    p.join(
      tree.path,
      'usr/share/icons/hicolor/1024x1024/apps',
      '$packageName.png',
    ),
  )..createSync(recursive: true);
  icon.copySync(iconTarget.path);
  Process.runSync('chmod', ['-R', 'u=rwX,go=rX', tree.path]);
}

int directorySizeKb(Directory directory) {
  var bytes = 0;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File) bytes += entity.lengthSync();
  }
  return (bytes / 1024).ceil();
}

Future<void> main(List<String> arguments) async {
  final parsed =
      (ArgParser()
            ..addOption('bundle', mandatory: true)
            ..addOption('out', mandatory: true)
            ..addOption('architecture', defaultsTo: 'amd64'))
          .parse(arguments);
  final bundle = Directory(parsed['bundle'] as String);
  final config =
      loadYaml(File('linux/packaging/deb/make_config.yaml').readAsStringSync())
          as YamlMap;
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final packageName = config['package_name'] as String;
  final tree = Directory.systemTemp.createTempSync('zolnit-deb-');
  try {
    stageDebTree(
      tree: tree,
      bundle: bundle,
      files: buildDebFiles(
        config: config,
        pubspec: pubspec,
        architecture: parsed['architecture'] as String,
        installedSizeKb: directorySizeKb(bundle),
      ),
      packageName: packageName,
      icon: File(config['icon'] as String),
    );
    final build = await Process.run('dpkg-deb', [
      '--build',
      '--root-owner-group',
      tree.path,
      parsed['out'] as String,
    ]);
    stdout.write(build.stdout);
    stderr.write(build.stderr);
    exitCode = build.exitCode;
  } finally {
    tree.deleteSync(recursive: true);
  }
}
