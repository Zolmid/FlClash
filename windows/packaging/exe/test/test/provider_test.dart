import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_compiler.dart';
import 'package:flutter_app_packager/src/makers/exe/inno_setup/inno_setup_script.dart';
import 'package:flutter_app_packager/src/makers/exe/make_exe_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final repository = Directory(
    p.normalize(p.join(Directory.current.path, '../../../..')),
  );
  final values =
      jsonDecode(
            jsonEncode(
              loadYaml(
                File(
                  p.join(
                    repository.path,
                    'windows/packaging/exe/make_config.yaml',
                  ),
                ).readAsStringSync(),
              ),
            ),
          )
          as Map<String, dynamic>;
  late Directory previousDirectory;
  late Directory sandbox;

  setUp(() {
    previousDirectory = Directory.current;
    sandbox = Directory.systemTemp.createTempSync('flclash installer ');
    Directory.current = sandbox;
    File(
      'pubspec.yaml',
    ).writeAsStringSync('name: fl_clash\nversion: 1.0.0+1\n');
    final script = File('windows/packaging/exe/inno_setup.iss');
    script.parent.createSync(recursive: true);
    File(p.join(repository.path, script.path)).copySync(script.path);
    final inno = Directory('Inno Setup 6').absolute..createSync();
    for (final path in [
      'ISCC.exe',
      'Default.isl',
      'Languages/Japanese.isl',
      'Languages/Russian.isl',
    ]) {
      final file = File(p.join(inno.path, path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('');
    }
    InnoSetupCompiler.setExtraEnv({'INNO_SETUP_PATH': inno.path});
  });

  tearDown(() {
    InnoSetupCompiler.setExtraEnv({});
    Directory.current = previousDirectory;
    sandbox.deleteSync(recursive: true);
  });

  test('the pinned provider reads publisher_name and ignores publisher', () {
    final legacy = Map<String, dynamic>.of(values)
      ..remove('publisher_name')
      ..['publisher'] = 'chen08209';
    expect(MakeExeConfig.fromJson(legacy).publisherName, isNull);
    expect(MakeExeConfig.fromJson(values).publisherName, 'chen08209');
    expect(values, isNot(contains('publisher')));
  });

  test(
    'the actual provider renders identity, URLs and all installer languages',
    () async {
      final config = MakeExeConfig.fromJson(values)
        ..platform = 'windows'
        ..arch = 'x64'
        ..buildMode = 'release'
        ..packageFormat = 'exe'
        ..outputDirectory = Directory('dist');
      final script = await InnoSetupScript.fromMakeConfig(config).createFile();
      final content = script.readAsStringSync();
      expect(content, contains('AppPublisher=chen08209\n'));
      expect(content, contains('AppId=728B3532-C74B-4870-9068-BE70FE12A3E6\n'));
      expect(content, contains('AppName=FlClash\n'));
      expect(content, contains('PrivilegesRequired=admin\n'));
      final constants = File(
        p.join(repository.path, 'lib/common/constant.dart'),
      ).readAsStringSync();
      String constant(String name) =>
          RegExp("const $name = '([^']+)';").firstMatch(constants)!.group(1)!;
      final publisherUrl =
          'https://github.com/${constant('upstreamRepository')}';
      expect(content, contains('AppPublisherURL=$publisherUrl\n'));
      expect(content, contains('AppSupportURL=$publisherUrl\n'));
      expect(
        content,
        contains(
          'AppUpdatesURL=https://github.com/${constant('repository')}/releases/latest\n',
        ),
      );
      for (final language in [
        'english',
        'japanese',
        'russian',
        'chineseSimplified',
        'chineseTraditional',
      ]) {
        expect(content, contains('Name: "$language"; MessagesFile: "'));
      }
      for (final locale in values['locales'] as List) {
        if (locale['file'] case final String path) {
          expect(content, contains('MessagesFile: "$path"'));
        }
      }
      expect(content, isNot(contains('{%')));
      expect(content, isNot(matches(RegExp(r'\{\{[A-Z_]+\}\}'))));
      expect(
        content,
        contains("ExpandConstant('{srcexe}') + '.' + Nonce + '.ready'"),
      );
      expect(content, contains('if not WaitForParentAcknowledgement then'));
      expect(content, contains("ExpandConstant('{app}\\FlClash.exe')"));
      final cleanup = content.substring(
        content.indexOf('procedure RemoveUserRegistrations;'),
        content.indexOf('function IsAppUpdate: Boolean;'),
      );
      expect(cleanup, contains("Exec(AppPath, '--remove-user-registrations'"));
      expect(cleanup, contains('ewWaitUntilTerminated, ResultCode)'));
      expect(cleanup, isNot(contains('ExecAsOriginalUser')));
      expect(cleanup, isNot(contains('/Delete')));
      final uninstall = content.substring(
        content.indexOf('procedure CurUninstallStepChanged('),
        content.indexOf('[Languages]'),
      );
      expect(uninstall, contains('if CurUninstallStep = usUninstall then'));
      expect(
        uninstall.indexOf('RemoveUserRegistrations;'),
        lessThan(uninstall.indexOf('KillProcesses;')),
      );
      expect(content, isNot(contains('function InitializeUninstall()')));
    },
  );
}
