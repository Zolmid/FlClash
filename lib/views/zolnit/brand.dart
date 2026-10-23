import 'dart:math' as math;

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'data.dart';

class ZolnitBrand extends StatelessWidget {
  const ZolnitBrand({super.key, this.width = 196, this.brightness});

  final double width;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    // The official renders keep the mark's surface filter, which flutter_svg drops.
    return Image.asset(
      'assets/images/zolnit-horizontal-${dark ? 'dark' : 'light'}.png',
      width: width,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'ZolNit',
    );
  }
}

abstract final class _BrandColors {
  static const Color dark = Color(0xff202c33);
  static const Color ink = Color(0xffe9efec);
  static const Color muted = Color(0xffa8b7bd);
}

class ZolnitBrandRegion extends StatelessWidget {
  const ZolnitBrandRegion({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    return ColoredBox(
      color: _BrandColors.dark,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 46),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ZolnitBrand(width: 255, brightness: Brightness.dark),
            const Spacer(flex: 2),
            _Eyebrow(label: text.zolnitLoginEyebrow),
            const SizedBox(height: 16),
            Text(
              text.zolnitTagline,
              style: AppTextStyle.largeTitle
                  .of(context, emphasized: true)
                  .copyWith(color: _BrandColors.ink),
            ),
            const SizedBox(height: 14),
            Text(
              text.zolnitLoginDescription,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(color: _BrandColors.muted, height: 1.6),
            ),
            const Spacer(),
            const _OrbitArt(),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _FeatureItem(
                    glyph: AppGlyphs.proxies,
                    title: text.zolnitGlobalRoutes,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _FeatureItem(
                    glyph: AppGlyphs.devices,
                    title: text.zolnitEveryScreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyle.caption2
          .of(context, emphasized: true)
          .copyWith(color: _BrandColors.muted, letterSpacing: 1.7),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.glyph, required this.title});

  final Glyph glyph;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlyphIcon(glyph, size: 18, color: _BrandColors.muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .copyWith(color: _BrandColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrbitArt extends StatelessWidget {
  const _OrbitArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: CustomPaint(
        size: const Size(double.infinity, 140),
        painter: _OrbitPainter(),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.45;
    final cy = size.height * 0.5;
    final outerRx = size.width * 0.38;
    final outerRy = size.height * 0.44;
    final innerRx = outerRx * 0.55;
    final innerRy = outerRy * 0.55;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _BrandColors.muted.withValues(alpha: 0.18);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: outerRx * 2,
        height: outerRy * 2,
      ),
      ringPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: innerRx * 2,
        height: innerRy * 2,
      ),
      ringPaint,
    );

    const dotAngle = -math.pi / 4;
    final dotX = cx + outerRx * math.cos(dotAngle);
    final dotY = cy + outerRy * math.sin(dotAngle);
    final dotPaint = Paint()..color = _BrandColors.ink.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZolnitPanel extends StatelessWidget {
  const ZolnitPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SurfaceScope(
    level: SurfaceLevel.card,
    child: Material(
      color: SurfaceLevel.card.colorOf(Theme.of(context).colorScheme),
      shape: AppShape.xl,
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

class ZolnitFailureMessage extends StatelessWidget {
  const ZolnitFailureMessage({
    super.key,
    required this.code,
    this.serverMessage,
    this.fallback,
  });

  final String? code;
  final String? serverMessage;
  final String? fallback;

  @override
  Widget build(BuildContext context) => code != null
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            zolnitFailureText(context, code, serverMessage, fallback: fallback),
            style: AppTextStyle.body
                .of(context)
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        )
      : const SizedBox.shrink();
}
