import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(800, 1000)),
        ],
        child: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('backup names preview variables and reject unknown variables', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      const BackupFileNameDialog(
        value: 'backup-{version}-{platform}',
        version: '1.2.3',
        platform: 'ios',
      ),
    );
    expect(find.text('backup-1.2.3-ios.zip'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '{unknown}');
    await tester.tap(find.text(currentAppLocalizations.save));
    await tester.pumpAndSettle();
    expect(
      find.text(currentAppLocalizations.unknownBackupVariable),
      findsOneWidget,
    );
  });

  testWidgets('directory browsing traverses children and their parent', (
    tester,
  ) async {
    final paths = <String>[];
    await pumpDialog(
      tester,
      DAVDirectoryBrowserDialog(
        directory: '/FlClash',
        loadDirectories: (path) async {
          paths.add(path);
          return path == '/FlClash' ? ['team'] : [];
        },
      ),
    );
    await tester.tap(find.text('team'));
    await tester.pumpAndSettle();
    expect(find.text('/FlClash/team'), findsOneWidget);
    await tester.tap(find.text(currentAppLocalizations.parentDirectory));
    await tester.pumpAndSettle();
    expect(paths, ['/FlClash', '/FlClash/team', '/FlClash']);
    expect(find.text('team'), findsOneWidget);
  });

  testWidgets('unknown WebDAV resources cannot be deleted from the picker', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      RemoteBackupsDialog(
        files: const [DAVFile(name: 'backup.zip')],
        onDelete: (_) async => fail('an unknown resource must not be deleted'),
      ),
    );
    final delete = find.widgetWithText(
      TextButton,
      currentAppLocalizations.delete,
    );
    expect(tester.widget<TextButton>(delete).onPressed, isNull);
    expect(find.text('backup.zip'), findsOneWidget);
  });
}
