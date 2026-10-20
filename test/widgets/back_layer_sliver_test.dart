import 'package:fl_clash/ui/pop_scope.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a sliver back layer keeps its layout and keyboard handling', (
    tester,
  ) async {
    var backed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            BackLayerScope(
              onBack: () => backed++,
              child: SliverToBoxAdapter(
                child: TextButton(
                  autofocus: true,
                  onPressed: () {},
                  child: const Text('Editing'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Editing'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(backed, 1);
    expect(tester.takeException(), isNull);
  });
}
