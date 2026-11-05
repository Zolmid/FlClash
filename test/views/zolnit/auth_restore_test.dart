import 'dart:async';

import 'package:fl_clash/views/zolnit/auth.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';

class _RestoreGate implements ZolnitSessionVault {
  final pending = Completer<String?>();
  String? saved;
  @override
  Future<String?> readAuthorization() => pending.future;
  @override
  Future<void> writeAuthorization(String value) async => saved = value;
  @override
  Future<void> deleteAuthorization() async => saved = null;
}

void main() {
  for (final skin in ZolnitSkin.values) {
    group('manual recovery on ${skin.name}', () {
      final vault = _RestoreGate();
      final harness = ZolnitHarness.register(vault: vault);
      testWidgets('pending automatic restore cannot disable sign-in', (
        tester,
      ) async {
        await tester.runAsync(harness.session.logout);
        final restoring = harness.session.restore();
        addTearDown(() {
          if (!vault.pending.isCompleted) vault.pending.complete(null);
        });
        await tester.pump();
        expect(harness.session.restoring, isTrue);
        var signedIn = 0;
        await harness.mount(
          tester,
          skin,
          child: ZolnitLoginPage(
            session: harness.session,
            onSignedIn: () async {
              signedIn++;
            },
            openWebsite: () {},
          ),
        );
        final email = find.byKey(const ValueKey('zolnit-email'));
        expect(tester.widget<TextFormField>(email).enabled, isTrue);
        await tester.enterText(email, 'fixture@example.invalid');
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('zolnit-password')),
            matching: find.byType(TextFormField),
          ),
          'fixture-password',
        );
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(harness.session.authenticated, isTrue);
        expect(signedIn, 1);
        final generation = harness.session.accountGeneration;
        final saved = vault.saved;
        vault.pending.complete('Bearer old-fixture');
        await tester.pump();
        await tester.runAsync(() => restoring);
        expect(harness.session.authenticated, isTrue);
        expect(harness.session.accountGeneration, generation);
        expect(vault.saved, saved);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
