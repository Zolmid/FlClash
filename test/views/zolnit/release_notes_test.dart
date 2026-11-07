import 'package:fl_clash/common/changelog.dart';
import 'package:fl_clash/views/zolnit/notes.dart';
import 'package:fl_clash/views/zolnit/motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  const body =
      '<!-- flclash:changelog:begin -->\n'
      '### Features\n- **release** Better updates.\n'
      '<!-- flclash:changelog:end -->\n'
      '<!-- flclash:changelog:json\n{"schemaVersion":2,"versions":[{"version":"1.1.0","tag":"v1.1.0","date":"","prerelease":false,"groups":[{"type":"feat","entries":[{"id":"abc1234","text":"Better updates."}]}]}]}\n-->';

  test('removes metadata and preserves human readable text', () {
    expect(parseReleaseChangelog(body)?.tag, 'v1.1.0');
    expect(releaseNotesPlainText(body), 'Features\n• release Better updates.');
    expect(
      displayReleaseNotes('News\n<!-- flclash:changelog:json\n{bad'),
      'News',
    );
    expect(displayReleaseNotes('News\n<!-- broken -->\nDone'), 'News\n\nDone');
    expect(
      displayReleaseNotes(
        'News\n<!-- flclash:changelog:json\n{broken --> SECRET JSON',
      ),
      'News',
    );
    expect(
      releaseNotesPlainText(
        'News\n<!-- flclash:changelog:json\n{broken --> SECRET JSON',
      ),
      'News',
    );
    expect(
      releaseNotesPlainText('Ordinary short notice.'),
      'Ordinary short notice.',
    );
  });

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    for (final dark in [false, true]) {
      testWidgets('long notes expand on mobile $locale dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final longBody =
            '${List.filled(20, '- More improvements').join('\n')}\n$body';
        await tester.pumpWidget(
          TestApp(
            includeNavigatorKey: false,
            locale: locale,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            child: Scaffold(
              body: AlertDialog(
                title: const Text('Update'),
                content: SingleChildScrollView(
                  child: ReleaseNotesContent(heading: 'v1.1.0', body: longBody),
                ),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Install')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('v1.1.0'), findsOneWidget);
        expect(find.text('Install'), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        final animated = tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animated.duration, zolnitStandard);
        expect(animated.curve, zolnitEase);
        expect(find.byType(TextButton), findsNWidgets(2));
        expect(
          find.text(locale.languageCode == 'zh' ? '展开' : 'Expand'),
          findsOneWidget,
        );
        await tester.tap(find.byType(TextButton).first);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
        expect(
          find.text(locale.languageCode == 'zh' ? '收起' : 'Collapse'),
          findsOneWidget,
        );
        final text = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText();
        expect(text, contains('• release Better updates.'));
        expect(
          text,
          contains(locale.languageCode == 'zh' ? '新功能' : 'New features'),
        );
        expect(text, isNot(contains('schemaVersion')));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('reduced motion expands and collapses immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        includeNavigatorKey: false,
        locale: const Locale('en'),
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ReleaseNotesContent(
              body: List.filled(12, '- Detail').join('\n'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.tap(find.text('Expand'));
    await tester.pump();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('Collapse'));
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('short notes are visible without expansion', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        includeNavigatorKey: false,
        child: Scaffold(body: ReleaseNotesContent(body: 'Hello there.')),
      ),
    );
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
