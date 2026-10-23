import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bridge.dart';
import 'protocol.dart';

class ZolnitNativeSurface extends StatelessWidget {
  const ZolnitNativeSurface({
    super.key,
    required this.bridge,
    this.platform,
    this.brightness,
    this.visible = true,
  });

  final NativeUiBridge bridge;
  final TargetPlatform? platform;
  final Brightness? brightness;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final params = bridge.snapshot?.encode();
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android => AndroidView(
        viewType: nativeUiViewType,
        layoutDirection: Directionality.of(context),
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      TargetPlatform.iOS => UiKitView(
        viewType: nativeUiViewType,
        layoutDirection: Directionality.of(context),
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      ),
      TargetPlatform.macOS => AppKitView(
        key: ValueKey(brightness),
        viewType: nativeUiViewType,
        layoutDirection: Directionality.of(context),
        creationParams: {'snapshot': params, 'brightness': brightness?.name},
        creationParamsCodec: const StandardMessageCodec(),
      ),
      TargetPlatform.windows => _WindowsSurface(bridge: bridge),
      _ => const SizedBox.shrink(),
    };
  }
}

class _WindowsSurface extends StatefulWidget {
  const _WindowsSurface({required this.bridge});

  final NativeUiBridge bridge;

  @override
  State<_WindowsSurface> createState() => _WindowsSurfaceState();
}

class _WindowsSurfaceState extends State<_WindowsSurface>
    with WidgetsBindingObserver {
  Rect? _lastRect;
  double? _lastScale;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.bridge.showSurface());
    _scheduleBounds();
  }

  @override
  void didUpdateWidget(_WindowsSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bridge != widget.bridge) {
      unawaited(oldWidget.bridge.hideSurface());
      unawaited(widget.bridge.showSurface());
      _lastRect = null;
      _lastScale = null;
    }
    _scheduleBounds();
  }

  @override
  void didChangeMetrics() => _scheduleBounds();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.bridge.showSurface());
      _scheduleBounds();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.bridge.hideSurface());
    }
  }

  void _scheduleBounds() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final render = context.findRenderObject();
      if (render is! RenderBox || !render.hasSize) return;
      final rect = render.localToGlobal(Offset.zero) & render.size;
      final scale = View.of(context).devicePixelRatio;
      if (rect == _lastRect && scale == _lastScale) return;
      _lastRect = rect;
      _lastScale = scale;
      unawaited(widget.bridge.setSurfaceBounds(rect, scale));
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _scheduleBounds();
      return const SizedBox.expand();
    },
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.bridge.hideSurface());
    super.dispose();
  }
}
