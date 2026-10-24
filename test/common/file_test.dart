import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';

class _MockFileSystemEntity extends Mock implements FileSystemEntity {}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('file_test');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('safeDelete', () {
    for (final recursive in [false, true]) {
      test(
        'accepts a file disappearing after exists (recursive: $recursive)',
        () async {
          final file = File(join(root.path, 'compiled.mrs'))
            ..writeAsStringSync('cache');
          final entity = _MockFileSystemEntity();
          when(entity.exists).thenAnswer((_) async {
            final exists = await file.exists();
            await file.delete();
            return exists;
          });
          when(
            () => entity.delete(recursive: recursive),
          ).thenAnswer((_) => file.delete(recursive: recursive));

          await expectLater(entity.safeDelete(recursive: recursive), completes);

          expect(file.existsSync(), isFalse);
          verify(entity.exists).called(1);
          verify(() => entity.delete(recursive: recursive)).called(1);
        },
      );
    }

    test('skips deletion when the entity is already missing', () async {
      final entity = _MockFileSystemEntity();
      when(entity.exists).thenAnswer((_) async => false);

      await entity.safeDelete();

      verifyNever(() => entity.delete());
    });

    final deleteErrors = <String, FileSystemException>{
      'permission': const PathAccessException(
        'compiled.mrs',
        OSError('Permission denied', 13),
      ),
      'other IO': const FileSystemException(
        'Input/output error',
        'compiled.mrs',
        OSError('Input/output error', 5),
      ),
    };
    for (final entry in deleteErrors.entries) {
      test('preserves ${entry.key} errors from delete', () async {
        final entity = _MockFileSystemEntity();
        when(entity.exists).thenAnswer((_) async => true);
        when(() => entity.delete()).thenThrow(entry.value);

        await expectLater(entity.safeDelete(), throwsA(same(entry.value)));
      });
    }

    test('preserves errors from exists', () async {
      final entity = _MockFileSystemEntity();
      const error = PathNotFoundException('compiled.mrs', OSError('', 2));
      when(entity.exists).thenThrow(error);

      await expectLater(entity.safeDelete(), throwsA(same(error)));

      verifyNever(() => entity.delete());
    });

    test('does not recursively delete by default', () async {
      final directory = Directory(join(root.path, 'cache'))..createSync();
      final child = File(join(directory.path, 'compiled.mrs'))
        ..writeAsStringSync('cache');

      await expectLater(
        directory.safeDelete(),
        throwsA(isA<FileSystemException>()),
      );

      expect(child.readAsStringSync(), 'cache');
    });
  });

  group('safeDeletePath', () {
    test('removes a file', () async {
      final path = join(root.path, 'config.yaml');
      File(path).writeAsStringSync('mixed-port: 7890');

      await safeDeletePath(path);

      expect(File(path).existsSync(), isFalse);
    });

    test('removes a directory along with everything under it', () async {
      final path = join(root.path, '42');
      File(join(path, 'proxies', 'abc'))
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: []');

      await safeDeletePath(path);

      expect(Directory(path).existsSync(), isFalse);
    });

    test('accepts a path that is already gone', () async {
      await expectLater(safeDeletePath(join(root.path, 'missing')), completes);
    });
  });

  group('writeAsStringAtomically', () {
    test('replaces the file and leaves nothing beside it', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mixed-port: 7890');

      await file.writeAsStringAtomically('mixed-port: 7891');

      expect(file.readAsStringSync(), 'mixed-port: 7891');
      expect(root.listSync().map((entry) => basename(entry.path)), [
        'config.yaml',
      ]);
    });

    test('creates the directory a first write needs', () async {
      final file = File(join(root.path, 'home', 'config.yaml'));

      await file.writeAsStringAtomically('mode: rule');

      expect(file.readAsStringSync(), 'mode: rule');
    });

    test('keeps the old file when the new one cannot be written', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mode: rule');
      Directory('${file.path}.$pid.tmp').createSync();

      await expectLater(
        file.writeAsStringAtomically('mode: global'),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.readAsStringSync(), 'mode: rule');
    });
  });
}
