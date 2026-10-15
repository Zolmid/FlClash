import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/goroutine_info.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

void main() {
  testWidgets('the counter follows page visibility and app lifecycle', (
    tester,
  ) async {
    var reads = 0;
    Future<int> read() async => 40 + ++reads;
    Widget host(bool active) => TestApp(
      wrapInProviderScope: true,
      child: PageActivityScope(
        isActive: active,
        child: GoroutineInfo(countReader: read),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(seconds: 3));
    expect(reads, 0);
    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(find.text('41'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(reads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(seconds: 3));
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'new Core session discards an old count and disconnect clears it',
    (tester) async {
      final core = _MockCore();
      final oldCount = Completer<int>();
      var reads = 0;
      when(
        core.getGoroutineCount,
      ).thenAnswer((_) => ++reads == 1 ? oldCount.future : Future.value(99));
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: GoroutineInfo()),
        ),
      );
      await tester.pump();
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await tester.pump();
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pump();
      expect(find.text('99'), findsOneWidget);
      oldCount.complete(7);
      await tester.pump();
      expect(find.text('99'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed reads keep the counter usable for the next poll', (
    tester,
  ) async {
    var reads = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        child: GoroutineInfo(
          countReader: () async {
            if (++reads == 1) throw StateError('Core unavailable');
            return 42;
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
