import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
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
