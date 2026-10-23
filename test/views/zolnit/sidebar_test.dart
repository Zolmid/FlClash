import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/zolnit/shell.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();
  const labels = ['连接', '全部线路', '套餐', '账号'];

  for (final (name, skin, size, dark, dpr, scale) in const [
    ('macos regular light', ZolnitSkin.macos, Size(1200, 800), false, 1.0, 1.0),
    (
      'macos regular dark retina',
      ZolnitSkin.macos,
      Size(1200, 800),
      true,
      2.0,
      1.0,
    ),
    (
      'macos compact light scaled',
      ZolnitSkin.macos,
      Size(820, 600),
      false,
      2.0,
      1.25,
    ),
    (
      'macos compact dark scaled',
      ZolnitSkin.macos,
      Size(820, 600),
      true,
      1.0,
      1.25,
    ),
    ('windows', ZolnitSkin.windows, Size(1200, 800), false, 1.0, 1.0),
    ('linux', ZolnitSkin.linux, Size(1200, 800), false, 1.0, 1.0),
  ]) {
    testWidgets('sidebar centers every row on $name', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await harness.mount(tester, skin, size: size, dark: dark);
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = size * dpr;
      await tester.pumpAndSettle();

      final sidebar = find.byType(ZolnitSidebar);
      for (final selected in labels) {
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text(selected)),
        );
        await tester.pumpAndSettle();
        final rows = <Rect>[];
        final glyphs = <Rect>[];
        final texts = <Rect>[];
        for (final label in labels) {
          final text = find.descendant(of: sidebar, matching: find.text(label));
          final item = find
              .ancestor(of: text, matching: find.byType(InkWell))
              .first;
          final glyph = find.descendant(
            of: item,
            matching: find.byType(GlyphIcon),
          );
          final bounds = tester.getRect(item);
          rows.add(bounds);
          glyphs.add(tester.getRect(glyph));
          texts.add(tester.getRect(text));
          expect(
            tester.getCenter(glyph).dy,
            closeTo(bounds.center.dy, 0.01),
            reason: '$label icon must be centered in its full hit area',
          );
          expect(
            tester.getCenter(text).dy,
            closeTo(bounds.center.dy, 0.01),
            reason: '$label text must be centered in its full hit area',
          );
        }
        final height = switch (skin) {
          ZolnitSkin.macos => 36.0,
          ZolnitSkin.windows => 38.0,
          _ => 42.0,
        };
        for (var index = 0; index < rows.length; index++) {
          expect(rows[index].height, height);
          expect(rows[index].width, rows.first.width);
          expect(glyphs[index].left, glyphs.first.left);
          expect(texts[index].left, texts.first.left);
          if (index > 0) {
            expect(rows[index].top - rows[index - 1].bottom, closeTo(4, 0.01));
          }
        }
        expect(tester.takeException(), isNull);
      }
      await harness.capture(tester, 'sidebar-$name');
    });
  }

  testWidgets('Chinese sidebar heading uses its localized workspace title', (
    tester,
  ) async {
    await harness.mount(tester, ZolnitSkin.macos);
    final sidebar = find.byType(ZolnitSidebar);
    expect(
      find.descendant(of: sidebar, matching: find.text('我的空间')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sidebar, matching: find.text('YOUR WORKSPACE')),
      findsNothing,
    );
  });
}
