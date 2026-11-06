import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'harness.dart';

class _Wire implements ZolnitRealtimeSocket {
  final frames = StreamController<Object?>();
  final sent = <String>[];
  @override
  Stream<Object?> get messages => frames.stream;
  @override
  void send(Object x) {
    sent.add('$x');
    if (x == 'ping' && !frames.isClosed) frames.add('pong');
  }

  void receive(Map<String, dynamic> frame) =>
      frames.add(jsonEncode({'v': 1, ...frame}));
  @override
  Future<void> close() async {
    if (!frames.isClosed) await frames.close();
  }
}

void main() {
  late _Wire wire;
  late DateTime now;
  final h = ZolnitHarness.register(
    clientPlatform: 'android',
    distribution: 'direct',
    overrides: [
      zolnitRealtimeConnectorProvider.overrideWithValue((_) async => wire),
      zolnitBundleClockProvider.overrideWithValue(() => now),
    ],
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.now();
    wire = _Wire();
    h.panel = (req) {
      final p = req.url.path;
      if (p.endsWith('/user/info')) {
        return zolnitJson({'email': 'no-id@example.invalid'});
      }
      if (p.endsWith('/realtime/inbox')) {
        return zolnitJson({'subject': 'b' * 64, 'events': []});
      }
      if (p.endsWith('/realtime/ticket')) {
        return zolnitJson({'subject': 'b' * 64, 'ticket': 'a' * 43});
      }
      return zolnitPanelFixture(req);
    };
    h.container.read(initProvider.notifier).value = true;
  });
  testWidgets(
    'healthy WSS stops the HTTP sweep; losing the origin pulse resumes it without signing out',
    (tester) async {
      await h.mount(tester, ZolnitSkin.android);
      await tester.pump();
      expect(wire.sent.where((s) => s.contains('"hello"')), hasLength(1));
      wire.receive({'op': 'ready'});
      wire.receive({'op': 'pulse'});
      await tester.pumpAndSettle();
      h.requests.clear();
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(seconds: 45));
        await tester.pump(const Duration(seconds: 45));
        wire.receive({'op': 'pulse'});
        await tester.pump();
      }
      expect(h.requests, isEmpty);
      wire.receive({
        'op': 'event',
        'scope': 'account',
        'seq': 1,
        'id': 'c' * 32,
        'type': 'account.usage',
        'data': {'u': 17, 'd': 13, 'transfer_enable': 400},
      });
      await tester.pumpAndSettle();
      expect(wire.sent.any((s) => s.contains('"ack"')), isTrue);
      expect(h.requests, isEmpty);
      final snap = h.session.subscription;
      expect(
        snap?['transfer_enable'],
        isNot(400),
      ); // A display event cannot grant entitlement.
      now = now.add(const Duration(seconds: 151));
      await tester.pump(const Duration(seconds: 151));
      await tester.pumpAndSettle();
      expect(h.requests.any((r) => r.url.path.endsWith('/user/info')), isTrue);
      expect(h.session.authenticated, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an old panel without realtime keeps HTTP and the normal account UI working',
    (tester) async {
      h.panel = zolnitPanelFixture;
      await h.mount(tester, ZolnitSkin.android);
      h.requests.clear();
      now = now.add(const Duration(minutes: 3));
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(h.requests.any((r) => r.url.path.endsWith('/user/info')), isTrue);
      expect(wire.sent, isEmpty);
      expect(h.session.authenticated, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'HTTP and WSS share one popup history; updates target the installed platform and newer build only',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'ZolNit',
        packageName: 'com.zolmid.zolnit',
        version: '1.0.0',
        buildNumber: '200',
        buildSignature: '',
      );
      final note = {
        'id': 'c' * 32,
        'scope': 'global',
        'type': 'notice.popup',
        'data': {'title': 'Fixture popup', 'body': 'One announcement'},
        'created_at': now.millisecondsSinceEpoch ~/ 1000,
        'read': false,
      };
      final previous = h.panel;
      h.panel = (req) {
        if (req.url.path.endsWith('/realtime/inbox'))
          return zolnitJson({
            'subject': 'b' * 64,
            'events': [note],
          });
        if (req.url.path.endsWith('/realtime/read'))
          return zolnitJson({'read': true, 'event_id': note['id']});
        return previous(req);
      };
      await h.mount(tester, ZolnitSkin.android);
      await tester.pumpAndSettle();
      expect(find.text('Fixture popup'), findsOneWidget);
      await tester.tap(find.text('确定').last);
      await tester.pumpAndSettle();
      wire.receive({'op': 'event', ...note, 'seq': 1});
      wire.receive({'op': 'ready'});
      wire.receive({'op': 'pulse'});
      for (final (seq, target, build) in [
        (2, 'ios', 202),
        (3, 'android', 200),
        (4, 'android', 201),
      ]) {
        wire.receive({
          'op': 'event',
          'scope': 'global',
          'seq': seq,
          'id': seq.toString().padLeft(32, '0'),
          'type': 'client.update',
          'data': {
            'version': '1.1.0',
            'platform': target,
            'build': build,
            'body': 'Build $build',
          },
        });
      }
      await tester.pumpAndSettle();
      expect(find.text('Fixture popup'), findsNothing);
      final items = await ZolnitRealtimePreferencesStore().readInbox(
        'https://panel.example:${'b' * 64}',
      );
      expect(items.where((e) => e.title == 'Fixture popup'), hasLength(1));
      expect(items.where((e) => e.body == 'Build 201'), hasLength(1));
      expect(
        items.any((e) => e.body == 'Build 200' || e.body == 'Build 202'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
