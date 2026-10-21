import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class ZolnitBrand extends StatelessWidget {
  const ZolnitBrand({super.key, this.width = 152});

  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      'assets/images/zolnit-horizontal-${dark ? 'dark' : 'light'}.svg',
      width: width,
      semanticsLabel: 'ZolNit',
    );
  }
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
  const ZolnitFailureMessage({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => visible
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            context.appLocalizations.zolnitFailure,
            style: AppTextStyle.body
                .of(context)
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        )
      : const SizedBox.shrink();
}
