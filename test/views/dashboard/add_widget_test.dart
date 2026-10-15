import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/widget_registry.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/glyph_finders.dart';
import '../../helpers/test_app.dart';

void main() {
  final addBadges = find.widgetWithGlyph(
    CornerBadgeButton,
    AppGlyphs.addCircle,
  );

  testWidgets('a widget added from the sheet flies into the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final shown = DashboardWidget.values
        .where(
          (item) =>
              item != DashboardWidget.outboundMode &&
              item.platforms.contains(SupportPlatform.currentPlatform),
        )
        .toList();
    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          DashboardState(dashboardWidgets: shown),
        ),
      ],
    );
    addTearDown(container.dispose);
    final appSettingSubscription = container.listen(
      appSettingProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(appSettingSubscription.close);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: DashboardView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-icon')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byGlyph(AppGlyphs.addCircle));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(addBadges.last);
    await tester.pump();
    await tester.pump();

    final grid = tester.state<SuperGridState>(find.byType(SuperGrid));
    expect(grid.items.last, DashboardWidget.outboundMode.widget);
    expect(container.read(appSettingProvider).dashboardWidgets, [
      ...shown,
      DashboardWidget.outboundMode,
    ]);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(addBadges, findsNothing);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  Future<GridItem> openWithTwoLeft(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final available = DashboardWidget.values
        .where(
          (item) => item.platforms.contains(SupportPlatform.currentPlatform),
        )
        .toList();
    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          DashboardState(
            dashboardWidgets: available.sublist(0, available.length - 2),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final appSettingSubscription = container.listen(
      appSettingProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(appSettingSubscription.close);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = size;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: DashboardView()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('edit-icon')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byGlyph(AppGlyphs.addCircle));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return available[available.length - 2].widget;
  }

  Future<void> pumpFor(WidgetTester tester, int ms) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('adding a widget closes the sheet', (tester) async {
    final added = await openWithTwoLeft(tester, const Size(400, 900));
    expect(find.byType(SheetDragHandle), findsOneWidget);

    await tester.tap(addBadges.first);
    await pumpFor(tester, 500);

    expect(find.byType(SheetDragHandle), findsNothing);
    final grid = tester.state<SuperGridState>(find.byType(SuperGrid));
    expect(grid.items.last, added);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('adding a widget closes the side sheet', (tester) async {
    final added = await openWithTwoLeft(tester, const Size(1200, 900));
    expect(find.byType(SideSheet), findsOneWidget);

    await tester.tap(addBadges.first);
    await pumpFor(tester, 500);

    expect(find.byType(SideSheet), findsNothing);
    final grid = tester.state<SuperGridState>(find.byType(SuperGrid));
    expect(grid.items.last, added);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  for (final size in [const Size(400, 900), const Size(1200, 900)]) {
    testWidgets('focused add card closes the sheet at $size', (tester) async {
      final added = await openWithTwoLeft(tester, size);
      final badge = tester.element(addBadges.first);
      final container = badge.findAncestorWidgetOfExactType<Stack>()!;
      final card = find
          .descendant(
            of: find.byWidget(container),
            matching: find.byType(CommonCard),
          )
          .first;
      final cardElement = tester.element(card);
      final button = find
          .descendant(
            of: card,
            matching: find.byWidgetPredicate(
              (widget) => widget is ButtonStyleButton,
            ),
          )
          .first;
      var focused = false;
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focusContext = FocusManager.instance.primaryFocus?.context;
        focused = false;
        focusContext?.visitAncestorElements((element) {
          if (identical(element, cardElement)) focused = true;
          return !focused;
        });
        if (focused) break;
      }
      expect(focused, isTrue);
      expect(
        FocusManager.instance.primaryFocus!.descendants.where(
          (node) => node.canRequestFocus,
        ),
        isEmpty,
      );
      final activate = tester.widget<ButtonStyleButton>(button).onPressed!;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      activate();
      await pumpFor(tester, 1500);
      expect(find.byType(SheetDragHandle), findsNothing);
      expect(find.byType(SideSheet), findsNothing);
      final grid = tester.state<SuperGridState>(find.byType(SuperGrid));
      expect(grid.items.where((item) => item.key == added.key), hasLength(1));
      expect(grid.items.last, added);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
