import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void _mockClipboard(WidgetTester tester, Future<Object?> Function() read) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData' ? read() : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Future<void> _openDialog(
  WidgetTester tester, {
  NamedUrlDialog dialog = const NamedUrlDialog(title: 'Import'),
  void Function(List<NamedUrl>?)? onResult,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 1000)),
      ],
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showDialog<List<NamedUrl>>(
              context: context,
              builder: (_) => dialog,
            );
            onResult?.call(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

EditableText _urlInput(WidgetTester tester) => tester.widget<EditableText>(
  find.descendant(
    of: find.widgetWithText(TextFormField, 'URL'),
    matching: find.byType(EditableText),
  ),
);

void main() {
  testWidgets(
    'paste preserves credentials, name, and the age key until submit',
    (tester) async {
      const url = 'https://me@mail.com:p@ss@dav.example.com/sub?token=secret';
      _mockClipboard(tester, () async => {'text': '  $url\n'});
      List<NamedUrl>? result;
      await _openDialog(
        tester,
        dialog: const NamedUrlDialog(title: 'Import', withAgeSecretKey: true),
        onResult: (value) => result = value,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Home',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Age secret key'),
        'AGE-SECRET-KEY-1EXAMPLE',
      );
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();

      final input = _urlInput(tester);
      expect(input.controller.text, url);
      expect(
        input.controller.selection,
        const TextSelection.collapsed(offset: url.length),
      );
      expect(result, isNull);
      expect(find.byType(NamedUrlDialog), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(result, [
        (label: 'Home', url: url, ageSecretKey: 'AGE-SECRET-KEY-1EXAMPLE'),
      ]);
    },
  );

  for (final response in ['null', 'empty', 'error']) {
    testWidgets('a $response clipboard response preserves the existing url', (
      tester,
    ) async {
      _mockClipboard(tester, () async {
        if (response == 'error') throw PlatformException(code: 'denied');
        return response == 'null' ? null : {'text': ' \n\t '};
      });
      await _openDialog(
        tester,
        dialog: const NamedUrlDialog(
          title: 'Import',
          url: 'https://example.com/original',
        ),
      );
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      expect(_urlInput(tester).controller.text, 'https://example.com/original');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paste applies the field limit without splitting a grapheme', (
    tester,
  ) async {
    final expected = '${'a' * (TextInputLimits.url - 1)}👨‍👩‍👧‍👦';
    _mockClipboard(tester, () async => {'text': '${expected}extra'});
    await _openDialog(tester);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    final input = _urlInput(tester);
    expect(input.controller.text, expected);
    expect(
      input.controller.selection,
      TextSelection.collapsed(offset: expected.length),
    );
  });

  testWidgets('a clipboard read completing after disposal does not write', (
    tester,
  ) async {
    final read = Completer<Object?>();
    _mockClipboard(tester, () => read.future);
    await _openDialog(tester);
    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpWidget(const SizedBox.shrink());
    read.complete({'text': 'https://example.com/late'});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple pasted links stay single until batch is chosen', (
    tester,
  ) async {
    const shareLink = 'trojan://pass@example.com:443#Hong Kong 01';
    const text =
        'https://example.com/a\nhttps://example.com/a\n'
        'https://example.com/old\n$shareLink';
    _mockClipboard(tester, () async => {'text': text});
    List<NamedUrl>? result;
    await _openDialog(
      tester,
      dialog: NamedUrlDialog(
        title: 'Import',
        batch: true,
        existingUrls: const {'https://example.com/old'},
        urlValidator: (value) =>
            value != null && (value.isUrl || value.isShareLink)
            ? null
            : 'Invalid',
      ),
      onResult: (value) => result = value,
    );
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(_urlInput(tester).controller.text, text);
    expect(find.byTooltip('Batch import'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byTooltip('Batch import'));
    await tester.pumpAndSettle();
    expect(find.text('2 to add, 1 skipped as existing'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(result, [
      (label: '', url: 'https://example.com/a', ageSecretKey: ''),
      (label: '', url: shareLink, ageSecretKey: ''),
    ]);
  });
}
