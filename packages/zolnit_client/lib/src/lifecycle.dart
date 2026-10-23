import 'dart:async';

import 'package:flutter/widgets.dart';

import 'checkout.dart';

class CheckoutLifecycleBinding with WidgetsBindingObserver {
  CheckoutLifecycleBinding(this.controller) {
    WidgetsBinding.instance.addObserver(this);
  }

  final CheckoutController controller;
  bool _closed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_closed && state == AppLifecycleState.resumed) {
      unawaited(controller.refresh());
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
