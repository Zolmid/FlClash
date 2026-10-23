import 'package:fl_clash/common/system.dart';
import 'package:material_ui/material_ui.dart';

/// The platform family a ZolNit screen takes its geometry from.
enum ZolnitSkin {
  macos,
  windows,
  linux,
  ios,
  android;

  static ZolnitSkin get host => system.isMacOS
      ? macos
      : system.isWindows
      ? windows
      : system.isLinux
      ? linux
      : system.isIOS
      ? ios
      : android;

  bool get desktop => this == macos || this == windows || this == linux;

  double get sidebarWidth => switch (this) {
    macos => 216,
    windows => 210,
    linux => 228,
    _ => 0,
  };

  double get panelCorner => switch (this) {
    macos => 18,
    windows => 8,
    linux => 10,
    ios => 25,
    android => 28,
  };

  double get tileCorner => switch (this) {
    macos => 18,
    windows => 8,
    linux => 10,
    ios => 19,
    android => 21,
  };

  double get controlCorner => switch (this) {
    macos => 8,
    windows => 5,
    linux => 6,
    ios => 22,
    android => 24,
  };

  double get badgeCorner => switch (this) {
    macos => 9,
    windows => 5,
    linux => 6,
    ios || android => 10,
  };

  double get gutter => switch (this) {
    macos || windows || linux => 30,
    ios => 19,
    android => 16,
  };

  static ZolnitSkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZolnitSkinScope>()?.skin ??
      host;
}

class ZolnitSkinScope extends InheritedWidget {
  const ZolnitSkinScope({super.key, required this.skin, required super.child});

  final ZolnitSkin skin;

  @override
  bool updateShouldNotify(ZolnitSkinScope oldWidget) => skin != oldWidget.skin;
}

/// The brand palette: warm paper, slate ink and the muted accent tints.
class ZolnitColors {
  const ZolnitColors({
    required this.paper,
    required this.solid,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentStrong,
    required this.sage,
    required this.blue,
    required this.clay,
    required this.lavender,
    required this.soft,
    required this.isDark,
  });

  static const light = ZolnitColors(
    paper: Color(0xfff3f1eb),
    solid: Color(0xfffaf9f5),
    ink: Color(0xff28363e),
    muted: Color(0xff53636b),
    accent: Color(0xff506a7a),
    accentStrong: Color(0xff3e596a),
    sage: Color(0xffdce5db),
    blue: Color(0xffdce5ed),
    clay: Color(0xffeadfd8),
    lavender: Color(0xffe4dfeb),
    soft: Color(0xffe9eeec),
    isDark: false,
  );

  static const dark = ZolnitColors(
    paper: Color(0xff151e24),
    solid: Color(0xff202c33),
    ink: Color(0xffe9efec),
    muted: Color(0xffa8b7bd),
    accent: Color(0xffabc7d6),
    accentStrong: Color(0xffc4d8e3),
    sage: Color(0xff2b3a33),
    blue: Color(0xff2b3b46),
    clay: Color(0xff3a322d),
    lavender: Color(0xff352f40),
    soft: Color(0xff2a373f),
    isDark: true,
  );

  static const membership = Color(0xff202c33);
  static const onMembership = Color(0xffe9efec);
  static const mutedOnMembership = Color(0xffa8b7bd);
  static const accentOnMembership = Color(0xffabc7d6);

  final Color paper;
  final Color solid;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentStrong;
  final Color sage;
  final Color blue;
  final Color clay;
  final Color lavender;
  final Color soft;
  final bool isDark;

  Color line([double alpha = 0.13]) => ink.withValues(alpha: alpha);

  static ZolnitColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
