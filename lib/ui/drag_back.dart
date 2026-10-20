import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const double _flingVelocity = 1.0;
const Duration _settleDuration = Duration(milliseconds: 350);
const double _dragEdge = 1e-6;

final Animatable<Offset> _slideTween = Tween<Offset>(
  begin: const Offset(1.0, 0.0),
  end: Offset.zero,
);
const Animation<Offset> _noSlide = AlwaysStoppedAnimation(Offset.zero);

/// Nested scrollables, sliders and fields join the arena before this route drag.
mixin DragBackRouteMixin<T> on ModalRoute<T> {
  bool _dragBackActive = false;

  /// Supplies a result for gesture pops without vetoing the pop.
  ValueGetter<Object?>? pageResult;

  @override
  T? get currentResult => pageResult?.call() as T?;

  /// Keeps the transition linear through the drag and release settling.
  bool get isDragBackActive => _dragBackActive;

  @protected
  void didStartDragBack() {}

  /// Called once the route has settled after a drag back, popped or not.
  @protected
  void didEndDragBack() {}

  Widget dragBackDetector(Widget child) {
    return _DragBackDetector(route: this, child: child);
  }

  /// Keep this wrapper mounted: adding a parent when dragging starts
  /// would rebuild the page.
  Widget dragBackSlide(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return SlideTransition(
      position: _dragBackActive ? animation.drive(_slideTween) : _noSlide,
      textDirection: Directionality.of(context),
      child: child,
    );
  }

  // popGestureEnabled no longer excludes covered or settling routes;
  // NavigatorResizable must not settle beneath an active gesture.
  bool get _canDragBack =>
      isCurrent &&
      popGestureEnabled &&
      secondaryAnimation!.isDismissed &&
      !popGestureInProgress;

  void _startDragBack() {
    _dragBackActive = true;
    didStartDragBack();
    navigator!.didStartUserGesture();
  }

  // Mid-drag endpoints finalize route opacity or OpenContainer ownership
  // early; only release may settle the last bit.
  void _updateDragBack(double delta) {
    final controller = this.controller!;
    controller.value = clampDouble(
      controller.value - delta,
      _dragEdge,
      1 - _dragEdge,
    );
  }

  void _endDragBack(double velocity) {
    final controller = this.controller!;
    final navigator = this.navigator!;
    final bool settleForward;
    if (!isCurrent) {
      settleForward = isActive;
    } else if (velocity.abs() >= _flingVelocity) {
      settleForward = velocity <= 0;
    } else {
      settleForward = controller.value > 0.5;
    }
    if (settleForward) {
      controller.animateTo(
        1.0,
        duration: _settleDuration,
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _settleDuration,
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    }
    if (!controller.isAnimating) {
      _finishDragBack(navigator);
      return;
    }
    void handleStatus(AnimationStatus status) {
      if (status.isAnimating) {
        return;
      }
      controller.removeStatusListener(handleStatus);
      _finishDragBack(navigator);
    }

    controller.addStatusListener(handleStatus);
  }

  void _finishDragBack(NavigatorState navigator) {
    if (!_dragBackActive) {
      return;
    }
    _dragBackActive = false;
    didEndDragBack();
    navigator.didStopUserGesture();
  }

  void _abortDragBack() {
    final navigator = this.navigator;
    if (!_dragBackActive || navigator == null) {
      return;
    }
    _dragBackActive = false;
    didEndDragBack();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        navigator.didStopUserGesture();
      }
    });
  }
}

class _DragBackDetector extends StatefulWidget {
  const _DragBackDetector({required this.route, required this.child});

  final DragBackRouteMixin<dynamic> route;
  final Widget child;

  @override
  State<_DragBackDetector> createState() => _DragBackDetectorState();
}

class _DragBackDetectorState extends State<_DragBackDetector> {
  late final _DragBackGestureRecognizer _recognizer;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _recognizer = _DragBackGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_dragging) {
      widget.route._abortDragBack();
    }
    super.dispose();
  }

  double _toLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.route._canDragBack) {
      _recognizer.addPointer(event);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _dragging = true;
    widget.route._startDragBack();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragging) {
      return;
    }
    widget.route._updateDragBack(
      _toLogical(details.primaryDelta! / context.size!.width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    widget.route._endDragBack(
      _toLogical(details.velocity.pixelsPerSecond.dx / context.size!.width),
    );
  }

  void _handleDragCancel() {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    widget.route._endDragBack(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

// Desktop text fields select with a pan, which accepts past the pan slop.
class _DragBackGestureRecognizer extends HorizontalDragGestureRecognizer {
  _DragBackGestureRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows =>
        globalDistanceMoved.abs() >
            computePanSlop(pointerDeviceKind, gestureSettings),
      _ => super.hasSufficientGlobalDistanceToAccept(
        pointerDeviceKind,
        deviceTouchSlop,
      ),
    };
  }
}
