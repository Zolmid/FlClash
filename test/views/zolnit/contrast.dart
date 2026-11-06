import 'package:fl_clash/ui/icons/glyph_painter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double contrastRatio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

class ContrastIssue {
  const ContrastIssue(
    this.label,
    this.foreground,
    this.background,
    this.ratio,
    this.required,
  );

  final String label;
  final Color foreground;
  final Color background;
  final double ratio;
  final double required;

  static String hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

  @override
  String toString() =>
      '"$label" ${hex(foreground)} on ${hex(background)} = '
      '${ratio.toStringAsFixed(2)} < $required';
}

const _unknown = Color(0x01020304);

Color? _decorationFill(Decoration? decoration) => switch (decoration) {
  BoxDecoration(gradient: null, image: null, :final color) => color,
  ShapeDecoration(gradient: null, image: null, :final color) => color,
  null => null,
  _ => _unknown,
};

Color? _fillOf(Widget widget, Element element) => switch (widget) {
  Material(type: MaterialType.transparency) => null,
  Material(:final color?) => color,
  Material(type: MaterialType.canvas) => Theme.of(element).canvasColor,
  Material(type: MaterialType.card) => Theme.of(element).cardColor,
  ColoredBox(:final color) => color,
  DecoratedBox(position: DecorationPosition.background, :final decoration) =>
    _decorationFill(decoration),
  Ink(:final decoration) => _decorationFill(decoration),
  CustomPaint(painter: final painter?)
      when painter is! GlyphPainter &&
          '${painter.runtimeType}' != '_ShapeBorderPainter' =>
    _unknown,
  Image() => _unknown,
  _ => null,
};

bool _hidden(Widget widget) => switch (widget) {
  Opacity(:final opacity) => opacity < 0.99,
  FadeTransition(:final opacity) => opacity.value < 0.99,
  Offstage(:final offstage) => offstage,
  Visibility(:final visible) => !visible,
  IconButton(:final onPressed) => onPressed == null,
  _ => false,
};

Color? _background(Element element) {
  final fills = <Color>[];
  var measurable = true;
  Color? opaque;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (_hidden(widget)) {
      measurable = false;
      return false;
    }
    final fill = _fillOf(widget, ancestor);
    if (fill == _unknown) {
      measurable = false;
      return false;
    }
    if (fill == null || fill.a == 0) return true;
    if (fill.a >= 1) {
      opaque = fill;
      return false;
    }
    fills.add(fill);
    return true;
  });
  if (!measurable || opaque == null) return null;
  var color = opaque!;
  for (final fill in fills.reversed) {
    color = Color.alphaBlend(fill, color);
  }
  return color;
}

bool _inView(RenderBox box, Size view) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return false;
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  return rect.overlaps(Offset.zero & view);
}

/// Measures every visible text run and glyph against the fill it is painted
/// on: 4.5:1 for body text, 3:1 for large text and icons (WCAG 2.2 AA).
List<ContrastIssue> auditContrast(WidgetTester tester) {
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  final issues = <ContrastIssue>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (!_inView(paragraph, view)) continue;
    final background = _background(element);
    if (background == null) continue;
    void visit(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        final color = style.color;
        if (text.isNotEmpty &&
            color != null &&
            color.a > 0 &&
            !text.runes.every((r) => r > 0x1F000)) {
          final size = style.fontSize ?? 14;
          final bold = (style.fontWeight?.value ?? 400) >= 700;
          final required = size >= 24 || (size >= 18.66 && bold) ? 3.0 : 4.5;
          final ratio = contrastRatio(
            Color.alphaBlend(color, background),
            background,
          );
          if (ratio < required) {
            issues.add(ContrastIssue(text, color, background, ratio, required));
          }
        }
      }
      span.visitDirectChildren((child) {
        visit(child, style);
        return true;
      });
    }

    visit(paragraph.text, const TextStyle());
  }
  for (final element in find.byType(CustomPaint).evaluate()) {
    final painter = (element.widget as CustomPaint).painter;
    if (painter is! GlyphPainter || painter.color.a == 0) continue;
    final box = element.renderObject! as RenderBox;
    if (!_inView(box, view)) continue;
    final background = _background(element);
    if (background == null) continue;
    final ratio = contrastRatio(
      Color.alphaBlend(painter.color, background),
      background,
    );
    if (ratio < 3) {
      final owner = element.findAncestorWidgetOfExactType<Tooltip>()?.message;
      issues.add(
        ContrastIssue(
          'icon ${owner ?? ''}',
          painter.color,
          background,
          ratio,
          3,
        ),
      );
    }
  }
  return issues;
}
