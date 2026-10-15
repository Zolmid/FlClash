import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  for (final mode in ['default', 'autofocus', 'selectAll', 'secret']) {
    testWidgets('InputDialog keeps $mode focus and selection intent', (
      tester,
    ) async {
      const value = 'existing name';
      await tester.pumpWidget(
        TestApp(
          overrides: [
            viewSizeProvider.overrideWithBuild((_, _) => const Size(1000, 800)),
          ],
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => InputDialog(
                  title: 'Name',
                  value: value,
                  autofocus: mode == 'autofocus' || mode == 'secret',
                  selectAll: mode == 'selectAll',
                  obscureText: mode == 'secret',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.focusNode.hasFocus, mode != 'default');
      expect(input.controller.text, value);
      if (mode == 'selectAll') {
        expect(
          input.controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: value.length),
        );
      } else if (mode != 'default') {
        expect(
          input.controller.selection,
          const TextSelection.collapsed(offset: value.length),
        );
      }
    });
  }
}
