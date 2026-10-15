import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  bool isTV = true,
  bool slider = false,
  bool input = true,
  void Function(String?)? onResult,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RemoteFocusAdapter(
      enabled: isTV,
      child: TestApp(
        overrides: [
          tvLayoutProvider.overrideWith((_) => isTV),
          viewSizeProvider.overrideWithBuild((_, _) => const Size(1000, 800)),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => CommonDialog(
                  title: 'Input',
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('cancel'),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('submit'),
                      child: const Text('Submit'),
                    ),
                  ],
                  child: !input
                      ? const Text('Body')
                      : slider
                      ? Slider(autofocus: true, value: 0.5, onChanged: (_) {})
                      : TextField(
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (value) =>
                              Navigator.of(context).pop(value),
                        ),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final viaToolbar in [false, true]) {
    testWidgets(
      'TV back from ${viaToolbar ? 'toolbar' : 'system'} releases input',
      (tester) async {
        await _openDialog(tester);
        await tester.enterText(find.byType(TextField), 'keep this');
        await tester.pump();
        final input = tester.widget<EditableText>(find.byType(EditableText));
        final scope = input.focusNode.enclosingScope!;
        expect(input.focusNode.hasPrimaryFocus, isTrue);

        if (viaToolbar) {
          await tester.tap(find.text('Back'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(CommonDialog), findsOneWidget);
        expect(input.focusNode.hasFocus, isFalse);
        expect(scope.hasPrimaryFocus, isTrue);
        expect(scope.focusedChild, same(input.focusNode));
        expect(input.controller.text, 'keep this');
        expect(tester.testTextInput.hasAnyClients, isFalse);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CommonDialog), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('TV back releases a slider before closing', (tester) async {
    await _openDialog(tester, slider: true);
    final sliderFocus = FocusManager.instance.primaryFocus!;
    expect(
      sliderFocus.context?.findAncestorWidgetOfExactType<Slider>(),
      isNotNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CommonDialog), findsOneWidget);
    expect(sliderFocus.hasFocus, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CommonDialog), findsNothing);
  });

  for (final action in ['Submit', 'Cancel', 'IME']) {
    testWidgets(
      '$action closes once and returns its result with TV input focus',
      (tester) async {
        final results = <String?>[];
        await _openDialog(tester, onResult: results.add);
        await tester.enterText(find.byType(TextField), 'ime-value');
        await tester.pump();
        if (action == 'IME') {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(find.byType(CommonDialog), findsNothing);
        expect(results, [action == 'IME' ? 'ime-value' : action.toLowerCase()]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('TV back without input focus closes immediately', (tester) async {
    await _openDialog(tester, input: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CommonDialog), findsNothing);
  });

  testWidgets('non-TV back closes immediately while input is focused', (
    tester,
  ) async {
    await _openDialog(tester, isTV: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CommonDialog), findsNothing);
  });

  testWidgets(
    'back closes the current dialog without disturbing the outer input',
    (tester) async {
      await _openDialog(tester);
      await tester.enterText(find.byType(TextField), 'outer value');
      final outerInput = tester.widget<EditableText>(find.byType(EditableText));
      final outer = tester.element(find.byType(CommonDialog));
      final nested = showDialog<void>(
        context: outer,
        builder: (_) =>
            const CommonDialog(title: 'Nested', child: Text('Body')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await nested;
      expect(find.text('Nested'), findsNothing);
      expect(find.text('Input'), findsOneWidget);
      expect(outerInput.controller.text, 'outer value');
      expect(outerInput.focusNode.hasPrimaryFocus, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CommonDialog), findsOneWidget);
      expect(outerInput.focusNode.hasFocus, isFalse);
    },
  );
}
