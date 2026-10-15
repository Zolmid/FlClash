import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.listen(appSettingProvider, (_, _) {});
    container
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            foregroundTickerInterval: 3,
            foregroundTickerIdleWhenUnfocused: true,
            foregroundTickerIdleInterval: 7,
          ),
        );
  });

  tearDown(() => container.dispose());

  Future<void> openIntervalDialog(WidgetTester tester) async {
    const size = Size(1000, 3000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: GeneralView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.uiUpdateInterval));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(TextButton, currentAppLocalizations.submit),
    );
    await tester.pumpAndSettle();
  }

  for (final value in ['', 'invalid', '0', '-1']) {
    testWidgets('disabled idle interval ignores invalid draft "$value"', (
      tester,
    ) async {
      await openIntervalDialog(tester);
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.enterText(find.byType(TextFormField).last, value);
      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          currentAppLocalizations.uiUpdateIdleWhenUnfocused,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);

      await submit(tester);

      final setting = container.read(appSettingProvider);
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(setting.foregroundTickerInterval, 5);
      expect(setting.foregroundTickerIdleWhenUnfocused, isFalse);
      expect(setting.foregroundTickerIdleInterval, 7);
    });

    testWidgets(
      'enabled idle interval rejects "$value" and accepts correction',
      (tester) async {
        await openIntervalDialog(tester);
        await tester.enterText(find.byType(TextFormField).last, value);

        await submit(tester);

        final setting = container.read(appSettingProvider);
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(setting.foregroundTickerInterval, 3);
        expect(setting.foregroundTickerIdleWhenUnfocused, isTrue);
        expect(setting.foregroundTickerIdleInterval, 7);

        await tester.enterText(find.byType(TextFormField).last, '9');
        await submit(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          container.read(appSettingProvider).foregroundTickerIdleInterval,
          9,
        );
      },
    );
  }

  testWidgets('disabling idle interval keeps the latest saved value', (
    tester,
  ) async {
    await openIntervalDialog(tester);
    await tester.enterText(find.byType(TextFormField).last, 'invalid');
    await tester.tap(
      find.widgetWithText(
        SwitchListTile,
        currentAppLocalizations.uiUpdateIdleWhenUnfocused,
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(foregroundTickerIdleInterval: 11));

    await submit(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(appSettingProvider).foregroundTickerIdleInterval, 11);
  });
}
