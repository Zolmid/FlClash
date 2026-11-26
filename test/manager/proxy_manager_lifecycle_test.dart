import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/proxy_manager.dart';
import 'package:fl_clash/manager/core_manager.dart';
import 'package:fl_clash/models/models.dart' show CoreEvent;
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';
import 'package:mocktail/mocktail.dart';

class FakeCore extends Mock implements CoreHandlerInterface {}

class FakeProxy implements Proxy {
  @override
  List<String> get restoreFailures => const [];
  final calls = <String>[];
  @override
  Future<bool> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    calls.add('start');
    return true;
  }

  @override
  Future<bool> stopProxy() async {
    calls.add('stop');
    return true;
  }
}

void main() {
  testWidgets(
    'Core disconnect releases proxy and readiness is required to retake it',
    (tester) async {
      final core = FakeCore();
      when(() => core.stopLog()).thenAnswer((_) {});
      when(() => core.startLog()).thenAnswer((_) {});
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(container.dispose);
      container.read(runTimeProvider.notifier).value = 1;
      container
          .read(networkSettingProvider.notifier)
          .update((v) => v.copyWith(systemProxy: true));
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(desktopListenersReadyProvider.notifier).setReady(true);
      final fake = FakeProxy();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProxyManager(
            queue: SystemProxyQueue(fake),
            child: const CoreManager(child: SizedBox()),
          ),
        ),
      );
      await tester.pump();
      expect(fake.calls, ['start']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.crash, data: 'boom'),
      );
      await tester.pump();
      await tester.pump();
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);
      await tester.pump(const Duration(milliseconds: 20));
      expect(fake.calls, ['start', 'stop']);
      container.read(desktopListenersReadyProvider.notifier).setReady(false);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pump();
      expect(fake.calls, ['start', 'stop']);
      container.read(desktopListenersReadyProvider.notifier).setReady(true);
      await tester.pump();
      expect(container.read(desktopListenersReadyProvider), isTrue);
      expect(container.read(proxyStateProvider).isStart, isTrue);
      await tester.pump(const Duration(milliseconds: 20));
      expect(fake.calls, ['start', 'stop', 'start']);
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );
}
