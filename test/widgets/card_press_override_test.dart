import 'package:fl_clash/widgets/card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('override transitions retain the card scrollable state', (
    tester,
  ) async {
    final controller = PageController();
    final node = FocusNode();
    var editing = false;
    late StateSetter update;
    await tester.pumpWidget(
      TestApp(
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return CardPressOverride(
              onPressed: editing ? () {} : null,
              focusNode: node,
              child: CommonCard(
                skipTraversal: true,
                enterActionsOnRight: true,
                onPressed: () {},
                child: PageView(
                  controller: controller,
                  children: const [Text('first'), Text('second')],
                ),
              ),
            );
          },
        ),
      ),
    );
    final pager = tester.state(find.byType(PageView));
    for (final next in [true, false, true]) {
      update(() => editing = next);
      await tester.pump();
      expect(tester.state(find.byType(PageView)), same(pager));
      expect(controller.positions, hasLength(1));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    node.dispose();
  });

  testWidgets('an override owns activation and excludes nested controls', (
    tester,
  ) async {
    final node = FocusNode();
    var normalPresses = 0;
    var overrides = 0;
    var nestedPresses = 0;
    await tester.pumpWidget(
      TestApp(
        child: CardPressOverride(
          onPressed: () => overrides++,
          focusNode: node,
          child: CommonCard(
            inert: true,
            skipTraversal: true,
            onPressed: () => normalPresses++,
            child: CommonCard(
              onPressed: () => nestedPresses++,
              child: TextButton(
                onPressed: () => nestedPresses++,
                child: const Text('nested'),
              ),
            ),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(node.descendants.where((node) => node.canRequestFocus), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(overrides, 1);
    expect(normalPresses, 0);
    expect(nestedPresses, 0);
    expect(
      tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .where((button) => identical(button.focusNode, node)),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    node.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null override keeps normal card activation and inert state', (
    tester,
  ) async {
    var presses = 0;
    Future<void> pump({required bool inert}) => tester.pumpWidget(
      TestApp(
        child: CardPressOverride(
          onPressed: null,
          child: CommonCard(
            inert: inert,
            onPressed: () => presses++,
            onLongPress: () => presses++,
            child: const Text('normal'),
          ),
        ),
      ),
    );
    await pump(inert: false);
    await tester.tap(find.text('normal'));
    expect(presses, 1);
    await pump(inert: true);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(button.onLongPress, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
