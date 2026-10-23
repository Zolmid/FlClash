import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'brand.dart';
import 'kit.dart';
import 'skin.dart';

class ZolnitSidebar extends StatelessWidget {
  const ZolnitSidebar({
    super.key,
    required this.labels,
    required this.glyphs,
    required this.selected,
    required this.onSelected,
    required this.onHelp,
    required this.onPreferences,
  });

  final List<String> labels;
  final List<Glyph> glyphs;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onHelp;
  final VoidCallback onPreferences;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final text = context.appLocalizations;
    return SizedBox(
      width: skin.sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.ink.withValues(alpha: 0.03),
            colors.paper,
          ),
          border: Border(right: BorderSide(color: colors.line(0.08))),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(23, 28, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ZolnitBrand(width: 150),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  text.zolnitWorkspace,
                  style: zolnitText(
                    context,
                    10,
                    leading: 14,
                    weight: FontWeight.w600,
                    color: colors.muted,
                    spacing: 1.6,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _NavItem(
                        glyph: glyphs[i],
                        label: labels[i],
                        selected: i == selected,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
            _SidebarLink(
              glyph: AppGlyphs.help,
              label: text.zolnitHelpSupport,
              onTap: onHelp,
            ),
            _SidebarLink(
              glyph: AppGlyphs.settings,
              label: text.zolnitPreferences,
              onTap: onPreferences,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Glyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (height, corner, inset, fill, active) = switch (skin) {
      ZolnitSkin.macos => (
        36.0,
        8.0,
        12.0,
        colors.blue.withValues(alpha: 0.88),
        colors.ink,
      ),
      ZolnitSkin.windows => (
        38.0,
        5.0,
        15.0,
        colors.blue.withValues(alpha: 0.74),
        colors.ink,
      ),
      _ => (42.0, 6.0, 13.0, colors.accent, dark ? colors.paper : Colors.white),
    };
    final color = selected ? active : colors.muted;
    final shape = AppShape.all(corner);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? fill : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (skin == ZolnitSkin.windows && selected)
                  PositionedDirectional(
                    start: 0,
                    top: (height - 16) / 2,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.accent,
                        shape: AppShape.full,
                      ),
                      child: const SizedBox(width: 3, height: 16),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: Row(
                    children: [
                      GlyphIcon(glyph, size: 18, color: color),
                      const SizedBox(width: 13),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            13,
                            weight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final Glyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: InkWell(
        customBorder: AppShape.sm,
        onTap: onTap,
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GlyphIcon(glyph, size: 18, color: colors.muted),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: zolnitText(context, 13, color: colors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ZolnitTopBar extends StatelessWidget {
  const ZolnitTopBar({
    super.key,
    required this.compact,
    required this.title,
    required this.showBrand,
    required this.initial,
    required this.busy,
    required this.onRefresh,
    required this.onNotices,
    required this.onHelp,
    required this.onAccount,
  });

  final bool compact;
  final String title;
  final bool showBrand;
  final String initial;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onNotices;
  final VoidCallback onHelp;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final text = context.appLocalizations;
    final phone = compact || !skin.desktop;
    final height = switch (skin) {
      ZolnitSkin.macos => 62.0,
      ZolnitSkin.windows => 58.0,
      ZolnitSkin.linux => 64.0,
      ZolnitSkin.ios => 68.0,
      ZolnitSkin.android => 72.0,
    };
    final background = switch (skin) {
      ZolnitSkin.macos => colors.solid.withValues(alpha: 0.65),
      ZolnitSkin.windows => colors.paper.withValues(alpha: 0.88),
      ZolnitSkin.linux => colors.solid,
      ZolnitSkin.ios => colors.solid.withValues(alpha: 0.84),
      ZolnitSkin.android => colors.paper,
    };
    final side = phone ? 0.0 : 1.0;
    final Widget leading;
    if (phone && showBrand) {
      leading = const Align(
        alignment: AlignmentDirectional.centerStart,
        child: ZolnitBrand(width: 112),
      );
    } else if (skin == ZolnitSkin.windows || skin == ZolnitSkin.linux) {
      leading = Row(
        children: [
          Text(
            text.zolnitMySpace,
            style: zolnitText(context, 12, color: colors.muted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GlyphIcon(
              AppGlyphs.chevronForward,
              size: 14,
              color: colors.muted,
            ),
          ),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zolnitText(context, 12, weight: FontWeight.w500),
            ),
          ),
        ],
      );
    } else {
      leading = Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: zolnitText(
            context,
            phone ? 20 : 14,
            leading: phone ? 26 : 20,
            weight: FontWeight.w600,
          ),
        ),
      );
    }
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(
          tooltip: text.zolnitRefresh,
          glyph: AppGlyphs.refresh,
          onPressed: busy ? null : onRefresh,
        ),
        _BarButton(
          tooltip: text.zolnitNotices,
          glyph: AppGlyphs.bell,
          onPressed: onNotices,
        ),
        if (!phone)
          _BarButton(
            tooltip: text.zolnitHelpSupport,
            glyph: AppGlyphs.help,
            onPressed: onHelp,
          ),
        _Avatar(initial: initial, onTap: onAccount),
      ],
    );
    final trailing = skin == ZolnitSkin.macos && !phone
        ? DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.solid.withValues(alpha: 0.63),
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadius.all(13),
                side: BorderSide(
                  color: colors.isDark
                      ? colors.line(0.12)
                      : const Color(0x90ffffff),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 5, 4),
              child: buttons,
            ),
          )
        : buttons;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: colors.line(0.06 * side))),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: phone && skin.desktop ? 20 : skin.gutter,
            ),
            child: Row(
              children: [
                Expanded(child: leading),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.glyph,
    required this.onPressed,
  });

  final String tooltip;
  final Glyph glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final size = switch (skin) {
      ZolnitSkin.ios => 44.0,
      ZolnitSkin.android => 48.0,
      ZolnitSkin.linux => 34.0,
      _ => 32.0,
    };
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
      ),
      icon: GlyphIcon(glyph, size: 18, color: colors.muted),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final text = context.appLocalizations;
    final size = switch (skin) {
      ZolnitSkin.macos => 28.0,
      ZolnitSkin.windows => 34.0,
      ZolnitSkin.linux => 31.0,
      ZolnitSkin.ios => 44.0,
      ZolnitSkin.android => 48.0,
    };
    final shape = skin == ZolnitSkin.linux ? AppShape.all(6) : AppShape.circle;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        button: true,
        label: text.account,
        child: Material(
          color: skin.desktop ? colors.blue : Colors.transparent,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Text(
                  initial,
                  style: zolnitText(
                    context,
                    skin == ZolnitSkin.macos ? 11 : 13,
                    weight: FontWeight.w600,
                    color: colors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
