import 'dart:async';

import 'package:fl_clash/providers/zolnit_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native retirement starts even while credential deletion waits', (
    tester,
  ) async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final gate = Completer<void>();
    final deletionStarted = Completer<void>();
    var retirementStarted = false;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'delete');
      deletionStarted.complete();
      await gate.future;
      return null;
    });
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      messenger.setMockMethodCallHandler(channel, null);
    });
    final vault = SecureZolnitSessionVault(
      beforeDelete: () async {
        retirementStarted = true;
      },
    );
    final deletion = vault.deleteAuthorization();
    await tester.pump();
    expect(deletionStarted.isCompleted, isTrue);
    expect(retirementStarted, isTrue);
    gate.complete();
    await tester.pump();
    await deletion;
  });
}
