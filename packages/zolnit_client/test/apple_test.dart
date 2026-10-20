import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:zolnit_client/zolnit_client.dart';

class Store implements AppleStore {
  final events = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  Future<void> close() => events.close();
  int buys = 0;
  int finishes = 0;
  int queries = 0;
  int restores = 0;
  String? token;
  bool isAvailable = true;
  final product = ProductDetails(
    id: 'monthly',
    title: 'Monthly',
    description: 'Monthly',
    price: 'US\$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );

  @override
  Stream<List<PurchaseDetails>> get purchases => events.stream;
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<List<ProductDetails>> products(Set<String> ids) async {
    queries++;
    return [product];
  }

  @override
  Future<bool> buy(ProductDetails product, String accountToken) async {
    buys++;
    token = accountToken;
    return true;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    finishes++;
  }

  @override
  Future<void> restore() async {
    restores++;
  }
}

class Backend implements AppleBillingBackend {
  int verifications = 0;
  bool applied = true;
  bool fail = false;
  String account = 'accountA';
  Completer<ApplePurchaseContext>? preparing;
  Completer<AppleVerification>? verifying;

  @override
  Future<ApplePurchaseContext> prepare(String productId) async =>
      preparing != null
      ? preparing!.future
      : ApplePurchaseContext(
          accountId: account,
          productId: productId,
          appAccountToken: '11111111-2222-4333-8444-555555555555',
        );

  @override
  Future<AppleVerification> verify(ApplePurchaseProof proof) async {
    verifications++;
    expect(proof.verificationData, 'signed-transaction');
    expect(proof.toString(), isNot(contains('signed-transaction')));
    if (fail) throw const ClientFailure('network');
    return verifying != null
        ? verifying!.future
        : AppleVerification(
            accountId: account,
            productId: proof.productId,
            transactionId: proof.transactionId,
            applied: applied,
          );
  }
}

PurchaseDetails purchase({
  PurchaseStatus status = PurchaseStatus.purchased,
  String id = 'transaction1',
}) => PurchaseDetails(
  purchaseID: id,
  productID: 'monthly',
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: 'signed-transaction',
    source: 'app_store',
  ),
  transactionDate: '1',
  status: status,
)..pendingCompletePurchase = true;

void main() {
  late Store store;
  late Backend backend;
  late ApplePurchaseController controller;

  setUp(() {
    store = Store();
    backend = Backend();
    controller = ApplePurchaseController(
      store: store,
      backend: backend,
      productIds: {'monthly'},
      enabled: true,
    )..setAccount('accountA');
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  Future<void> send(PurchaseDetails value) async {
    store.events.add([value]);
    await controller.settled;
  }

  test(
    'uses StoreKit product prices and binds purchases to a UUID account token',
    () async {
      await controller.loadProducts();
      expect(controller.products.single.price, 'US\$4.99');
      await Future.wait([controller.buy('monthly'), controller.buy('monthly')]);
      expect(store.buys, 1);
      expect(store.token, '11111111-2222-4333-8444-555555555555');
      expect(store.finishes, 0);
      expect(controller.stage, ApplePurchaseStage.purchasing);
    },
  );

  test('does not buy after account changes during preparation', () async {
    await controller.loadProducts();
    backend.preparing = Completer();
    final buy = controller.buy('monthly');
    await Future<void>.delayed(Duration.zero);
    controller.setAccount('accountB');
    backend.preparing!.complete(
      ApplePurchaseContext(
        accountId: 'accountA',
        productId: 'monthly',
        appAccountToken: '11111111-2222-4333-8444-555555555555',
      ),
    );
    await buy;
    expect(store.buys, 0);
    expect(controller.stage, ApplePurchaseStage.idle);
  });

  test(
    'finishes only after backend acknowledges matching account and transaction',
    () async {
      backend.applied = false;
      await send(purchase());
      expect(controller.stage, ApplePurchaseStage.awaitingBackend);
      expect(store.finishes, 0);
      backend.applied = true;
      await controller.retryVerification();
      expect(store.finishes, 1);
      expect(controller.stage, ApplePurchaseStage.applied);
    },
  );

  test(
    'duplicates and restores do not repeat an already acknowledged transaction',
    () async {
      await send(purchase());
      await send(purchase(status: PurchaseStatus.restored));
      expect(backend.verifications, 1);
      expect(store.finishes, 1);
    },
  );

  test(
    'verification outage leaves the transaction unfinished and retryable',
    () async {
      backend.fail = true;
      await send(purchase());
      expect(store.finishes, 0);
      expect(controller.failure, 'network');
      backend.fail = false;
      await controller.retryVerification();
      expect(store.finishes, 1);
      expect(store.buys, 0);
    },
  );

  test(
    'a transaction bound to another account is not finished or delivered',
    () async {
      backend.account = 'accountB';
      await send(purchase());
      expect(store.finishes, 0);
      expect(controller.stage, ApplePurchaseStage.awaitingBackend);
      expect(controller.failure, 'purchase_identity_mismatch');
    },
  );

  test('logout during verification ignores a late acknowledgement', () async {
    backend.verifying = Completer();
    store.events.add([purchase()]);
    await Future<void>.delayed(Duration.zero);
    controller.setAccount('accountB');
    backend.verifying!.complete(
      const AppleVerification(
        accountId: 'accountA',
        productId: 'monthly',
        transactionId: 'transaction1',
        applied: true,
      ),
    );
    await controller.settled;
    expect(store.finishes, 0);
    expect(controller.stage, ApplePurchaseStage.idle);
  });

  test(
    'pending and cancellation never trigger validation or delivery',
    () async {
      await send(purchase(status: PurchaseStatus.pending));
      expect(controller.stage, ApplePurchaseStage.pending);
      await send(purchase(status: PurchaseStatus.canceled));
      expect(controller.stage, ApplePurchaseStage.cancelled);
      expect(backend.verifications, 0);
      expect(store.finishes, 0);
    },
  );

  test(
    'restored purchases use the same authoritative verification path',
    () async {
      await controller.restore();
      await send(purchase(status: PurchaseStatus.restored));
      expect(store.restores, 1);
      expect(store.finishes, 1);
      expect(controller.stage, ApplePurchaseStage.applied);
    },
  );

  test(
    'unconfigured Apple products do not query or launch the store',
    () async {
      final unconfigured = ApplePurchaseController(
        store: store,
        backend: backend,
        productIds: const {},
        enabled: false,
      );
      await unconfigured.loadProducts();
      expect(unconfigured.stage, ApplePurchaseStage.unavailable);
      expect(store.queries, 0);
      expect(store.buys, 0);
      unconfigured.dispose();
    },
  );

  test('unknown product does not create a native payment', () async {
    await controller.loadProducts();
    await expectLater(controller.buy('other'), throwsA(isA<ClientFailure>()));
    expect(store.buys, 0);
  });

  test(
    'catalog refresh and restore cannot unlock an active purchase',
    () async {
      await controller.loadProducts();
      await controller.buy('monthly');
      await expectLater(
        controller.loadProducts(),
        throwsA(isA<ClientFailure>()),
      );
      await expectLater(controller.restore(), throwsA(isA<ClientFailure>()));
      await expectLater(
        controller.buy('monthly'),
        throwsA(isA<ClientFailure>()),
      );
      expect(store.buys, 1);
      expect(store.restores, 0);
    },
  );

  test('invalidating a scheduled purchase prevents native work', () async {
    await controller.loadProducts();
    final buy = controller.buy('monthly');
    controller.setAccount(null);
    await buy;
    expect(store.buys, 0);
    expect(controller.stage, ApplePurchaseStage.idle);
  });
}
