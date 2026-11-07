import 'package:fl_clash/views/zolnit/motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host({
  required int key,
  required ZolnitPageDirection direction,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: ZolnitPageSwitcher(
        key: const ValueKey('page-switcher'),
        switchKey: key,
        direction: direction,
        child: ColoredBox(
          key: ValueKey('page-$key'),
          color: Colors.white,
          child: Center(child: Text('page-$key')),
        ),
      ),
    ),
  ),
);

void main() {
  test('page direction follows indexes and back navigation', () {
    expect(zolnitPageDirection(0, 1), ZolnitPageDirection.forward);
    expect(zolnitPageDirection(3, 1), ZolnitPageDirection.back);
  });

  testWidgets('page switch keeps opaque pages side-by-side without a fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(key: 0, direction: ZolnitPageDirection.forward),
    );
    await tester.pumpWidget(
      _host(key: 1, direction: ZolnitPageDirection.forward),
    );
    await tester.pump(const Duration(milliseconds: 140));

    final switcher = find.byKey(const ValueKey('page-switcher'));
    expect(
      find.descendant(of: switcher, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: switcher, matching: find.byType(ClipRect)),
      findsOneWidget,
    );
    expect(find.text('page-0'), findsOneWidget);
    expect(find.text('page-1'), findsOneWidget);
    final outgoing = tester.getRect(find.byKey(const ValueKey('page-0')));
    final incoming = tester.getRect(find.byKey(const ValueKey('page-1')));
    expect(outgoing.right, moreOrLessEquals(incoming.left));
    expect(outgoing.left, lessThan(0));
    expect(incoming.right, greaterThan(tester.getSize(switcher).width));
  });

  testWidgets(
    'rapid taps keep continuous coverage and only the latest pending destination',
    (tester) async {
      await tester.pumpWidget(
        _host(key: 0, direction: ZolnitPageDirection.forward),
      );
      await tester.pumpWidget(
        _host(key: 1, direction: ZolnitPageDirection.forward),
      );
      await tester.pump(const Duration(milliseconds: 80));
      final before = tester.getRect(find.byKey(const ValueKey('page-1'))).left;
      await tester.pumpWidget(
        _host(key: 2, direction: ZolnitPageDirection.forward),
      );
      await tester.pumpWidget(
        _host(key: 3, direction: ZolnitPageDirection.forward),
      );
      expect(find.text('page-2'), findsNothing);
      expect(find.text('page-3'), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('page-1'))).left,
        moreOrLessEquals(before),
      );
      final old = tester.getRect(find.byKey(const ValueKey('page-0'))),
          current = tester.getRect(find.byKey(const ValueKey('page-1')));
      expect(old.right, moreOrLessEquals(current.left));
      expect(old.left, lessThanOrEqualTo(0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('page-2'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('page-3'), findsOneWidget);
      expect(find.text('page-0'), findsNothing);
      expect(find.text('page-1'), findsNothing);
    },
  );

  testWidgets('reduced motion changes pages immediately at 320 and wide', (
    tester,
  ) async {
    for (final width in [320.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          key: 0,
          direction: ZolnitPageDirection.forward,
          reducedMotion: true,
        ),
      );
      await tester.pumpWidget(
        _host(
          key: 1,
          direction: ZolnitPageDirection.forward,
          reducedMotion: true,
        ),
      );
      await tester.pump();
      expect(find.text('page-0'), findsNothing);
      expect(find.text('page-1'), findsOneWidget);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
