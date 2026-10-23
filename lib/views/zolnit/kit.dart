import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'skin.dart';

TextStyle zolnitText(
  BuildContext context,
  double size, {
  double? leading,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? spacing,
}) =>
    AppTextStyle.custom(
      context,
      size: size,
      leading: leading ?? (size * 1.45).roundToDouble(),
      weight: weight,
    ).copyWith(
      color: color ?? ZolnitColors.of(context).ink,
      letterSpacing: spacing,
    );

BorderSide zolnitHairline(ZolnitSkin skin, ZolnitColors colors) =>
    switch (skin) {
      ZolnitSkin.macos => BorderSide(color: colors.line(0.10)),
      ZolnitSkin.windows ||
      ZolnitSkin.linux => BorderSide(color: colors.line()),
      ZolnitSkin.ios => BorderSide(
        color: colors.isDark ? colors.line(0.12) : const Color(0x80ffffff),
      ),
      ZolnitSkin.android => BorderSide.none,
    };

EdgeInsets zolnitPagePadding(ZolnitSkin skin, {required bool compact}) {
  final gutter = skin.desktop && compact ? 20.0 : skin.gutter;
  return EdgeInsets.fromLTRB(
    gutter,
    skin.desktop ? 28 : 22,
    gutter,
    skin.desktop ? 32 : 24,
  );
}

class ZolnitPageHeading extends StatelessWidget {
  const ZolnitPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final (weight, size) = switch (skin) {
      ZolnitSkin.macos || ZolnitSkin.windows => (FontWeight.w600, 27.0),
      ZolnitSkin.linux => (FontWeight.w700, 25.0),
      ZolnitSkin.ios => (FontWeight.w700, 34.0),
      ZolnitSkin.android => (FontWeight.w500, 31.0),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: zolnitText(
                  context,
                  size,
                  leading: size * 1.3,
                  weight: weight,
                ),
              ),
              SizedBox(height: skin.desktop ? 6 : 10),
              Text(
                subtitle,
                style: zolnitText(
                  context,
                  skin.desktop ? 12 : 13,
                  color: colors.muted,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class ZolnitCard extends StatelessWidget {
  const ZolnitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.corner,
    this.radius,
    this.bordered = true,
    this.side,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? corner;
  final BorderRadius? radius;
  final bool bordered;
  final BorderSide? side;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: ShapeDecoration(
        color: color ?? colors.solid,
        shape: RoundedSuperellipseBorder(
          borderRadius: radius ?? AppRadius.all(corner ?? skin.panelCorner),
          side:
              side ??
              (bordered ? zolnitHairline(skin, colors) : BorderSide.none),
        ),
      ),
      child: child,
    );
  }
}

class ZolnitPill extends StatelessWidget {
  const ZolnitPill({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final square = skin == ZolnitSkin.windows || skin == ZolnitSkin.linux;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background ?? colors.soft,
        shape: AppShape.all(square ? 4 : 20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          style: zolnitText(
            context,
            11,
            leading: 15,
            weight: FontWeight.w500,
            color: foreground ?? colors.muted,
          ),
        ),
      ),
    );
  }
}

class ZolnitIconTile extends StatelessWidget {
  const ZolnitIconTile({
    super.key,
    required this.glyph,
    required this.tint,
    this.size = 36,
    this.iconSize = 18,
    this.color,
    this.corner,
  });

  final Glyph glyph;
  final Color tint;
  final double size;
  final double iconSize;
  final Color? color;
  final double? corner;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tint,
        shape: AppShape.all(corner ?? skin.badgeCorner + 1),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: GlyphIcon(glyph, size: iconSize, color: color ?? colors.muted),
        ),
      ),
    );
  }
}

class ZolnitFlagBadge extends StatelessWidget {
  const ZolnitFlagBadge({
    super.key,
    required this.flag,
    required this.label,
    this.size = 34,
  });

  final String? flag;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final fill = switch (skin) {
      ZolnitSkin.macos => colors.blue,
      ZolnitSkin.linux => colors.paper,
      _ => colors.soft,
    };
    final initial = label.isEmpty ? '' : label.characters.first.toUpperCase();
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: AppShape.all(skin.badgeCorner),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: flag == null
              ? Text(
                  initial,
                  style: zolnitText(
                    context,
                    size * 0.42,
                    weight: FontWeight.w600,
                    color: colors.muted,
                  ),
                )
              : Text(
                  flag!,
                  style: AppTextStyle.custom(
                    context,
                    size: size * 0.55,
                    leading: size * 0.7,
                  ).copyWith(fontFamily: FontFamily.twEmoji.value),
                ),
        ),
      ),
    );
  }
}

class ZolnitSegmented<T> extends StatelessWidget {
  const ZolnitSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.underlined = false,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool underlined;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final phone = !skin.desktop;
    final (
      track,
      side,
      corner,
      inset,
      selectedFill,
      selectedCorner,
    ) = switch (skin) {
      ZolnitSkin.macos => (
        colors.blue.withValues(alpha: 0.58),
        BorderSide(color: colors.line(0.07)),
        8.0,
        2.0,
        colors.solid,
        6.0,
      ),
      ZolnitSkin.windows => (
        Colors.transparent,
        BorderSide(color: colors.line()),
        4.0,
        0.0,
        colors.blue,
        0.0,
      ),
      ZolnitSkin.linux => (
        colors.solid,
        BorderSide(color: colors.line()),
        5.0,
        0.0,
        colors.accent,
        0.0,
      ),
      ZolnitSkin.ios => (
        colors.isDark ? colors.soft : const Color(0xffe8eceb),
        BorderSide.none,
        12.0,
        3.0,
        colors.solid,
        9.0,
      ),
      ZolnitSkin.android => (
        Colors.transparent,
        BorderSide(color: colors.accent.withValues(alpha: 0.333)),
        26.0,
        0.0,
        colors.solid,
        0.0,
      ),
    };
    final onAccent = skin == ZolnitSkin.linux;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(underlined ? 0 : inset),
      decoration: ShapeDecoration(
        color: underlined ? Colors.transparent : track,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppRadius.all(underlined ? AppCorner.none : corner),
          side: underlined ? BorderSide.none : side,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (option, label) in options)
            Flexible(
              child: Semantics(
                button: true,
                selected: option == value,
                child: Material(
                  color: !underlined && option == value
                      ? selectedFill
                      : Colors.transparent,
                  shape: AppShape.all(selectedCorner),
                  child: InkWell(
                    customBorder: AppShape.all(selectedCorner),
                    onTap: () => onChanged(option),
                    child: Container(
                      height: phone
                          ? (skin == ZolnitSkin.ios ? 44 : 48)
                          : (underlined ? 38 : 28),
                      decoration: underlined
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: option == value
                                      ? colors.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            )
                          : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 14 : 11,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: zolnitText(
                              context,
                              phone ? 12 : 11,
                              weight: option == value
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: underlined
                                  ? (option == value
                                        ? colors.accent
                                        : colors.muted)
                                  : option == value && onAccent
                                  ? Colors.white
                                  : colors.ink,
                            ),
                          ),
                        ),
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

class ZolnitButton extends StatelessWidget {
  const ZolnitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
    this.primary = false,
    this.expand = false,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Glyph? glyph;
  final bool primary;
  final bool expand;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill;
    final Color foreground;
    final BorderSide side;
    if (onDark) {
      fill = Colors.white.withValues(alpha: 0.082);
      foreground = ZolnitColors.onMembership;
      side = BorderSide(color: Colors.white.withValues(alpha: 0.1));
    } else if (primary) {
      fill = colors.accent;
      foreground = dark ? colors.paper : Colors.white;
      side = BorderSide.none;
    } else {
      fill = colors.solid;
      foreground = colors.ink;
      side = BorderSide(color: colors.line());
    }
    final shape = RoundedSuperellipseBorder(
      borderRadius: AppRadius.all(skin.controlCorner),
      side: side,
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: fill,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            height: skin.desktop ? 38 : 48,
            width: expand ? double.infinity : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zolnitText(
                        context,
                        skin.desktop ? 12 : 14,
                        weight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (glyph != null) ...[
                    const SizedBox(width: 8),
                    GlyphIcon(glyph!, size: 16, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ZolnitUsageBar extends StatelessWidget {
  const ZolnitUsageBar({super.key, required this.fraction, this.height = 5});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        shape: AppShape.full,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: ShapeDecoration(
              color: ZolnitColors.accentOnMembership,
              shape: AppShape.full,
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class ZolnitSectionHeading extends StatelessWidget {
  const ZolnitSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: zolnitText(
                  context,
                  skin.desktop ? 14 : 16,
                  leading: 20,
                  weight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: zolnitText(
                    context,
                    12,
                    leading: 17,
                    color: colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null)
          InkWell(
            customBorder: AppShape.sm,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionLabel != null) ...[
                    Text(
                      actionLabel!,
                      style: zolnitText(
                        context,
                        12,
                        leading: 17,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  GlyphIcon(
                    AppGlyphs.chevronForward,
                    size: 16,
                    color: colors.muted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ZolnitStatTile extends StatelessWidget {
  const ZolnitStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.glyph,
    required this.tint,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final Glyph glyph;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final phone = !skin.desktop;
    return ZolnitCard(
      corner: skin.tileCorner,
      padding: phone
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 19)
          : const EdgeInsets.symmetric(horizontal: 21, vertical: 19),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zolnitText(
                    context,
                    phone ? 10 : 11,
                    leading: phone ? 14 : 16,
                    color: colors.muted,
                  ),
                ),
                SizedBox(height: phone ? 12 : 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value),
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: zolnitText(
                            context,
                            11,
                            leading: 15,
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zolnitText(
                    context,
                    phone ? 23 : 24,
                    leading: phone ? 27 : 33,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!phone) ZolnitIconTile(glyph: glyph, tint: tint),
        ],
      ),
    );
  }
}
