import 'dart:io';

import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('calcSha256', () {
    test('returns correct hash for known content', () async {
      final tmp = File(
        '${Directory.systemTemp.path}/setup_hooks_test_sha256.txt',
      );
      tmp.writeAsStringSync('hello');
      try {
        final hash = await calcSha256(tmp.path);
        expect(
          hash,
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
        );
      } finally {
        tmp.deleteSync();
      }
    });

    test('throws BuildException for missing file', () async {
      expect(
        calcSha256('/nonexistent/path/file.bin'),
        throwsA(isA<BuildException>()),
      );
    });
  });

  group('writeCoreManifest', () {
    test('writes only the Core SHA256 field', () {
      final directory = Directory.systemTemp.createTempSync(
        'setup_hooks_manifest_test_',
      );
      final path = '${directory.path}/manifest.json';
      const hash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      try {
        writeCoreManifest(path: path, coreSha256: hash);

        expect(File(path).readAsStringSync(), '{"coreSha256":"$hash"}\n');
      } finally {
        directory.deleteSync(recursive: true);
      }
    });

    test('replaces an existing manifest', () {
      final directory = Directory.systemTemp.createTempSync(
        'setup_hooks_manifest_test_',
      );
      final path = '${directory.path}/manifest.json';
      const oldHash =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const newHash =
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
      try {
        File(path).writeAsStringSync('{"coreSha256":"$oldHash"}\n');

        writeCoreManifest(path: path, coreSha256: newHash);

        expect(File(path).readAsStringSync(), '{"coreSha256":"$newHash"}\n');
      } finally {
        directory.deleteSync(recursive: true);
      }
    });

    test('rejects an invalid Core SHA256', () {
      expect(
        () => writeCoreManifest(path: '/tmp/manifest.json', coreSha256: 'bad'),
        throwsA(isA<BuildException>()),
      );
    });
  });

  group('ensureDir', () {
    test('creates directory recursively', () {
      final tmp = '${Directory.systemTemp.path}/setup_hooks_test_dir/a/b/c';
      try {
        ensureDir(tmp);
        expect(Directory(tmp).existsSync(), isTrue);
      } finally {
        Directory(
          '${Directory.systemTemp.path}/setup_hooks_test_dir',
        ).deleteSync(recursive: true);
      }
    });
  });

  group('copyFile', () {
    test('copies file to destination', () {
      final src = File('${Directory.systemTemp.path}/setup_hooks_test_src.txt');
      final dest =
          '${Directory.systemTemp.path}/setup_hooks_test_dest/sub/file.txt';
      src.writeAsStringSync('content');
      try {
        copyFile(src.path, dest);
        expect(File(dest).existsSync(), isTrue);
        expect(File(dest).readAsStringSync(), 'content');
      } finally {
        src.deleteSync();
        Directory(
          '${Directory.systemTemp.path}/setup_hooks_test_dest',
        ).deleteSync(recursive: true);
      }
    });

    test('throws BuildException for missing source', () {
      expect(
        () => copyFile('/nonexistent/file.txt', '/tmp/out.txt'),
        throwsA(isA<BuildException>()),
      );
    });
  });
  test(
    'replacement with a missing staged file preserves the prior outputs',
    () {
      final dir = Directory.systemTemp.createTempSync('setup_replace_');
      try {
        final old = File('${dir.path}/old')..writeAsStringSync('previous');
        final staged = File('${dir.path}/staged')..writeAsStringSync('new');
        expect(
          () => replaceFiles({
            staged.path: old.path,
            '${dir.path}/missing': '${dir.path}/header',
          }),
          throwsA(isA<BuildException>()),
        );
        expect(old.readAsStringSync(), 'previous');
        expect(staged.readAsStringSync(), 'new');
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );
  test('a failed second replacement restores the first output', () {
    final dir = Directory.systemTemp.createTempSync('setup_replace_');
    try {
      final old = File('${dir.path}/old')..writeAsStringSync('previous');
      old.setLastModifiedSync(DateTime.utc(2020));
      final before = old.statSync();
      final first = File('${dir.path}/first')..writeAsStringSync('new');
      final second = File('${dir.path}/second')..writeAsStringSync('header');
      final blocked = Directory('${dir.path}/blocked')..createSync();
      expect(
        () => replaceFiles({first.path: old.path, second.path: blocked.path}),
        throwsA(isA<FileSystemException>()),
      );
      expect(old.readAsStringSync(), 'previous');
      expect(old.statSync().modified, before.modified);
      expect(old.statSync().mode, before.mode);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
  test('a complete output group replaces both files', () {
    final dir = Directory.systemTemp.createTempSync('setup_replace_');
    try {
      final library = File('${dir.path}/library')
        ..writeAsStringSync('old library');
      final header = File('${dir.path}/header')
        ..writeAsStringSync('old header');
      final newLibrary = File('${dir.path}/new-library')
        ..writeAsStringSync('new library');
      final newHeader = File('${dir.path}/new-header')
        ..writeAsStringSync('new header');
      replaceFiles({
        newLibrary.path: library.path,
        newHeader.path: header.path,
      });
      expect(library.readAsStringSync(), 'new library');
      expect(header.readAsStringSync(), 'new header');
      expect(dir.listSync().whereType<Directory>(), isEmpty);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
  test('a destination permission error preserves the old output', () {
    final dir = Directory.systemTemp.createTempSync(
      'setup_replace_permissions_',
    );
    final protected = Directory('${dir.path}/protected')..createSync();
    try {
      final old = File('${protected.path}/library')
        ..writeAsStringSync('previous');
      final staged = File('${dir.path}/staged')..writeAsStringSync('new');
      expect(Process.runSync('chmod', ['500', protected.path]).exitCode, 0);
      expect(
        () => replaceFiles({staged.path: old.path}),
        throwsA(isA<FileSystemException>()),
      );
      expect(old.readAsStringSync(), 'previous');
    } finally {
      Process.runSync('chmod', ['700', protected.path]);
      dir.deleteSync(recursive: true);
    }
  }, skip: Platform.isWindows ? 'POSIX permission test' : false);
}
