import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_connection.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';

class _Wire implements ZolnitRealtimeSocket {
  final frames = StreamController<Object?>();
  @override
  Stream<Object?> get messages => frames.stream;
  @override
  void send(Object message) {}
  void receive(String operation) => frames.add(
    jsonEncode({
      'v': 1,
      'op': operation,
      if (operation == 'ready') 'methods': ['order.status'],
    }),
  );
  @override
  Future<void> close() async {
    if (!frames.isClosed) await frames.close();
  }
}

void main() {
  final harness = ZolnitHarness.register(
    clientPlatform: 'ios',
    distribution: 'direct',
  );
  late DateTime now;
  late int syncs;

  Future<void> mount(
    WidgetTester tester, {
    ZolnitRealtimeConnect? connect,
  }) async {
    now = DateTime.utc(2026, 11, 14);
    syncs = 0;
    harness.container.dispose();
    harness.container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(harness.session),
        safeModeProvider.overrideWithValue(true),
        initProvider.overrideWithBuild((_, _) => true),
        zolnitBundleClockProvider.overrideWithValue(() => now),
        if (connect != null)
          zolnitRealtimeConnectorProvider.overrideWithValue(connect),
        zolnitSyncProfileProvider.overrideWithValue(() async {
          syncs++;
          return 1;
        }),
        isStartProvider.overrideWithValue(true),
        zolnitConnectionPhaseProvider.overrideWithValue(
          ZolnitConnectionPhase.connected,
        ),
      ],
    );
    globalState.container = harness.container;
    harness.container.read(coreStatusProvider.notifier).value =
        CoreStatus.connected;
    await harness.mount(tester, ZolnitSkin.ios);
    await tester.pumpAndSettle();
  }

  testWidgets('fresh iOS resume retains the view and reconciles checkout', (
    tester,
  ) async {
    await mount(tester);
    expect(syncs, 1);
    await harness.session.checkout.start('pending-1', 1);
    await tester.pumpAndSettle();
    final paymentReads = harness.paymentStatusReads;
    final before = harness.requests.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(syncs, 1);
    expect(harness.paymentStatusReads, paymentReads + 1);
    expect(
      harness.requests
          .skip(before)
          .where((r) => r.url.path.endsWith('/user/info')),
      isEmpty,
    );
    expect(
      harness.container.read(zolnitConnectionPhaseProvider),
      ZolnitConnectionPhase.connected,
    );
  });

  testWidgets('overdue iOS data refreshes after foreground return', (
    tester,
  ) async {
    await mount(tester);
    expect(syncs, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 3));
    await tester.pump(const Duration(minutes: 3));
    expect(syncs, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(syncs, 2);
    expect(
      harness.container.read(zolnitConnectionPhaseProvider),
      ZolnitConnectionPhase.connected,
    );
  });
  testWidgets('iOS resumes its realtime socket without a full refresh', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final wires = <_Wire>[];
    harness.panel = (request) {
      if (request.url.path.endsWith('/realtime/inbox')) {
        return zolnitJson({'subject': 'b' * 64, 'events': []});
      }
      if (request.url.path.endsWith('/realtime/ticket')) {
        return zolnitJson({'subject': 'b' * 64, 'ticket': 'a' * 43});
      }
      return zolnitPanelFixture(request);
    };
    await mount(
      tester,
      connect: (_) async {
        final wire = _Wire();
        wires.add(wire);
        return wire;
      },
    );
    expect(wires.length, 1);
    wires.first.receive('ready');
    wires.first.receive('pulse');
    await tester.pumpAndSettle();
    expect(harness.session.api.liveReads?.supports('order.status'), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(harness.session.api.liveReads?.supports('order.status'), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(wires.length, 2);
    wires.last.receive('ready');
    wires.last.receive('pulse');
    await tester.pumpAndSettle();
    expect(harness.session.api.liveReads?.supports('order.status'), isTrue);
    expect(syncs, 1);
  });
}
