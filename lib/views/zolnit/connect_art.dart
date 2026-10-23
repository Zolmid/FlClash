import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'skin.dart';

const _continents = <List<(double, double)>>[
  [
    (75, 93),
    (135, 45),
    (245, 49),
    (315, 105),
    (270, 157),
    (205, 167),
    (182, 220),
    (132, 178),
  ],
  [(232, 235), (295, 246), (340, 306), (300, 408), (274, 440), (252, 355)],
  [(420, 104), (475, 65), (545, 77), (565, 130), (527, 167), (459, 162)],
  [
    (455, 183),
    (527, 170),
    (574, 238),
    (554, 320),
    (507, 358),
    (467, 295),
    (438, 222),
  ],
  [
    (560, 85),
    (665, 51),
    (820, 67),
    (934, 139),
    (881, 190),
    (797, 177),
    (751, 246),
    (690, 211),
    (639, 173),
    (574, 163),
  ],
  [
    (706, 245),
    (748, 243),
    (778, 293),
    (822, 307),
    (833, 336),
    (782, 326),
    (740, 279),
  ],
  [(807, 355), (865, 326), (912, 358), (913, 407), (854, 428), (817, 397)],
];

bool _inside(double x, double y, List<(double, double)> polygon) {
  var result = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final (xi, yi) = polygon[i];
    final (xj, yj) = polygon[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      result = !result;
    }
  }
  return result;
}

final List<Offset> _mapDots = [
  for (var y = 45.0; y < 455; y += 11)
    for (var x = 55.0; x < 955; x += 11)
      if (_continents.any((polygon) => _inside(x, y, polygon))) Offset(x, y),
];

/// A dotted world with one route fanning out of the home region.
class ZolnitWorldMap extends StatelessWidget {
  const ZolnitWorldMap({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 2,
      child: CustomPaint(painter: _MapPainter(color)),
    ),
  );
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1000;
    canvas.scale(scale);
    final dot = Paint()
      ..color = color
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(ui.PointMode.points, _mapDots, dot);
    final route = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final path in [
      Path()
        ..moveTo(722, 221)
        ..quadraticBezierTo(650, 48, 866, 136),
      Path()
        ..moveTo(722, 221)
        ..quadraticBezierTo(814, 184, 783, 301),
    ]) {
      for (final metric in path.computeMetrics()) {
        for (var at = 0.0; at < metric.length; at += 10) {
          canvas.drawPath(metric.extractPath(at, at + 5), route);
        }
      }
    }
    final fill = Paint()..color = color;
    canvas
      ..drawCircle(const Offset(722, 221), 6, fill)
      ..drawCircle(const Offset(866, 136), 5, fill)
      ..drawCircle(const Offset(783, 301), 5, fill);
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => oldDelegate.color != color;
}

class ZolnitPowerButton extends StatelessWidget {
  const ZolnitPowerButton({
    super.key,
    required this.status,
    required this.label,
    required this.onPressed,
  });

  final CoreStatus status;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final area = switch (skin) {
      ZolnitSkin.ios => 92.0,
      ZolnitSkin.android => 136.0,
      _ => 108.0,
    };
    final size = switch (skin) {
      ZolnitSkin.ios => 82.0,
      ZolnitSkin.android => 120.0,
      _ => 80.0,
    };
    final connected = status == CoreStatus.connected;
    final squircle = skin == ZolnitSkin.android;
    final fill = squircle || connected ? colors.accent : colors.blue;
    final icon = squircle || connected
        ? (dark ? colors.paper : Colors.white)
        : (status == CoreStatus.connecting ? colors.accent : colors.muted);
    final shape = squircle
        ? AppShape.all(38)
        : RoundedSuperellipseBorder(
            borderRadius: AppRadius.full,
            side: skin == ZolnitSkin.linux
                ? BorderSide(color: colors.accent.withValues(alpha: 0.28))
                : BorderSide.none,
          );
    return SizedBox.square(
      dimension: area,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingsPainter(
                color: squircle ? colors.accent : colors.ink,
                squircle: squircle,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: label,
            child: Material(
              color: fill,
              shape: shape,
              child: InkWell(
                customBorder: shape,
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Center(
                    child: GlyphIcon(
                      AppGlyphs.power,
                      size: squircle ? 44 : 32,
                      color: icon,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.color, required this.squircle});

  final Color color;
  final bool squircle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (squircle) {
      stroke.color = color.withValues(alpha: 0.3);
      for (final turn in const [-0.2, 0.18]) {
        canvas
          ..save()
          ..translate(center.dx, center.dy)
          ..rotate(turn)
          ..drawRSuperellipse(
            RSuperellipse.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: size.width - 4,
                height: size.height - 4,
              ),
              const Radius.circular(42),
            ),
            stroke,
          )
          ..restore();
      }
      return;
    }
    final radius = size.shortestSide / 2;
    canvas
      ..drawCircle(
        center,
        radius - 4,
        stroke..color = color.withValues(alpha: 0.1),
      )
      ..drawCircle(
        center,
        radius + 9,
        stroke..color = color.withValues(alpha: 0.07),
      );
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.squircle != squircle;
}

/// Soft concentric washes behind the dark membership card's corner.
class ZolnitMembershipArt extends StatelessWidget {
  const ZolnitMembershipArt({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: CustomPaint(painter: _WashPainter(), size: Size.infinite),
  );
}

class _WashPainter extends CustomPainter {
  const _WashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.9, size.height * 0.04);
    final reach = math.min(size.width, size.height * 1.4);
    for (final (radius, alpha) in [
      (reach * 0.82, 0.025),
      (reach * 0.6, 0.03),
      (reach * 0.38, 0.035),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_WashPainter oldDelegate) => false;
}
