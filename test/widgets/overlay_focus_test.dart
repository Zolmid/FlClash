import 'package:fl_clash/ui/focus.dart';
import 'package:fl_clash/ui/popup.dart';
import 'package:fl_clash/ui/side_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void _noop() {}

void main() {
  Future<FocusNode> pumpOverlay(
    WidgetTester tester, {
    bool sideSheet = false,
    bool modal = true,
  }) async {
    final outsideFocus = FocusNode();
    addTearDown(outsideFocus.dispose);
    Widget controls(BuildContext _) => const Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: _noop, child: Text('First')),
          TextButton(onPressed: _noop, child: Text('Last')),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Focus(
              focusNode: outsideFocus,
              child: const SizedBox(width: 48, height: 600),
            ),
            Expanded(
              child: FocusTraversalGroup(
                policy: PageTraversalPolicy(),
                child: Navigator(
                  routeDirectionalTraversalEdgeBehavior:
                      TraversalEdgeBehavior.parentScope,
                  pages: [
                    MaterialPage(
                      child: PageFocusScope(
                        child: Scaffold(
                          body: Builder(
                            builder: (context) => TextButton(
                              onPressed: () {
                                if (sideSheet) {
                                  showModalSideSheet<void>(
                                    context: context,
                                    builder: controls,
                                  );
                                } else {
                                  Navigator.of(context).push(
                                    CommonPopupRoute<void>(
                                      barrierLabel: 'dismiss',
                                      anchorOf: () =>
                                          const Rect.fromLTWH(80, 80, 40, 40),
                                      modal: modal,
                                      builder: controls,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Open'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  onDidRemovePage: (_) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return outsideFocus;
  }

  Future<void> focus(WidgetTester tester, String label) async {
    Focus.of(tester.element(find.text(label))).requestFocus();
    await tester.pump();
  }

  bool focused(WidgetTester tester, String label) =>
      Focus.of(tester.element(find.text(label))).hasPrimaryFocus;

  for (final sideSheet in [false, true]) {
    testWidgets(
      '${sideSheet ? 'side sheet' : 'popup'} keeps arrows and tab inside its nested modal route',
      (tester) async {
        final outside = await pumpOverlay(tester, sideSheet: sideSheet);
        await focus(tester, 'First');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focused(tester, 'Last'), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(tester, 'Last'), isTrue);
        expect(outside.hasFocus, isFalse);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(focused(tester, 'First'), isTrue);

        Navigator.of(tester.element(find.text('First'))).pop();
        await tester.pumpAndSettle();
        await focus(tester, 'Open');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(outside.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a nonmodal popup does not trap focus in its route', (
    tester,
  ) async {
    final outside = await pumpOverlay(tester, modal: false);
    await focus(tester, 'Last');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(outside.hasFocus, isTrue);
    expect(find.text('First'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
