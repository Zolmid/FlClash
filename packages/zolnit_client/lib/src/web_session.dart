import 'dart:async';

import 'session.dart';

const zolnitWebLanding = 'https://link.zolmid.com/theme/ZolNit/app-login.html';
const zolnitWebOrigin = 'https://link.zolmid.com';
const zolnitWebDestinations = {
  '/',
  '/#/dashboard',
  '/theme/ZolNit/downloads.html',
};

abstract interface class ZolnitWebSessionBrowser {
  Future<bool> open(String code, String destination);
  Future<void> close();
}

class ZolnitWebSessionCoordinator {
  ZolnitWebSessionCoordinator({
    required this.session,
    required this.browser,
    required this.fallback,
    this.canAuthorize = true,
  }) : _generation = session.api.generation,
       _accountGeneration = session.accountGeneration {
    session.addListener(_sessionChanged);
  }

  final ZolnitSessionController session;
  final ZolnitWebSessionBrowser browser;
  final Future<bool> Function(Uri) fallback;
  final bool canAuthorize;
  int _generation;
  int _accountGeneration;
  int _epoch = 0;
  bool _disposed = false;
  Future<bool>? _flight;
  bool _browserActive = false;
  Future<void>? _closing;

  Future<void> _closeBrowser() {
    final closing = _closing;
    if (closing != null) return closing;
    if (!_browserActive) return Future.value();
    _browserActive = false;
    final operation = browser.close();
    _closing = operation;
    return operation.whenComplete(() {
      if (identical(_closing, operation)) _closing = null;
    });
  }

  void _sessionChanged() {
    if (_generation == session.api.generation &&
        _accountGeneration == session.accountGeneration &&
        session.authenticated) {
      return;
    }
    _generation = session.api.generation;
    _accountGeneration = session.accountGeneration;
    _epoch++;
    unawaited(_closeBrowser().catchError((Object _) {}));
  }

  Future<bool> open(Uri target) {
    if (_disposed) return Future.value(false);
    final pending = _flight;
    if (pending != null) return pending;
    final operation = _open(target);
    _flight = operation;
    return operation.whenComplete(() {
      if (identical(_flight, operation)) _flight = null;
    });
  }

  Future<bool> _open(Uri target) async {
    final destination = target.toString().startsWith(zolnitWebOrigin)
        ? target.toString().substring(zolnitWebOrigin.length)
        : '';
    if (!canAuthorize ||
        !zolnitWebDestinations.contains(destination) ||
        target.toString() != '$zolnitWebOrigin$destination' ||
        !session.authenticated ||
        session.api.origin.origin != zolnitWebOrigin) {
      return fallback(target);
    }
    final generation = session.api.generation;
    final accountGeneration = session.accountGeneration;
    final epoch = _epoch;
    bool current() =>
        !_disposed &&
        session.authenticated &&
        session.api.generation == generation &&
        session.accountGeneration == accountGeneration &&
        _epoch == epoch;
    try {
      await _closeBrowser();
      if (!current()) return false;
      final code = await session.api.authorizeWebSession();
      if (!current()) return false;
      _browserActive = true;
      final opened = await browser
          .open(code, destination)
          .timeout(
            const Duration(seconds: 18),
            onTimeout: () async {
              await _closeBrowser();
              return false;
            },
          );
      if (!current()) {
        await _closeBrowser();
        return false;
      }
      if (opened) return true;
      await _closeBrowser();
    } catch (_) {
      await _closeBrowser().catchError((Object _) {});
    }
    return current() ? fallback(target) : false;
  }

  void cancel() {
    _epoch++;
    unawaited(_closeBrowser().catchError((Object _) {}));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    session.removeListener(_sessionChanged);
    unawaited(_closeBrowser().catchError((Object _) {}));
  }
}
