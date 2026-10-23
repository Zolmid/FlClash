import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

const _appleLocales = {'en', 'ja', 'ru', 'zh-Hans', 'zh-Hant'};

Map<String, dynamic> _catalog(String path) =>
    (jsonDecode(File(path).readAsStringSync())
            as Map<String, dynamic>)['strings']
        as Map<String, dynamic>;

String _translation(dynamic entry, String locale) =>
    entry['localizations'][locale]['stringUnit']['value'] as String;

String _projectSection(String project, String section) => project.substring(
  project.indexOf('/* Begin $section section */'),
  project.indexOf('/* End $section section */'),
);

void main() {
  test(
    'Windows installer enables its five languages with valid local files',
    () {
      final config =
          loadYaml(
                File(
                  'windows/packaging/exe/make_config.yaml',
                ).readAsStringSync(),
              )
              as YamlMap;
      final locales = config['locales'] as YamlList;
      const names = {
        'en': 'english',
        'ja': 'japanese',
        'ru': 'russian',
        'zh': 'chineseSimplified',
        'zh_TW': 'chineseTraditional',
      };
      const builtinFiles = {
        'en': r'compiler:Default.isl',
        'ja': r'compiler:Languages\\Japanese.isl',
        'ru': r'compiler:Languages\\Russian.isl',
      };
      expect(
        locales.map((locale) => locale['lang']).toSet(),
        names.keys.toSet(),
      );
      final script = File(
        'windows/packaging/exe/inno_setup.iss',
      ).readAsStringSync();
      expect(config['publisher_name'], 'Zolmid');
      expect(config['publisher'], isNull);
      expect(config['publisher_url'], 'https://link.zolmid.com');
      expect(script, contains('AppPublisher={{PUBLISHER_NAME}}'));
      expect(script, contains('AppPublisherURL={{PUBLISHER_URL}}'));
      expect(script, contains('AppSupportURL={{PUBLISHER_URL}}'));
      expect(script, contains('AppUpdatesURL=https://link.zolmid.com'));
      final languages = script.substring(
        script.indexOf('[Languages]'),
        script.indexOf('[Tasks]'),
      );
      for (final locale in locales) {
        final lang = locale['lang'] as String;
        final branch = RegExp(
          "\\{% if locale.lang == '$lang' %\\}([\\s\\S]*?)\\{% endif %\\}",
        ).firstMatch(languages);
        expect(branch, isNotNull, reason: '$lang requires an installer branch');
        expect(
          branch!.group(1),
          contains('Name: "${names[lang]}"; MessagesFile:'),
        );
        final configuredFile = locale['file'] as String?;
        if (configuredFile == null) {
          expect(
            branch.group(1),
            contains('MessagesFile: "${builtinFiles[lang]}"'),
          );
          continue;
        }
        expect(branch.group(1), contains('"{{ locale.file }}"'));
        final pathFromDist = p.windows.normalize(
          p.windows.join('dist', configuredFile),
        );
        final file = File(p.joinAll(p.windows.split(pathFromDist)));
        expect(file.existsSync(), isTrue, reason: '$configuredFile from dist/');
        final messages = file.readAsStringSync();
        expect(
          messages,
          contains(lang == 'zh_TW' ? r'LanguageID=$0404' : r'LanguageID=$0804'),
        );
        for (final key in [
          'CreateDesktopIcon',
          'AdditionalIcons',
          'LaunchProgram',
        ]) {
          expect(messages, matches(RegExp('^$key=.+', multiLine: true)));
        }
      }
    },
  );

  test('Android common translates its existing notification channel keys', () {
    const resources = 'android/common/src/main/res';
    Map<String, String> strings(String path) => {
      for (final item in XmlDocument.parse(
        File(path).readAsStringSync(),
      ).findAllElements('string'))
        item.getAttribute('name')!: item.innerText,
    };
    final defaults = strings('$resources/values/strings.xml');
    final traditional = strings('$resources/values-b+zh+Hant/strings.xml');
    expect(traditional.keys.toSet(), defaults.keys.toSet());
    expect(traditional['app_name'], defaults['app_name']);
    expect(traditional['service_channel_name'], 'ZolNit 服務');
    expect(
      File(
        'android/common/src/main/java/com/zolmid/zolnit/common/Ext.kt',
      ).readAsStringSync(),
      contains('getString(R.string.service_channel_name)'),
    );
  });

  test(
    'macOS menu catalogs match the existing XIB objects and source text',
    () {
      final document = XmlDocument.parse(
        File('macos/Runner/Base.lproj/MainMenu.xib').readAsStringSync(),
      );
      final objects = {
        for (final element in document.descendants.whereType<XmlElement>())
          if (element.getAttribute('id') case final String id) id: element,
      };
      final menu = _catalog('macos/Runner/mul.lproj/MainMenu.xcstrings');
      for (final entry in menu.entries) {
        final parts = entry.key.split('.');
        expect(objects, contains(parts.first), reason: entry.key);
        expect(
          objects[parts.first]!.getAttribute(parts.last),
          _translation(entry.value, 'en'),
          reason: '${entry.key} must refer to unchanged source text',
        );
        expect(
          (entry.value['localizations'] as Map).keys.toSet(),
          _appleLocales,
        );
        for (final locale in _appleLocales) {
          expect(_translation(entry.value, locale), isNotEmpty);
        }
      }
      final info = _catalog('macos/Runner/InfoPlist.xcstrings');
      expect(info.keys, ['NSLocationWhenInUseUsageDescription']);
      for (final locale in _appleLocales) {
        expect(_translation(info.values.single, locale), isNotEmpty);
      }
    },
  );

  test('macOS declares and bundles both native localization catalogs', () {
    final plist = XmlDocument.parse(
      File('macos/Runner/Info.plist').readAsStringSync(),
    );
    final locales = plist
        .findAllElements('key')
        .singleWhere((key) => key.innerText == 'CFBundleLocalizations')
        .nextElementSibling!
        .findElements('string')
        .map((element) => element.innerText)
        .toSet();
    expect(locales, _appleLocales);
    final project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final regions = RegExp(
      r'knownRegions = \(([\s\S]*?)\);',
    ).firstMatch(project)!.group(1)!;
    for (final locale in _appleLocales) {
      expect(regions, contains(locale));
    }
    expect(
      _projectSection(project, 'PBXResourcesBuildPhase'),
      contains('InfoPlist.xcstrings in Resources'),
    );
    expect(
      _projectSection(project, 'PBXBuildFile'),
      contains('fileRef = 9F33F407587A4FF3B06735C9 /* InfoPlist.xcstrings */;'),
    );
    expect(
      _projectSection(project, 'PBXFileReference'),
      contains('path = mul.lproj/MainMenu.xcstrings;'),
    );
    expect(
      _projectSection(project, 'PBXVariantGroup'),
      contains('0590E3572FFA8D5D00321CD8 /* mul */'),
    );
  });
}
