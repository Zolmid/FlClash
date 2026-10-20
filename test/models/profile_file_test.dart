import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('flclash-profile-file-');
    await useAppPaths(root);
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'rejected content leaves the existing file intact and removes staging',
    () async {
      final profile = Profile.normal(label: 'Existing');
      final file = await profile.file;
      await file.writeAsString('mode: rule\n');
      late String stagedPath;

      await expectLater(
        profile.saveFile(
          utf8.encode('invalid'),
          validate: (path, _) async {
            stagedPath = path;
            return 'Invalid configuration';
          },
        ),
        throwsA(
          isA<MessageException>().having(
            (e) => e.message,
            'message',
            'Invalid configuration',
          ),
        ),
      );

      expect(await file.readAsString(), 'mode: rule\n');
      expect(File(stagedPath).existsSync(), isFalse);
    },
  );

  test(
    'a validator exception removes staging without creating a profile file',
    () async {
      final profile = Profile.normal(label: 'New');
      late String stagedPath;

      await expectLater(
        profile.saveFile(
          utf8.encode('mode: rule\n'),
          validate: (path, _) async {
            stagedPath = path;
            throw StateError('Core disconnected');
          },
        ),
        throwsStateError,
      );

      expect(
        File(await appPath.getProfilePath('${profile.id}')).existsSync(),
        isFalse,
      );
      expect(File(stagedPath).existsSync(), isFalse);
    },
  );

  test(
    'successful validation still saves its prepared bytes before removing staging',
    () async {
      final profile = Profile.normal(label: 'Prepared');
      late String stagedPath;
      final saved = await profile.saveFile(
        utf8.encode('encrypted source'),
        validate: (path, _) async {
          stagedPath = path;
          await File(path).writeAsString('mode: rule\n');
          return '';
        },
      );

      expect(await (await saved.file).readAsString(), 'mode: rule\n');
      expect(saved.lastUpdateDate, isNotNull);
      expect(File(stagedPath).existsSync(), isFalse);
    },
  );
}
