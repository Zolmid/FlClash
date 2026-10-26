import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'api.dart';

enum ApplePurchaseStage {
  idle,
  unavailable,
  purchasing,
  pending,
  verifying,
  awaitingBackend,
  applied,
  cancelled,
  restoring,
  restored,
  failed,
}

class ApplePurchaseContext {
  ApplePurchaseContext({
    required this.accountId,
    required this.productId,
    required this.appAccountToken,
    this.entitlementEffect,
    this.giftExpiresAt,
  }) {
    if (accountId.isEmpty ||
        productId.isEmpty ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(appAccountToken)) {
      throw const ClientFailure('invalid_apple_context');
    }
  }

  final String accountId;
  final String productId;
  final String appAccountToken;
  final String? entitlementEffect;
  final DateTime? giftExpiresAt;
}

class ApplePurchaseProof {
  const ApplePurchaseProof({
    required this.productId,
    required this.transactionId,
    required this.verificationData,
    required this.source,
  });

  final String productId;
  final String transactionId;
  final String verificationData;
  final String source;

  @override
  String toString() => 'ApplePurchaseProof([redacted])';
}

class AppleVerification {
  const AppleVerification({
    required this.accountId,
    required this.productId,
    required this.transactionId,
    required this.applied,
  });

  final String accountId;
  final String productId;
  final String transactionId;
  final bool applied;
}

abstract interface class AppleBillingBackend {
  Future<ApplePurchaseContext> prepare(String productId);
  Future<AppleVerification> verify(ApplePurchaseProof proof);
}

abstract interface class AppleStore {
  Stream<List<PurchaseDetails>> get purchases;
  Future<bool> available();
  Future<List<ProductDetails>> products(Set<String> ids);
  Future<bool> buy(ProductDetails product, String accountToken);
  Future<void> restore();
  Future<void> complete(PurchaseDetails purchase);
}

class StoreKitGateway implements AppleStore {
  StoreKitGateway({InAppPurchase? store}) : _provided = store;

  final InAppPurchase? _provided;
  InAppPurchase get _store {
    if (kIsWeb ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      throw const ClientFailure('apple_unavailable');
    }
    return _provided ?? InAppPurchase.instance;
  }

  @override
  Stream<List<PurchaseDetails>> get purchases => _store.purchaseStream;
  @override
  Future<bool> available() => _store.isAvailable();

  @override
  Future<List<ProductDetails>> products(Set<String> ids) async {
    final response = await _store.queryProductDetails(ids);
    if (response.error != null || response.notFoundIDs.isNotEmpty) {
      throw const ClientFailure('apple_products_unavailable');
    }
    return response.productDetails;
  }

  @override
  Future<bool> buy(ProductDetails product, String accountToken) =>
      _store.buyNonConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: product,
          applicationUserName: accountToken,
        ),
      );

  @override
  Future<void> restore() => _store.restorePurchases();
  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

class ApplePurchaseController extends ChangeNotifier {
  ApplePurchaseController({
    required this.store,
    required this.backend,
    required Set<String> productIds,
    required this.enabled,
    this.confirmPurchase,
  }) : productIds = Set.unmodifiable(productIds) {
    if (enabled) {
      _subscription = store.purchases.listen(
        _enqueue,
        onError: (Object _) {
          if (!_disposed) {
            _failure = 'store_error';
            _set(ApplePurchaseStage.failed);
          }
        },
      );
    }
  }

  final AppleStore store;
  final AppleBillingBackend backend;
  final Set<String> productIds;
  final bool enabled;
  final Future<bool> Function(
    ProductDetails product,
    ApplePurchaseContext context,
  )?
  confirmPurchase;
  ApplePurchaseStage _stage = ApplePurchaseStage.idle;
  String? _failure;
  List<ProductDetails> _products = const [];
  ApplePurchaseStage get stage => _stage;
  String? get failure => _failure;
  List<ProductDetails> get products => _products;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _tail = Future.value();
  Future<void>? _buying;
  Future<void>? _restoring;
  final Map<String, PurchaseDetails> _unverified = {};
  final Set<String> _finished = {};
  String? _accountId;
  int _catalogRevision = 0;
  int _generation = 0;
  bool _disposed = false;

  bool _current(int generation) => !_disposed && generation == _generation;

  void _set(ApplePurchaseStage value) {
    _stage = value;
    notifyListeners();
  }

  bool _catalogCurrent(int generation, int catalogRev) {
    return _current(generation) && catalogRev == _catalogRevision;
  }

  void setAccount(String? accountId) {
    if (_disposed) throw const ClientFailure('closed');
    _generation++;
    _accountId = accountId;
    _unverified.clear();
    _finished.clear();
    _buying = null;
    _restoring = null;
    _failure = null;
    _set(ApplePurchaseStage.idle);
  }

  Future<void> loadProducts() async {
    if (_disposed) throw const ClientFailure('closed');
    if (_busy) throw const ClientFailure('purchase_in_progress');
    final generation = _generation;
    final catalogRev = _catalogRevision;
    if (!enabled || productIds.isEmpty) {
      _set(ApplePurchaseStage.unavailable);
      return;
    }
    try {
      if (!await store.available()) {
        if (_catalogCurrent(generation, catalogRev)) {
          _set(ApplePurchaseStage.unavailable);
        }
        return;
      }
      if (!_catalogCurrent(generation, catalogRev)) return;
      final result = await store.products(productIds);
      if (!_catalogCurrent(generation, catalogRev)) return;
      final returnedIds = result.map((product) => product.id).toSet();
      if (returnedIds.length != result.length ||
          !setEquals(returnedIds, productIds)) {
        throw const ClientFailure('apple_products_unavailable');
      }
      _products = List.unmodifiable(result);
      _set(ApplePurchaseStage.idle);
    } catch (_) {
      if (!_catalogCurrent(generation, catalogRev)) return;
      _failure = 'apple_products_unavailable';
      _set(ApplePurchaseStage.failed);
    }
  }

  Future<void> buy(String productId) {
    if (_disposed) return Future.error(const ClientFailure('closed'));
    if (_buying != null) return _buying!;
    final generation = _generation;
    final operation = Future<void>.microtask(() => _buy(productId, generation));
    _buying = operation;
    return operation.whenComplete(() {
      if (_current(generation)) _buying = null;
    });
  }

  Future<void> _buy(String productId, int generation) async {
    if (!_current(generation)) return;
    if (!enabled || _accountId == null) {
      throw const ClientFailure('apple_unavailable');
    }
    if (_busy) {
      throw const ClientFailure('purchase_in_progress');
    }
    final matching = products.where((product) => product.id == productId);
    if (!productIds.contains(productId) || matching.length != 1) {
      throw const ClientFailure('unknown_product');
    }
    _failure = null;
    _catalogRevision++;
    _set(ApplePurchaseStage.purchasing);
    if (!_current(generation)) return;
    try {
      final context = await backend.prepare(productId);
      if (!_current(generation)) return;
      if (context.accountId != _accountId || context.productId != productId) {
        throw const ClientFailure('purchase_identity_mismatch');
      }
      if (confirmPurchase != null) {
        final approved = await confirmPurchase!(matching.single, context);
        if (!_current(generation)) return;
        if (!approved) {
          _set(ApplePurchaseStage.cancelled);
          return;
        }
      }
      final launched = await store.buy(
        matching.single,
        context.appAccountToken,
      );
      if (!_current(generation)) return;
      if (!launched) throw const ClientFailure('store_unavailable');
    } on ClientFailure catch (error) {
      if (!_current(generation)) return;
      _failure = error.code;
      _set(ApplePurchaseStage.failed);
    } catch (_) {
      if (!_current(generation)) return;
      _failure = 'store_error';
      _set(ApplePurchaseStage.failed);
    }
  }

  void _enqueue(List<PurchaseDetails> values) {
    final generation = _generation;
    final accountId = _accountId;
    _tail = _tail.then((_) async {
      if (!_current(generation) || accountId == null) return;
      for (final purchase in values) {
        if (!_current(generation)) return;
        await _handle(purchase, accountId, generation);
      }
    });
  }

  Future<void> _handle(
    PurchaseDetails purchase,
    String accountId,
    int generation,
  ) async {
    if (!productIds.contains(purchase.productID)) return;
    _catalogRevision++;
    if (purchase.status == PurchaseStatus.pending) {
      _set(ApplePurchaseStage.pending);
      return;
    }
    if (purchase.status == PurchaseStatus.canceled) {
      _set(ApplePurchaseStage.cancelled);
      return;
    }
    if (purchase.status == PurchaseStatus.error) {
      _failure = 'store_error';
      _set(ApplePurchaseStage.failed);
      return;
    }
    final id = purchase.purchaseID;
    if (id == null ||
        id.isEmpty ||
        purchase.verificationData.serverVerificationData.isEmpty ||
        purchase.verificationData.source.isEmpty) {
      _failure = 'invalid_purchase';
      _set(ApplePurchaseStage.failed);
      return;
    }
    if (_finished.contains(id)) return;
    _unverified[id] = purchase;
    _set(ApplePurchaseStage.verifying);
    if (!_current(generation)) return;
    try {
      final result = await backend.verify(
        ApplePurchaseProof(
          productId: purchase.productID,
          transactionId: id,
          verificationData: purchase.verificationData.serverVerificationData,
          source: purchase.verificationData.source,
        ),
      );
      if (!_current(generation)) return;
      if (result.accountId != accountId ||
          result.productId != purchase.productID ||
          result.transactionId != id) {
        throw const ClientFailure('purchase_identity_mismatch');
      }
      if (!result.applied) {
        _set(ApplePurchaseStage.awaitingBackend);
        return;
      }
      if (purchase.pendingCompletePurchase) await store.complete(purchase);
      if (!_current(generation)) return;
      _finished.add(id);
      _unverified.remove(id);
      _failure = null;
      _set(ApplePurchaseStage.applied);
    } catch (error) {
      if (!_current(generation)) return;
      _failure = error is ClientFailure
          ? error.code
          : 'verification_unavailable';
      _set(ApplePurchaseStage.awaitingBackend);
    }
  }

  Future<void> retryVerification() {
    _enqueue(List.of(_unverified.values));
    return _tail;
  }

  bool get _busy => {
    ApplePurchaseStage.purchasing,
    ApplePurchaseStage.pending,
    ApplePurchaseStage.verifying,
    ApplePurchaseStage.awaitingBackend,
    ApplePurchaseStage.restoring,
  }.contains(stage);

  Future<void> restore() {
    if (_disposed) return Future.error(const ClientFailure('closed'));
    if (_restoring != null) return _restoring!;
    if (_busy) return Future.error(const ClientFailure('purchase_in_progress'));
    final generation = _generation;
    final operation = Future<void>.microtask(() => _restore(generation));
    _restoring = operation;
    return operation.whenComplete(() {
      if (_current(generation)) _restoring = null;
    });
  }

  Future<void> _restore(int generation) async {
    if (!_current(generation)) return;
    if (!enabled || _accountId == null || productIds.isEmpty) {
      throw const ClientFailure('apple_unavailable');
    }
    _catalogRevision++;
    _set(ApplePurchaseStage.restoring);
    if (!_current(generation)) return;
    try {
      await store.restore();
      await _tail;
      if (_current(generation) && stage == ApplePurchaseStage.restoring) {
        _set(ApplePurchaseStage.restored);
      }
    } catch (_) {
      if (!_current(generation)) return;
      _failure = 'restore_unavailable';
      _set(ApplePurchaseStage.failed);
    }
  }

  Future<void> get settled => _tail;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    _unverified.clear();
    super.dispose();
  }
}
