import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/zolnit/native_home.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_native_ui/zolnit_native_ui.dart';

import 'harness.dart';

Future<Object?> _fromPlatform(String method, [Object? arguments]) {
  const codec = StandardMethodCodec();
  final result = Completer<Object?>();
  ui.channelBuffers.push(
    nativeUiChannelName,
    codec.encodeMethodCall(MethodCall(method, arguments)),
    (data) {
      try {
        result.complete(data == null ? null : codec.decodeEnvelope(data));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    },
  );
  return result.future;
}

void main() {
  const enabled = bool.fromEnvironment('ZOLNIT_NATIVE_UI');
  final harness = ZolnitHarness.register();
  const macos = TargetPlatformVariant({TargetPlatform.macOS});
  const channel = MethodChannel(nativeUiChannelName);
  var availabilityChecks = 0;
  var navigations = 0;

  setUp(() {
    availabilityChecks = 0;
    navigations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') {
            availabilityChecks++;
            return false;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget host({int destination = 0}) => ZolnitNativeHome(
    session: harness.session,
    destination: destination,
    preferencesVisible: false,
    onConnection: (_) async => true,
    onNavigate: (_) => navigations++,
    onRefresh: () async {},
    onPreferences: () {},
    onHelp: () async {},
    child: const Text('existing destination'),
  );

  testWidgets(
    'native snapshot keeps unknown data and authoritative status',
    (tester) async {
      harness.panel = (request) => request.url.path.endsWith('/getSubscribe')
          ? zolnitJson({'plan_id': 1, 'u': null, 'd': 0})
          : zolnitPanelFixture(request);
      await harness.relogin();
      harness.container.read(coreStatusProvider.notifier).value =
          CoreStatus.connecting;
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      final snapshot = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      ).toJson();
      expect(snapshot['usage']['usedBytes'], isNull);
      expect(snapshot['usage']['totalBytes'], isNull);
      expect(snapshot['traffic']['uploadBps'], isNull);
      expect(snapshot['traffic']['downloadBps'], isNull);
      expect(snapshot['connectionState'], 'connecting');
      expect(snapshot['labels']['safeMode'], '安全模式');
      expect(find.text('existing destination'), findsNothing);
      expect(find.text('连接页面暂时无法显示，请重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'native command cannot cross logout before the next frame',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      final snapshot = NativeUiSnapshot.decode(
        await _fromPlatform('getSnapshot') as String,
      );
      await harness.session.logout();
      final reply =
          jsonDecode(
                await _fromPlatform(
                      'performCommand',
                      jsonEncode({
                        'schemaVersion': 1,
                        'id': 'preceding-account',
                        'accountGeneration': snapshot.accountGeneration,
                        'action': 'navigate',
                        'payload': {'destination': 'account'},
                      }),
                    )
                    as String,
              )
              as Map;
      expect(reply['errorCode'], 'stale_account');
      expect(navigations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'unavailable native connection page retries explicitly',
    (tester) async {
      await harness.mount(tester, ZolnitSkin.macos, child: host());
      expect(availabilityChecks, 1);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(availabilityChecks, 2);
      expect(find.text('existing destination'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );

  testWidgets(
    'other destinations keep their existing content',
    (tester) async {
      await harness.mount(
        tester,
        ZolnitSkin.macos,
        child: host(destination: 1),
      );
      expect(find.text('existing destination'), findsOneWidget);
      expect(find.text('连接页面暂时无法显示，请重试。'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !enabled,
    variant: macos,
  );
}
