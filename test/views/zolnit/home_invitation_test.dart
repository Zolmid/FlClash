import 'package:fl_clash/views/zolnit/account.dart';
import 'package:fl_clash/views/zolnit/invite.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  for (final (skin, size) in [
    (ZolnitSkin.android, const Size(320, 640)),
    (ZolnitSkin.macos, const Size(1400, 900)),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('invitation opens account tab: $skin dark=$dark', (
        tester,
      ) async {
        await harness.mount(tester, skin, size: size, dark: dark);
        final card = find.byKey(const ValueKey('home-invitation-card'));
        expect(card, findsOneWidget);
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        final node = tester.getSemantics(card).getSemanticsData();
        expect(node.hasAction(SemanticsAction.tap), isTrue);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.label, contains('邀请'));
        semantics.dispose();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(ZolnitInviteTab), findsOneWidget);
        expect(
          tester.widget<ZolnitAccountPage>(find.byType(ZolnitAccountPage)).tab,
          ZolnitAccountTab.invite,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
