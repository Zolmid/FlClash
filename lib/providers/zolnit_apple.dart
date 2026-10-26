import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';
import 'package:intl/intl.dart';

final zolnitAppleStoreProvider = Provider<AppleStore>(
  (ref) => StoreKitGateway(),
);
final zolnitAppleBillingProvider = Provider<ZolnitAppleBilling>((ref) {
  final billing = ZolnitAppleBilling(
    ref.watch(zolnitSessionProvider),
    ref.read(zolnitAppleStoreProvider),
  );
  ref.onDispose(billing.dispose);
  return billing;
});

class ZolnitAppleBilling extends ChangeNotifier {
  ZolnitAppleBilling(this.session, this.store)
    : _accountGeneration = session.api.generation {
    session.addListener(_accountChanged);
  }
  final ZolnitSessionController session;
  final AppleStore store;
  int _accountGeneration;
  int _revision = 0;
  bool _disposed = false;
  bool loading = false;
  String? failure;
  AppleBillingConfig? config;
  ApplePurchaseController? controller;
  ApplePurchaseStage? _lastStage;
  Future<void>? _load;

  bool get isAppStore =>
      session.api.distribution == 'apple-app-store' &&
      const {'ios', 'macos'}.contains(session.api.clientPlatform);
  bool get busy => const {
    ApplePurchaseStage.purchasing,
    ApplePurchaseStage.pending,
    ApplePurchaseStage.verifying,
    ApplePurchaseStage.awaitingBackend,
    ApplePurchaseStage.restoring,
  }.contains(controller?.stage);

  Future<void> load() {
    if (_load != null) return _load!;
    if (_disposed || !isAppStore || !session.authenticated || busy) {
      return Future.value();
    }
    final revision = ++_revision;
    final operation = _loadConfiguration(revision);
    _load = operation;
    return operation.whenComplete(() {
      if (identical(_load, operation)) _load = null;
    });
  }

  bool _current(int revision) =>
      !_disposed &&
      revision == _revision &&
      session.authenticated &&
      session.api.generation == _accountGeneration;

  Future<void> _loadConfiguration(int revision) async {
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final client = XboardAppleBillingBackend(
        session.api,
        const AppleBillingPaths(),
      );
      final next = await client.config();
      if (!_current(revision)) return;
      final expected = session.clientBundleAccountId;
      if (expected != null && next.accountId != expected) {
        throw const ClientFailure('purchase_identity_mismatch');
      }
      _releaseController();
      config = next;
      if (next.available) {
        final purchase = ApplePurchaseController(
          store: store,
          backend: XboardAppleBillingBackend(
            session.api,
            AppleBillingPaths.fromConfig(next),
          ),
          productIds: next.productIds,
          enabled: true,
          confirmPurchase: (product, context) async {
            if (!_current(revision) ||
                context.accountId != next.accountId ||
                !const {
                  'start_paid_after_verified_payment',
                  'replace_gift_after_verified_payment',
                }.contains(context.entitlementEffect)) {
              return false;
            }
            if (context.entitlementEffect ==
                    'replace_gift_after_verified_payment' &&
                context.giftExpiresAt == null) {
              return false;
            }
            final text = currentAppLocalizations;
            final approved = await dialogs.showMessage(
              title: text.zolnitAppleAutoRenewal,
              message: TextSpan(
                text: [
                  product.title,
                  product.price,
                  text.zolnitAppleConsent,
                  if (context.entitlementEffect ==
                      'replace_gift_after_verified_payment')
                    text.zolnitGiftReplacement,
                  if (context.giftExpiresAt != null)
                    [
                      text.zolnitPlanValidity,
                      DateFormat.yMMMd().format(
                        context.giftExpiresAt!.toLocal(),
                      ),
                    ].join(': '),
                ].join('\n\n'),
              ),
              confirmText: text.zolnitAppleSubscribe,
            );
            return approved == true && _current(revision);
          },
        )..setAccount(next.accountId);
        controller = purchase;
        purchase.addListener(_purchaseChanged);
        await purchase.loadProducts();
      }
    } on ClientFailure catch (error) {
      if (_current(revision)) failure = error.code;
    } catch (_) {
      if (_current(revision)) failure = 'apple_unavailable';
    } finally {
      if (_current(revision)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> subscribe(String productId) => _perform(() async {
    await controller?.buy(productId);
  });
  Future<void> restore() => _perform(() async {
    await controller?.restore();
  });
  Future<void> retryVerification() => _perform(() async {
    await controller?.retryVerification();
  });

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } on ClientFailure catch (error) {
      if (!_disposed) {
        failure = error.code;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        failure = 'apple_unavailable';
        notifyListeners();
      }
    }
  }

  void _purchaseChanged() {
    if (_disposed) return;
    final stage = controller?.stage;
    if (stage == ApplePurchaseStage.applied && _lastStage != stage) {
      unawaited(_refreshEntitlements());
    }
    _lastStage = stage;
    notifyListeners();
  }

  Future<void> _refreshEntitlements() async {
    final generation = session.api.generation;
    await session.refresh();
    if (!_disposed &&
        session.authenticated &&
        session.api.generation == generation) {
      await session.refreshBilling();
    }
  }

  void _accountChanged() {
    if (session.authenticated && session.api.generation == _accountGeneration) {
      return;
    }
    _accountGeneration = session.api.generation;
    _revision++;
    _load = null;
    _releaseController();
    config = null;
    loading = false;
    failure = null;
    if (!_disposed) notifyListeners();
  }

  void _releaseController() {
    controller?.removeListener(_purchaseChanged);
    controller?.setAccount(null);
    controller?.dispose();
    controller = null;
    _lastStage = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    session.removeListener(_accountChanged);
    _releaseController();
    super.dispose();
  }
}
