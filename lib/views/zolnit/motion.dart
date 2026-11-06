import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// UIKit's presentation curve: answers at once and settles slowly.
const zolnitEase = Cubic(0.32, 0.72, 0, 1);

const zolnitQuick = Duration(milliseconds: 180);

const zolnitStandard = Duration(milliseconds: 280);

/// The leaving child takes no taps and leaves the semantics tree at once.
class ZolnitSwitcher extends StatelessWidget {
  const ZolnitSwitcher({
    super.key,
    required this.switchKey,
    this.duration = zolnitStandard,
    this.rise = 0,
    this.alignment = Alignment.topCenter,
    required this.child,
  });

  final Object switchKey;
  final Duration duration;
  final double rise;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: context.motionDuration(duration),
    switchInCurve: zolnitEase,
    switchOutCurve: zolnitEase,
    layoutBuilder: (current, previous) =>
        Stack(alignment: alignment, children: [...previous, ?current]),
    transitionBuilder: (child, animation) =>
        _Entry(animation: animation, rise: rise, child: child),
    child: KeyedSubtree(key: ValueKey(switchKey), child: child),
  );
}

class _Entry extends AnimatedWidget {
  const _Entry({
    required Animation<double> animation,
    required this.rise,
    required this.child,
  }) : super(listenable: animation);

  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final leaving = animation.status == AnimationStatus.reverse;
    return IgnorePointer(
      ignoring: leaving,
      child: ExcludeSemantics(
        excluding: leaving,
        child: Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, rise * (1 - animation.value)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A dialog route in the brand theme of [context], even when it is pushed on
/// the root navigator, entering as an iOS alert does.
RawDialogRoute<T> zolnitDialogRoute<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return RawDialogRoute<T>(
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.modalScrim,
    transitionDuration: context.motionDuration(zolnitStandard),
    pageBuilder: (dialogContext, _, _) =>
        SafeArea(child: themes.wrap(Builder(builder: builder))),
    transitionBuilder: (_, animation, _, child) {
      final curved = animation.drive(CurveTween(curve: zolnitEase));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showZolnitDialog<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(zolnitDialogRoute<T>(context, builder));

/// Closes the dialog holding [context] once: a second tap while it leaves
/// would otherwise pop the page beneath it.
void zolnitCloseDialog<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return;
  Navigator.of(context).pop(result);
}

/// An alert in the brand: a title, a message, and actions that close it once.
class ZolnitAlert extends StatelessWidget {
  const ZolnitAlert({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.cancelLabel,
    this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String? cancelLabel;
  final String? confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content:
          content ??
          (message == null
              ? null
              : SingleChildScrollView(child: Text(message!))),
      actions: [
        if (cancelLabel != null)
          TextButton(
            onPressed: () => zolnitCloseDialog(context, false),
            child: Text(cancelLabel!),
          ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.destructive,
                  foregroundColor: const Color(0xffffffff),
                )
              : null,
          onPressed: () => zolnitCloseDialog(context, true),
          child: Text(confirmLabel ?? text.confirm),
        ),
      ],
    );
  }
}
