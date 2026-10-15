import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_info.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

const _runtime = CoreMemoryInfo(
  sys: 1000,
  heapObjects: 250,
  heapUnused: 100,
  heapIdle: 100,
  heapReleased: 500,
  stacks: 20,
  metadata: 10,
  gc: 10,
  other: 10,
);

void main() {
  late ProviderContainer container;

  Future<void> pumpDetails(
    WidgetTester tester,
    Future<CoreMemoryInfo?> Function() reader,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(viewSizeProvider.notifier).value = const Size(900, 2000);
    final snapshot = ValueNotifier(
      const MemorySnapshot(
        app: 8192,
        coreTotal: 4096,
        core: CoreMemoryStats(rss: 4096, heapInuse: 1024),
      ),
    );
    addTearDown(snapshot.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: MemoryDetailSheet(
            snapshot: snapshot,
            onRelease: () async => 0,
            runtimeReader: reader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(ListItem))
      .first;

  testWidgets(
    'hiding released heap changes only the Go chart and percentages',
    (tester) async {
      await pumpDetails(tester, () async => _runtime);
      final l10n = currentAppLocalizations;
      final processTotal = find.text(12288.traffic.value);
      expect(processTotal, findsOneWidget);
      expect(find.text(4096.traffic.show), findsOneWidget);
      expect(
        find.descendant(
          of: row(l10n.memoryHeapObjects),
          matching: find.text('25%'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DonutChart>(find.byType(DonutChart))
            .data
            .fold(0.0, (sum, item) => sum + item.value),
        1000,
      );

      await tester.ensureVisible(find.byTooltip(l10n.hide));
      await tester.tap(find.byTooltip(l10n.hide));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row(l10n.memoryHeapObjects),
          matching: find.text('50%'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DonutChart>(find.byType(DonutChart))
            .data
            .fold(0.0, (sum, item) => sum + item.value),
        500,
      );
      expect(processTotal, findsOneWidget);
      expect(find.text(4096.traffic.show), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.show));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row(l10n.memoryHeapObjects),
          matching: find.text('25%'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'runtime read failure retries and zero memory has finite shares',
    (tester) async {
      var reads = 0;
      await pumpDetails(tester, () async {
        if (++reads == 1) throw StateError('temporary failure');
        return const CoreMemoryInfo();
      });
      expect(
        find.text(currentAppLocalizations.memoryReadFailed),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text(currentAppLocalizations.memoryReadFailed), findsNothing);
      expect(
        tester
            .widget<DonutChart>(find.byType(DonutChart))
            .data
            .every((item) => item.value == 0),
        isTrue,
      );
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a previous Core session cannot replace the new runtime details',
    (tester) async {
      final pending = Completer<CoreMemoryInfo?>();
      var reads = 0;
      await pumpDetails(tester, () {
        if (container.read(coreStatusProvider) != CoreStatus.connected) {
          return Future.value();
        }
        return ++reads == 1 ? pending.future : Future.value(_runtime);
      });
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await tester.pump();
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pumpAndSettle();
      final l10n = currentAppLocalizations;
      expect(
        find.descendant(
          of: row(l10n.memoryHeapObjects),
          matching: find.text('25%'),
        ),
        findsOneWidget,
      );

      pending.complete(_runtime.copyWith(heapObjects: 900));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row(l10n.memoryHeapObjects),
          matching: find.text('25%'),
        ),
        findsOneWidget,
      );
      expect(find.text('90%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
