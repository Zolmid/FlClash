import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../tool/ci/package_linux_deb.dart';

void main() {
  final config =
      loadYaml(File('linux/packaging/deb/make_config.yaml').readAsStringSync())
          as YamlMap;
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final files = buildDebFiles(
    config: config,
    pubspec: pubspec,
    architecture: 'amd64',
    installedSizeKb: 4096,
  );

  test('control names a lowercase package at the pubspec version', () {
    expect(files.control, contains('Package: zolnit\n'));
    expect(files.control, contains('Version: ${pubspec['version']}\n'));
    expect(files.control, contains('Architecture: amd64\n'));
    expect(files.control, contains('Maintainer: Zolmid <zolmid@icloud.com>\n'));
    expect(files.control, contains('libsecret-1-0'));
    expect(files.control, isNot(contains('chen08209')));
  });

  test('desktop entry opens the registered URL scheme', () {
    expect(files.desktop, contains('Exec=ZolNit %U\n'));
    expect(files.desktop, contains('MimeType=x-scheme-handler/zolnit;\n'));
    expect(files.desktop, contains('StartupWMClass=com.zolmid.zolnit\n'));
  });

  test('maintainer scripts link the binary and keep the uninstall guard', () {
    expect(
      files.postinst,
      contains('ln -sf /opt/ZolNit/ZolNit /usr/bin/ZolNit'),
    );
    expect(files.postrm, contains('rm -f /usr/bin/ZolNit'));
    expect(
      files.postrm.indexOf('remove|purge'),
      lessThan(
        files.postrm.indexOf('systemctl disable --now zolnit-helper.service'),
      ),
    );
  });

  test('the tree places the Helper at the root-owned install path', () {
    final scratch = Directory.systemTemp.createTempSync('zolnit-deb-test-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final bundle = Directory(p.join(scratch.path, 'bundle'))..createSync();
    for (final name in ['ZolNit', 'FlClashCore', 'ZolNitHelperService']) {
      File(p.join(bundle.path, name)).writeAsStringSync(name);
      Process.runSync('chmod', ['755', p.join(bundle.path, name)]);
    }
    final tree = Directory(p.join(scratch.path, 'tree'))..createSync();
    stageDebTree(
      tree: tree,
      bundle: bundle,
      files: files,
      packageName: 'ZolNit',
      icon: File(config['icon'] as String),
    );
    final helper = File(p.join(tree.path, 'opt/ZolNit/ZolNitHelperService'));
    expect(helper.existsSync(), isTrue);
    expect(helper.statSync().mode & 0x49, 0x49);
    expect(helper.statSync().mode & 0x12, 0);
    expect(
      File(p.join(tree.path, 'DEBIAN/postinst')).statSync().mode & 0x40,
      0x40,
    );
    expect(
      File(
        p.join(tree.path, 'usr/share/icons/hicolor/1024x1024/apps/ZolNit.png'),
      ).existsSync(),
      isTrue,
    );
  });
}
