import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_native_ui/zolnit_native_ui.dart';

Map<String, dynamic> snapshot({
  int revision = 1,
  int generation = 1,
  String session = 'signedIn',
  bool safe = false,
}) => {
  'schemaVersion': 1,
  'revision': revision,
  'accountGeneration': generation,
  'locale': 'en',
  'textDirection': 'ltr',
  'safeMode': safe,
  'sessionStatus': session,
  'connectionState': 'disconnected',
  'destination': 'connect',
  'mode': 'rule',
  'selectedServerId': 'sg-1',
  'servers': [
    {'id': 'sg-1', 'name': 'Singapore', 'available': true, 'latencyMs': 9},
    {
      'id': 'sg-2',
      'name': 'Singapore 2',
      'available': false,
      'latencyMs': null,
    },
  ],
  'planName': 'Fixture',
  'planExpiresAt': null,
  'usage': {'usedBytes': 0, 'totalBytes': 1000},
  'traffic': {'uploadBps': 0, 'downloadBps': 0},
  'labels': {for (final key in nativeUiRequiredLabels) key: 'label.$key'},
};

String command({
  String id = 'intent-1',
  int generation = 1,
  String action = 'connect',
  Map<String, dynamic> payload = const {},
}) => jsonEncode({
  'schemaVersion': 1,
  'id': id,
  'accountGeneration': generation,
  'action': action,
  'payload': payload,
});

Future<Object?> fromPlatform(String method, [Object? arguments]) {
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

Future<Map<String, dynamic>> sendCommand(String json) async =>
    jsonDecode(await fromPlatform('performCommand', json) as String)
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(nativeUiChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bridges = <NativeUiBridge>[];
  var calls = 0;

  NativeUiBridge bridge({NativeUiCommandHandler? handler}) {
    final value = NativeUiBridge(
      onCommand:
          handler ??
          (cmd) async {
            calls++;
            return NativeUiReceipt.accepted(cmd.id);
          },
    );
    bridges.add(value);
    return value;
  }

  setUp(() {
    calls = 0;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isAvailable' ? true : null,
    );
  });
  tearDown(() {
    for (final value in bridges) {
      value.dispose();
    }
    bridges.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  Map<String, dynamic> returnRoute({bool enabled = true}) => {
    'title': 'RETURN ROUTE',
    'selectedId': null,
    'enabled': enabled,
    'options': [
      {'id': 'direct', 'label': 'Direct localized'},
      {'id': 'hk_lite', 'label': 'HK Lite localized'},
      {'id': 'hk_optimized', 'label': 'HK Optimized localized'},
    ],
  };

  test(
    'optional return route preserves no selection and hides malformed data',
    () {
      expect(NativeUiSnapshot.fromJson(snapshot()).returnRoute, isNull);
      for (final selected in [null, 'direct', 'hk_lite', 'hk_optimized']) {
        final route = returnRoute()..['selectedId'] = selected;
        final decoded = NativeUiSnapshot.decode(
          NativeUiSnapshot.fromJson(
            snapshot()..['returnRoute'] = route,
          ).encode(),
        );
        expect(decoded.returnRoute!.selectedId, selected);
        expect(decoded.returnRoute!.options['hk_lite'], 'HK Lite localized');
      }
      for (final raw in [
        null,
        false,
        [],
        {},
        returnRoute()..['options'] = [],
        returnRoute()..['enabled'] = 'true',
        returnRoute()..['title'] = 1,
        returnRoute()..['selectedId'] = 'DIRECT',
        returnRoute()..['selectedId'] = 1,
        returnRoute()
          ..['options'] = [
            {'id': 'direct', 'label': 'A'},
            {'id': 'direct', 'label': 'B'},
          ],
        returnRoute()
          ..['options'] = [
            {'id': 'DIRECT', 'label': 'Alias'},
          ],
        returnRoute()
          ..['options'] = [
            {'id': 'direct', 'label': null},
          ],
      ]) {
        final decoded = NativeUiSnapshot.fromJson(
          snapshot()..['returnRoute'] = raw,
        );
        expect(decoded.returnRoute, isNull);
        expect(decoded.toJson()['returnRoute'], isNull);
      }
      final missing = returnRoute()..remove('selectedId');
      expect(
        NativeUiSnapshot.fromJson(
          snapshot()..['returnRoute'] = missing,
        ).returnRoute!.selectedId,
        isNull,
      );
    },
  );

  test(
    'return route snapshot downgrades from all roles to selected lite',
    () async {
      final value = bridge();
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot()..['returnRoute'] = returnRoute()),
      );
      expect(value.snapshot!.returnRoute!.options.keys, [
        'direct',
        'hk_lite',
        'hk_optimized',
      ]);
      final lite = returnRoute()
        ..['selectedId'] = 'hk_lite'
        ..['options'] = [
          {'id': 'hk_lite', 'label': 'HK Lite localized'},
        ];
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(
          snapshot(revision: 2)..['returnRoute'] = lite,
        ),
      );
      final decoded = NativeUiSnapshot.decode(value.snapshot!.encode());
      expect(decoded.returnRoute!.options.keys, ['hk_lite']);
      expect(decoded.returnRoute!.selectedId, 'hk_lite');
      for (final id in ['direct', 'hk_optimized']) {
        expect(
          (await sendCommand(
            command(
              id: id,
              action: 'selectReturnRoute',
              payload: {'optionId': id},
            ),
          ))['errorCode'],
          'invalid_command',
        );
        expect(
          NativeUiSnapshot.fromJson(
            snapshot()
              ..['returnRoute'] = (Map<String, dynamic>.of(lite)
                ..['selectedId'] = id),
          ).returnRoute,
          isNull,
        );
      }
      expect(calls, 0);
    },
  );

  test(
    'return route retries share pending result only while role stays valid',
    () async {
      for (final completed in [false, true]) {
        for (final state in ['removed', 'disabled', 'absent', 'empty']) {
          final pending = Completer<NativeUiReceipt>();
          var executions = 0;
          final value = bridge(
            handler: (_) {
              executions++;
              return pending.future;
            },
          );
          await value.publishSnapshot(
            NativeUiSnapshot.fromJson(
              snapshot()..['returnRoute'] = returnRoute(),
            ),
          );
          final request = command(
            action: 'selectReturnRoute',
            payload: {'optionId': 'direct'},
          );
          final first = sendCommand(request);
          await Future<void>.delayed(Duration.zero);
          final duplicate = sendCommand(request);
          await Future<void>.delayed(Duration.zero);
          expect(executions, 1);
          if (completed) {
            pending.complete(const NativeUiReceipt.accepted('intent-1'));
            expect((await first)['accepted'], true);
            expect(await duplicate, await first);
          }
          final next = snapshot(revision: 2);
          if (state != 'absent') {
            final route = returnRoute(enabled: state != 'disabled');
            if (state == 'removed') {
              route['selectedId'] = 'hk_lite';
              route['options'] = [
                {'id': 'hk_lite', 'label': 'Lite'},
              ];
            } else if (state == 'empty') {
              route['options'] = [];
            }
            next['returnRoute'] = route;
          }
          await value.publishSnapshot(NativeUiSnapshot.fromJson(next));
          expect(
            (await sendCommand(request))['errorCode'],
            state == 'disabled' ? 'unavailable' : 'invalid_command',
          );
          expect(executions, 1);
          if (!completed) {
            pending.complete(const NativeUiReceipt.accepted('intent-1'));
            expect((await first)['accepted'], true);
            expect(await duplicate, await first);
          }
        }
      }
    },
  );

  test(
    'return route follows session safe mode and any pending command',
    () async {
      final value = bridge();
      for (final entry in [
        (1, 'signedOut', false, 'unauthenticated'),
        (2, 'offline', false, 'unavailable'),
        (3, 'signedIn', true, 'safe_mode'),
      ]) {
        await value.publishSnapshot(
          NativeUiSnapshot.fromJson(
            snapshot(revision: entry.$1, session: entry.$2, safe: entry.$3)
              ..['returnRoute'] = returnRoute(),
          ),
        );
        expect(
          (await sendCommand(
            command(
              action: 'selectReturnRoute',
              payload: {'optionId': 'direct'},
            ),
          ))['errorCode'],
          entry.$4,
        );
      }
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(
          snapshot(revision: 4)..['returnRoute'] = returnRoute(),
        ),
      );
      expect(
        (await sendCommand(
          command(
            id: 'accepted',
            action: 'selectReturnRoute',
            payload: {'optionId': 'hk_optimized'},
          ),
        ))['accepted'],
        true,
      );
      expect(value.snapshot!.returnRoute!.selectedId, isNull);
      final pending = Completer<NativeUiReceipt>();
      final busy = bridge(handler: (_) => pending.future);
      await busy.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot()..['returnRoute'] = returnRoute()),
      );
      final refresh = sendCommand(command(id: 'refresh', action: 'refresh'));
      await Future<void>.delayed(Duration.zero);
      expect(
        (await sendCommand(
          command(action: 'selectReturnRoute', payload: {'optionId': 'direct'}),
        ))['errorCode'],
        'unavailable',
      );
      pending.complete(const NativeUiReceipt.accepted('refresh'));
      await refresh;
    },
  );

  test('return route command validates exact payload', () {
    final parsed = NativeUiCommand.decode(
      command(action: 'selectReturnRoute', payload: {'optionId': 'hk_lite'}),
    );
    expect(parsed.payload, {'optionId': 'hk_lite'});
    for (final payload in <Map<String, dynamic>>[
      {},
      {'optionId': 'DIRECT'},
      {'optionId': 'direct', 'alias': 'DIRECT'},
    ]) {
      expect(
        () => NativeUiCommand.decode(
          command(action: 'selectReturnRoute', payload: payload),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'return route gates presence enabled busy generation and option membership',
    () async {
      final pending = Completer<NativeUiReceipt>();
      final value = bridge(
        handler: (cmd) {
          calls++;
          return pending.future;
        },
      );
      Future<Map<String, dynamic>> select(
        String id, {
        String option = 'hk_lite',
        int generation = 1,
      }) => sendCommand(
        command(
          id: id,
          generation: generation,
          action: 'selectReturnRoute',
          payload: {'optionId': option},
        ),
      );
      await value.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      expect((await select('absent'))['errorCode'], 'invalid_command');
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(
          snapshot(revision: 2)..['returnRoute'] = returnRoute(enabled: false),
        ),
      );
      expect((await select('disabled'))['errorCode'], 'unavailable');
      final route = returnRoute()
        ..['options'] = [
          {'id': 'hk_lite', 'label': 'Lite'},
        ];
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(
          snapshot(revision: 3)..['returnRoute'] = route,
        ),
      );
      expect(
        (await select('missing', option: 'direct'))['errorCode'],
        'invalid_command',
      );
      expect(
        (await select('stale', generation: 0))['errorCode'],
        'stale_account',
      );
      final first = select('first');
      await Future<void>.delayed(Duration.zero);
      expect((await select('busy'))['errorCode'], 'unavailable');
      expect(calls, 1);
      expect(value.snapshot!.returnRoute!.selectedId, isNull);
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(
          snapshot(revision: 4, generation: 2)..['returnRoute'] = route,
        ),
      );
      expect((await first)['errorCode'], 'stale_account');
      pending.complete(const NativeUiReceipt.accepted('first'));
      await Future<void>.delayed(Duration.zero);
      expect(value.snapshot!.returnRoute!.selectedId, isNull);
    },
  );

  testWidgets(
    'macOS surface receives the app theme independently of the OS theme',
    (tester) async {
      final value = bridge();
      final views = <AppKitView>[];
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                views.add(
                  ZolnitNativeSurface(
                        bridge: value,
                        platform: TargetPlatform.macOS,
                        brightness: brightness,
                      ).build(context)
                      as AppKitView,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
      expect((views[0].creationParams as Map)['brightness'], 'light');
      expect((views[1].creationParams as Map)['brightness'], 'dark');
      expect(views[0].key, isNot(views[1].key));
      expect(tester.takeException(), isNull);
    },
  );

  test('protocol preserves unknown metrics and measured zero', () {
    final value = snapshot();
    value['usage'] = {'usedBytes': null, 'totalBytes': null};
    value['traffic'] = {'uploadBps': null, 'downloadBps': 0};
    final decoded = NativeUiSnapshot.decode(
      NativeUiSnapshot.fromJson(value).encode(),
    ).toJson();
    expect(decoded['usage']['usedBytes'], isNull);
    expect(decoded['traffic']['uploadBps'], isNull);
    expect(decoded['traffic']['downloadBps'], 0);
    value['traffic']['downloadBps'] = -1;
    expect(() => NativeUiSnapshot.fromJson(value), throwsFormatException);
  });

  test('protocol blocks credential fields and malformed commands', () {
    final value = snapshot()..['authorization'] = 'fixture-secret';
    expect(
      () => NativeUiSnapshot.fromJson(value),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString().contains('fixture-secret'),
          'redacted',
          false,
        ),
      ),
    );
    expect(
      () => NativeUiCommand.decode(command(payload: {'profileUrl': 'private'})),
      throwsFormatException,
    );
    expect(
      () => NativeUiSnapshot.fromJson(snapshot()..['schemaVersion'] = 1.1),
      throwsFormatException,
    );
    final missingLabel = snapshot();
    (missingLabel['labels'] as Map).remove('connect');
    expect(
      () => NativeUiSnapshot.fromJson(missingLabel),
      throwsFormatException,
    );
  });

  test(
    'native reads current snapshot; stale publications cannot replace it',
    () async {
      final value = bridge();
      expect(await value.isAvailable(), isTrue);
      expect(await fromPlatform('getSnapshot'), isNull);
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 2)),
      );
      expect(
        await value.publishSnapshot(NativeUiSnapshot.fromJson(snapshot())),
        isFalse,
      );
      final current =
          jsonDecode(await fromPlatform('getSnapshot') as String) as Map;
      expect(current['revision'], 2);
      expect(current['connectionState'], 'disconnected');
      expect(calls, 0);
    },
  );

  test(
    'generation, session, safe mode and managed servers gate intents',
    () async {
      final value = bridge();
      await value.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      expect(
        (await sendCommand(command(generation: 0)))['errorCode'],
        'stale_account',
      );
      expect(
        (await sendCommand(
          command(action: 'selectServer', payload: {'serverId': 'unknown'}),
        ))['errorCode'],
        'invalid_command',
      );
      expect(
        (await sendCommand(
          command(action: 'selectServer', payload: {'serverId': 'sg-2'}),
        ))['errorCode'],
        'invalid_command',
      );
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 2, session: 'offline')),
      );
      expect((await sendCommand(command()))['errorCode'], 'unavailable');
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 3, session: 'signedOut')),
      );
      expect((await sendCommand(command()))['errorCode'], 'unauthenticated');
      expect(
        (await sendCommand(command(action: 'disconnect')))['accepted'],
        true,
      );
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 4, safe: true)),
      );
      expect(
        (await sendCommand(
          command(action: 'setMode', payload: {'mode': 'global'}),
        ))['errorCode'],
        'safe_mode',
      );
      expect(calls, 1);
    },
  );

  test(
    'duplicate delivery invokes the owner once and never infers connected',
    () async {
      final pending = Completer<NativeUiReceipt>();
      final value = bridge(
        handler: (cmd) {
          calls++;
          return pending.future;
        },
      );
      await value.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      final first = sendCommand(command());
      final repeated = sendCommand(command());
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pending.complete(const NativeUiReceipt.accepted('intent-1'));
      expect((await first)['accepted'], true);
      expect(await repeated, await first);
      expect(value.snapshot!.toJson()['connectionState'], 'disconnected');
    },
  );

  test(
    'account change resolves pending callers without accepting a late reply',
    () async {
      final pending = Completer<NativeUiReceipt>();
      final value = bridge(handler: (_) => pending.future);
      await value.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      final old = sendCommand(command());
      await Future<void>.delayed(Duration.zero);
      await value.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 2, generation: 2)),
      );
      expect((await old)['errorCode'], 'stale_account');
      pending.complete(const NativeUiReceipt.accepted('intent-1'));
      await Future<void>.delayed(Duration.zero);
      expect(value.snapshot!.accountGeneration, 2);
    },
  );

  test(
    'replacing the owner resolves a preceding pending command immediately',
    () async {
      final pending = Completer<NativeUiReceipt>();
      final old = bridge(handler: (_) => pending.future);
      await old.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      final reply = sendCommand(command());
      await Future<void>.delayed(Duration.zero);
      final current = bridge();
      await current.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
      try {
        expect(
          (await reply.timeout(const Duration(seconds: 1)))['errorCode'],
          'stale_account',
        );
      } finally {
        pending.complete(const NativeUiReceipt.accepted('intent-1'));
      }
      expect((await sendCommand(command(id: 'current')))['accepted'], true);
    },
  );

  test('late old controller disposal cannot detach its replacement', () async {
    final old = bridge();
    final current = bridge();
    old.dispose();
    expect(
      await old.publishSnapshot(
        NativeUiSnapshot.fromJson(snapshot(revision: 10)),
      ),
      false,
    );
    await current.publishSnapshot(NativeUiSnapshot.fromJson(snapshot()));
    expect((await sendCommand(command()))['accepted'], true);
  });
}
