import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'inherited.dart';

class CommonPopScope extends StatelessWidget {
  final Widget child;
  final FutureOr<bool> Function(BuildContext context)? onPop;
  final FutureOr<void> Function()? onPopSuccess;

  const CommonPopScope({
    super.key,
    required this.child,
    this.onPop,
    this.onPopSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final hasBackLayer = route?.willHandlePopInternally == true;
    return PopScope(
      canPop: onPop == null || hasBackLayer,
      onPopInvokedWithResult: onPop == null
          ? null
          : (didPop, _) async {
              if (didPop) {
                return;
              }
              final res = await onPop!(context);
              if (!context.mounted) {
                return;
              }
              if (!res) {
                return;
              }
              Navigator.of(context).pop();
              if (onPopSuccess != null) {
                await onPopSuccess!();
              }
            },
      child: child,
    );
  }
}

class BackLayerScope extends StatefulWidget {
  final Widget child;
  final VoidCallback onBack;
  final bool Function()? onBackIntercept;
  @visibleForTesting
  final void Function(void Function(Duration) callback)?
  schedulePostFrameCallback;

  const BackLayerScope({
    super.key,
    required this.onBack,
    this.onBackIntercept,
    required this.child,
    @visibleForTesting this.schedulePostFrameCallback,
  });

  @override
  State<BackLayerScope> createState() => _BackLayerScopeState();
}

class _BackLayerScopeState extends State<BackLayerScope> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;
  bool _isDetaching = false;
  bool _isPageActive = true;
  int _syncRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final isPageActive = PageActivityScope.isActiveOf(context);
    if (identical(_route, route) && _isPageActive == isPageActive) {
      return;
    }
    _detach();
    _route = route;
    _isPageActive = isPageActive;
    final revision = ++_syncRevision;
    final schedulePostFrameCallback =
        widget.schedulePostFrameCallback ??
        WidgetsBinding.instance.addPostFrameCallback;
    schedulePostFrameCallback((_) {
      if (!mounted || revision != _syncRevision) {
        return;
      }
      if (!_isPageActive) {
        widget.onBack();
        return;
      }
      if (route == null) {
        return;
      }
      _installEntry(route);
    });
  }

  void _installEntry(ModalRoute<dynamic> route) {
    if (_entry != null) return;
    final entry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: _handleRemove,
    );
    _entry = entry;
    route.addLocalHistoryEntry(entry);
  }

  void _handleRemove() {
    _entry = null;
    if (!_isDetaching && mounted) {
      if (widget.onBackIntercept?.call() == true) {
        final route = _route;
        if (mounted &&
            _isPageActive &&
            route != null &&
            route.navigator != null) {
          _installEntry(route);
        }
      } else {
        widget.onBack();
      }
    }
  }

  void _detach() {
    final entry = _entry;
    if (entry == null) {
      return;
    }
    _entry = null;
    _isDetaching = true;
    entry.remove();
    _isDetaching = false;
  }

  @override
  void dispose() {
    _syncRevision++;
    _detach();
    _route = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _BackLayerIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): _BackLayerIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): _BackLayerIntent(),
      },
      child: Actions(
        actions: {
          _BackLayerIntent: CallbackAction<_BackLayerIntent>(
            onInvoke: (_) => Navigator.of(context).maybePop(),
          ),
        },
        child: widget.child,
      ),
    );
  }
}

class _BackLayerIntent extends Intent {
  const _BackLayerIntent();
}
