import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';

GridItem _card(String label, {int span = 2, VoidCallback? onPressed}) =>
    GridItem(
      key: ValueKey(label),
      crossAxisCellCount: span,
      child: SizedBox(
        height: 100,
        child: CommonCard(
          enterActionsOnRight: true,
          skipTraversal: true,
          onPressed: onPressed,
          child: TextButton(onPressed: () {}, child: Text(label)),
        ),
      ),
    );

List<String> _labels(SuperGridState grid) => [
  for (final item in grid.items) (item.key! as ValueKey<String>).value,
];

Future<void> _pumpMotion(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _focusCard(WidgetTester tester, String label) async {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
  button.focusNode!.requestFocus();
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initial});

  final List<GridItem> initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final gridKey = GlobalKey<SuperGridState>();
  late List<GridItem> children = widget.initial;
  bool editing = true;
  int rootBacks = 0;
  final List<List<String>> changes = [];

  void replace(List<GridItem> next) => setState(() => children = next);

  @override
  Widget build(BuildContext context) {
    final grid = SuperGrid(
      key: gridKey,
      editing: editing,
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      onChanged: (items) {
        changes.add([
          for (final item in items) (item.key! as ValueKey<String>).value,
        ]);
        setState(() => children = items);
      },
      children: children,
    );
    return TestApp(
      child: CommonPopScope(
        onPop: (_) {
          rootBacks++;
          return false;
        },
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: editing
                  ? BackLayerScope(
                      onBack: () => setState(() => editing = false),
                      onBackIntercept: () =>
                          gridKey.currentState!.cancelHeldMove(),
                      child: grid,
                    )
                  : grid,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<_HarnessState> pump(WidgetTester tester, List<GridItem> items) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: items));
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
    return key.currentState!;
  }

  testWidgets(
    'confirm holds the card and deletes it without its normal action',
    (tester) async {
      var presses = 0;
      final harness = await pump(tester, [
        _card('A', onPressed: () => presses++),
        _card('B'),
      ]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'A');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(grid.isHolding, isTrue);
      expect(presses, 0);
      expect(find.byGlyph(AppGlyphs.removeCircle), findsOneWidget);
      expect(harness.changes, isEmpty);

      await _key(tester, LogicalKeyboardKey.enter);
      expect(grid.isHolding, isFalse);
      expect(_labels(grid), ['B']);
      expect(harness.changes, [
        ['B'],
      ]);
      await _pumpMotion(tester);
      expect(find.text('A'), findsNothing);
      final survivor = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('B'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(survivor.focusNode!.hasFocus, isTrue);
      expect(presses, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'held arrows preview order and confirm commits once during motion',
    (tester) async {
      final harness = await pump(tester, [
        _card('A'),
        _card('B'),
        _card('C'),
        _card('D'),
      ]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'A');
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_labels(grid), ['B', 'A', 'C', 'D']);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_labels(grid), ['B', 'D', 'C', 'A']);
      expect(harness.changes, isEmpty);
      expect(find.byGlyph(AppGlyphs.removeCircle), findsNothing);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(grid.isHolding, isFalse);
      expect(harness.changes, [
        ['B', 'D', 'C', 'A'],
      ]);
      await _pumpMotion(tester);
      expect(_labels(grid), ['B', 'D', 'C', 'A']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed spans use packed geometry and rapid reverse keeps the foreground',
    (tester) async {
      final harness = await pump(tester, [
        _card('A', span: 4),
        _card('B'),
        _card('C'),
      ]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'B');
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_labels(grid), ['A', 'C', 'B']);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_labels(grid), ['A', 'B', 'C']);
      final render = tester.renderObject<RenderGrid>(
        find.byWidgetPredicate((widget) => widget is Grid),
      );
      expect(render.foregroundIndex, 1);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_labels(grid), ['B', 'A', 'C']);
      expect(harness.changes, isEmpty);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_labels(grid), ['A', 'B', 'C']);
      expect(grid.isHolding, isFalse);
      expect(harness.editing, isTrue);
      expect(harness.changes, isEmpty);
    },
  );

  testWidgets(
    'a boundary arrow keeps deletion armed and Tab stays on the held card',
    (tester) async {
      final harness = await pump(tester, [_card('A'), _card('B')]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'A');
      final focus = FocusManager.instance.primaryFocus;
      await _key(tester, LogicalKeyboardKey.select);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, focus);
      expect(grid.isHolding, isTrue);
      expect(_labels(grid), ['A', 'B']);
      expect(find.byGlyph(AppGlyphs.removeCircle), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.select);
      expect(_labels(grid), ['B']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back cancels a hold, then exits edit mode, then reaches the route',
    (tester) async {
      final harness = await pump(tester, [_card('A'), _card('B')]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'A');
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_labels(grid), ['A', 'B']);
      expect(grid.isHolding, isFalse);
      expect(harness.editing, isTrue);
      expect(harness.rootBacks, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(harness.editing, isFalse);
      expect(harness.rootBacks, 0);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(harness.rootBacks, 1);
    },
  );

  testWidgets(
    'external children and adding reset holds without restoring stale keys',
    (tester) async {
      final harness = await pump(tester, [_card('A'), _card('B')]);
      final grid = harness.gridKey.currentState!;
      await _focusCard(tester, 'A');
      await _key(tester, LogicalKeyboardKey.enter);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      harness.replace([_card('B'), _card('C')]);
      await tester.pump();
      expect(grid.isHolding, isFalse);
      expect(grid.cancelHeldMove(), isFalse);
      expect(_labels(grid), ['B', 'C']);
      await _focusCard(tester, 'B');
      await _key(tester, LogicalKeyboardKey.enter);
      await grid.addItem(_card('D'));
      await tester.pump();
      expect(grid.isHolding, isFalse);
      expect(_labels(grid), ['B', 'C', 'D']);
      expect(tester.takeException(), isNull);
    },
  );
}
