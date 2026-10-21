import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

enum CheckoutStage {
  idle,
  launching,
  awaitingPayment,
  qr,
  processing,
  completed,
  cancelled,
  failed,
}

enum StripeWallet { card, alipay, wechatPay }

class PaymentQr {
  PaymentQr({required this.payload, required this.expiresAt}) {
    if (payload.isEmpty || payload.length > 8192) {
      throw const ClientFailure('invalid_qr');
    }
  }

  final String payload;
  final DateTime expiresAt;

  bool isValidAt(DateTime now) => expiresAt.isAfter(now);

  @override
  String toString() => 'PaymentQr([redacted])';
}

sealed class CheckoutAction {
  const CheckoutAction({this.fallbackQr});

  final PaymentQr? fallbackQr;
}

class HostedCheckout extends CheckoutAction {
  const HostedCheckout(this.uri, {super.fallbackQr});

  final Uri uri;
}

class QrCheckout extends CheckoutAction {
  const QrCheckout(PaymentQr qr) : super(fallbackQr: qr);
}

class StatusOnlyCheckout extends CheckoutAction {
  const StatusOnlyCheckout();
}

class StripeCheckout extends CheckoutAction {
  StripeCheckout({
    required this.publishableKey,
    required this.clientSecret,
    required this.wallet,
    required this.returnUri,
    this.wechatAppId,
    super.fallbackQr,
  }) {
    if (!RegExp(r'^pk_(test|live)_[A-Za-z0-9]+$').hasMatch(publishableKey) ||
        !RegExp(
          r'^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$',
        ).hasMatch(clientSecret) ||
        returnUri.scheme != 'zolnit' ||
        returnUri.host != 'safepay' ||
        returnUri.path.isNotEmpty ||
        returnUri.hasPort ||
        returnUri.userInfo.isNotEmpty ||
        returnUri.hasQuery ||
        returnUri.hasFragment ||
        (wallet == StripeWallet.wechatPay &&
            !RegExp(r'^wx[A-Za-z0-9]+$').hasMatch(wechatAppId ?? ''))) {
      throw const ClientFailure('invalid_stripe_action');
    }
  }

  final String publishableKey;
  final String clientSecret;
  final StripeWallet wallet;
  final Uri returnUri;
  final String? wechatAppId;

  @override
  String toString() => 'StripeCheckout($wallet, [redacted])';
}

abstract interface class CheckoutBackend {
  Future<CheckoutAction> start(String tradeNo, int methodId);
  Future<int> status(String tradeNo);
}

abstract interface class RecurringCheckoutBackend implements CheckoutBackend {
  Future<CheckoutAction> startRecurring(
    String tradeNo,
    int methodId, {
    required Json approvedTerms,
  });
}

abstract interface class CheckoutPlatform {
  Future<bool> open(Uri uri);
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  });
}

class CheckoutController extends ChangeNotifier {
  CheckoutController({
    required this.backend,
    required this.platform,
    required Set<String> allowedHttpsOrigins,
    required this.allowStripe,
    DateTime Function()? now,
  }) : _allowedHttpsOrigins = Set.unmodifiable(allowedHttpsOrigins),
       _now = now ?? DateTime.now;

  final CheckoutBackend backend;
  final CheckoutPlatform platform;
  final bool allowStripe;
  final Set<String> _allowedHttpsOrigins;
  final DateTime Function() _now;
  CheckoutStage _stage = CheckoutStage.idle;
  PaymentQr? _qr;
  String? _tradeNo;
  String? _failure;
  String? _failureMessage;
  CheckoutStage get stage => _stage;
  PaymentQr? get qr => _qr;
  String? get tradeNo => _tradeNo;
  String? get failure => _failure;
  String? get failureMessage => _failureMessage;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _active;
  Future<void>? _refreshing;

  bool _current(int generation) => !_disposed && generation == _generation;

  void _set(CheckoutStage value) {
    _stage = value;
    notifyListeners();
  }

  Future<void> start(String tradeNo, int methodId, {Json? recurringTerms}) {
    if (_disposed) return Future.error(const ClientFailure('closed'));
    if (!allowStripe) {
      return Future.error(
        const ClientFailure('stripe_disabled_for_distribution'),
      );
    }
    if (_active != null) {
      if (this.tradeNo != tradeNo) {
        return Future.error(const ClientFailure('purchase_in_progress'));
      }
      return _active!;
    }
    _tradeNo = tradeNo;
    final generation = ++_generation;
    _qr = null;
    _failure = null;
    _failureMessage = null;
    final operation = Future<void>.microtask(
      () => _start(tradeNo, methodId, generation, recurringTerms),
    );
    _active = operation;
    return operation.whenComplete(() {
      if (_current(generation)) _active = null;
    });
  }

  Future<void> _start(
    String tradeNo,
    int methodId,
    int generation,
    Json? recurringTerms,
  ) async {
    if (!_current(generation)) return;
    _set(CheckoutStage.launching);
    if (!_current(generation)) return;
    CheckoutAction? action;
    try {
      if (recurringTerms != null) {
        final recurringBackend = backend;
        if (recurringBackend is! RecurringCheckoutBackend) {
          throw const ClientFailure('recurring_unavailable');
        }
        action = await recurringBackend.startRecurring(
          tradeNo,
          methodId,
          approvedTerms: recurringTerms,
        );
      } else {
        action = await backend.start(tradeNo, methodId);
      }
      if (!_current(generation)) return;
      switch (action) {
        case HostedCheckout(:final uri):
          if (uri.scheme != 'https' ||
              uri.userInfo.isNotEmpty ||
              !_allowedHttpsOrigins.contains(uri.origin)) {
            throw const ClientFailure('untrusted_checkout_url');
          }
          if (!await platform.open(uri)) {
            throw const ClientFailure('launch_unavailable');
          }
        case StripeCheckout():
          await platform.confirmStripe(
            action,
            isCurrent: () => _current(generation),
          );
        case QrCheckout():
          _showQr(action);
          return;
        case StatusOnlyCheckout():
          break;
      }
      if (!_current(generation)) return;
      _qr = action.fallbackQr;
      _set(CheckoutStage.awaitingPayment);
      await refresh();
    } on ClientFailure catch (error) {
      if (!_current(generation)) return;
      _failure = error.code;
      _failureMessage = error.serverMessage;
      if ({'user_cancelled', 'confirmation_pending'}.contains(error.code)) {
        _qr = action?.fallbackQr;
        _set(CheckoutStage.awaitingPayment);
        await refresh();
      } else if ({
            'launch_unavailable',
            'sdk_unavailable',
            'wallet_unavailable',
          }.contains(error.code) &&
          action?.fallbackQr?.isValidAt(_now()) == true) {
        _showQr(action!);
      } else {
        _set(CheckoutStage.failed);
      }
    } catch (_) {
      if (!_current(generation)) return;
      _failure = 'payment_error';
      _set(CheckoutStage.failed);
    }
  }

  void _showQr(CheckoutAction action) {
    final qr = action.fallbackQr;
    if (qr == null || !qr.isValidAt(_now())) {
      throw const ClientFailure('qr_expired');
    }
    _qr = qr;
    _set(CheckoutStage.qr);
  }

  void showFallbackQr() {
    if (_disposed ||
        {CheckoutStage.completed, CheckoutStage.cancelled}.contains(stage)) {
      return;
    }
    final value = qr;
    if (value == null || !value.isValidAt(_now())) {
      _failure = 'qr_expired';
      _set(CheckoutStage.failed);
      return;
    }
    _set(CheckoutStage.qr);
  }

  Future<void> refresh() {
    if (_disposed || tradeNo == null) return Future.value();
    if (_refreshing != null) return _refreshing!;
    final generation = _generation;
    final currentTradeNo = tradeNo!;
    final operation = Future<void>.microtask(
      () => _refresh(currentTradeNo, generation),
    );
    _refreshing = operation;
    return operation.whenComplete(() {
      if (_current(generation)) _refreshing = null;
    });
  }

  Future<void> _refresh(String tradeNo, int generation) async {
    if (!_current(generation)) return;
    try {
      final status = await backend.status(tradeNo);
      if (!_current(generation)) return;
      switch (status) {
        case 0:
          _set(
            qr?.isValidAt(_now()) == true && stage == CheckoutStage.qr
                ? CheckoutStage.qr
                : CheckoutStage.awaitingPayment,
          );
        case 1:
          _set(CheckoutStage.processing);
        case 2:
          _qr = null;
          _set(CheckoutStage.cancelled);
        case 3:
          _qr = null;
          _set(CheckoutStage.completed);
        case 4:
          _failure = 'order_credited';
          _qr = null;
          _set(CheckoutStage.cancelled);
        default:
          throw const ClientFailure('invalid_order_status');
      }
    } on ClientFailure catch (error) {
      if (!_current(generation)) return;
      _failure = error.code;
      _set(CheckoutStage.failed);
    } catch (_) {
      if (!_current(generation)) return;
      _failure = 'network';
      _set(CheckoutStage.failed);
    }
  }

  Future<void> poll({
    Duration interval = const Duration(seconds: 3),
    int attempts = 40,
  }) async {
    if (interval.isNegative || attempts < 1 || attempts > 100) {
      throw const ClientFailure('invalid_poll_options');
    }
    final generation = _generation;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (!_current(generation) ||
          {CheckoutStage.completed, CheckoutStage.cancelled}.contains(stage)) {
        return;
      }
      await refresh();
      if (failure == 'unauthenticated') return;
      if (attempt + 1 < attempts) await Future<void>.delayed(interval);
    }
  }

  void reset() {
    _generation++;
    _active = null;
    _refreshing = null;
    _tradeNo = null;
    _qr = null;
    _failure = null;
    _failureMessage = null;
    if (!_disposed) _set(CheckoutStage.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
