import 'package:fl_clash/views/zolnit/kit.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(ZolnitSkin skin, Widget child) => MaterialApp(
  home: ZolnitSkinScope(
    skin: skin,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('mobile selection and primary actions each give one haptic', (
    tester,
  ) async {
    final haptics = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      _host(
        ZolnitSkin.ios,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZolnitSegmented<int>(
              options: const [(0, 'One'), (1, 'Two')],
              value: 0,
              onChanged: (_) {},
            ),
            ZolnitButton(label: 'Continue', primary: true, onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Two'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
    ]);
  });

  testWidgets('desktop brand controls do not request haptics', (tester) async {
    final haptics = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      _host(
        ZolnitSkin.macos,
        ZolnitButton(label: 'Continue', primary: true, onPressed: () {}),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(haptics, isEmpty);
  });
}
