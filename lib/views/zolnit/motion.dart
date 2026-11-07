import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// UIKit's presentation curve: answers at once and settles slowly.
const zolnitEase = Cubic(0.32, 0.72, 0, 1);

const zolnitQuick = Duration(milliseconds: 180);

const zolnitStandard = Duration(milliseconds: 280);

const zolnitPageDuration = Duration(milliseconds: 380);

/// A calmer spatial curve reserved for full-page navigation.
const zolnitPageEase = Cubic(0.22, 0.1, 0.22, 1);

enum ZolnitPageDirection { forward, back }

ZolnitPageDirection zolnitPageDirection(int from, int to) =>
    to >= from ? ZolnitPageDirection.forward : ZolnitPageDirection.back;

/// A tab/page replacement with one opaque outgoing and one opaque incoming
/// page. Their edges meet throughout the transition, rather than cross-fading.
class ZolnitPageSwitcher extends StatefulWidget {
  const ZolnitPageSwitcher({
    super.key,
    required this.switchKey,
    required this.direction,
    required this.child,
    this.duration = zolnitPageDuration,
  });

  final Object switchKey;
  final ZolnitPageDirection direction;
  final Widget child;
  final Duration duration;

  @override
  State<ZolnitPageSwitcher> createState() => _ZolnitPageSwitcherState();
}

class _ZolnitPageSwitcherState extends State<ZolnitPageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Widget _incoming;
  Widget? _outgoing;
  late Object _activeKey;
  Object? _outgoingKey;
  late ZolnitPageDirection _activeDirection;
  ({Widget child, Object key, ZolnitPageDirection direction})? _pending;
  Offset _incomingStart = Offset.zero;
  Offset _outgoingStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _incoming = widget.child;
    _activeKey = widget.switchKey;
    _activeDirection = widget.direction;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _outgoing != null) {
          setState(() {
            _outgoing = null;
            final next = _pending;
            _pending = null;
            if (next != null) _begin(next.child, next.key, next.direction);
          });
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.disableAnimations) {
      _controller.stop();
      _outgoing = null;
      _pending = null;
      _incoming = widget.child;
      _activeKey = widget.switchKey;
      _incomingStart = Offset.zero;
    }
  }

  @override
  void didUpdateWidget(covariant ZolnitPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (_activeKey == widget.switchKey) {
      _incoming = widget.child;
      _pending = null;
      return;
    }
    if (context.disableAnimations) {
      _incoming = widget.child;
      _activeKey = widget.switchKey;
      _outgoing = null;
      _pending = null;
      _incomingStart = Offset.zero;
      _controller.value = 1;
      return;
    }
    if (_controller.isAnimating) {
      _pending = (
        child: widget.child,
        key: widget.switchKey,
        direction: widget.direction,
      );
    } else {
      _begin(widget.child, widget.switchKey, widget.direction);
    }
  }

  void _begin(Widget child, Object key, ZolnitPageDirection direction) {
    _outgoingKey = _activeKey;
    _activeKey = key;
    _activeDirection = direction;
    _outgoing = _incoming;
    _outgoingStart = Offset.zero;
    _incoming = child;
    _incomingStart = Offset(
      direction == ZolnitPageDirection.forward ? 1 : -1,
      0,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.disableAnimations) return _incoming;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = zolnitPageEase.transform(_controller.value);
          final direction = _activeDirection == ZolnitPageDirection.forward
              ? 1.0
              : -1.0;
          final outgoing = _outgoing;
          final outgoingOffset = Offset.lerp(
            _outgoingStart,
            Offset(-direction, 0),
            progress,
          )!;
          final incomingOffset = Offset.lerp(
            _incomingStart,
            Offset.zero,
            progress,
          )!;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (outgoing != null)
                _PageLayer(
                  key: ValueKey(_outgoingKey),
                  offset: outgoingOffset,
                  exiting: true,
                  child: outgoing,
                ),
              _PageLayer(
                key: ValueKey(_activeKey),
                offset: incomingOffset,
                child: _incoming,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageLayer extends StatelessWidget {
  const _PageLayer({
    super.key,
    required this.offset,
    required this.child,
    this.exiting = false,
  });

  final Offset offset;
  final Widget child;
  final bool exiting;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: exiting,
    child: ExcludeSemantics(
      excluding: exiting,
      child: FractionalTranslation(
        translation: offset,
        child: SizedBox.expand(child: child),
      ),
    ),
  );
}

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
