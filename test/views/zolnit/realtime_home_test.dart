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
  Map<String, dynamic>? Function(String method, Object? data)? answer;
  @override
  Stream<Object?> get messages => frames.stream;
  @override
  void send(Object x) {
    sent.add('$x');
    if (x == 'ping' && !frames.isClosed) frames.add('pong');
    final m = x is String && x.startsWith('{') ? jsonDecode(x) : null;
    final reply = m is Map && m['op'] == 'request'
        ? answer?.call(m['method'] as String, m['data'])
        : null;
    if (reply != null) receive({'op': 'response', 'id': m['id'], ...reply});
  }

  void receive(Map<String, dynamic> frame) =>
      frames.add(jsonEncode({'v': 1, ...frame}));
  @override
  Future<void> close() async {
    if (!frames.isClosed) await frames.close();
  }
}

class _Updater extends CommonAction {
  final hints = <String?>[];
  final health = <bool>[];

  @override
  void build() {}

  @override
  Future<bool> notifyAppUpdateHint({String? version}) async {
    hints.add(version);
    return false;
  }

  @override
  void setAppUpdateRealtimeHintsHealthy(bool healthy) => health.add(healthy);
}

void main() {
  late _Wire wire;
  late DateTime now;
  late _Updater updater;
  final h = ZolnitHarness.register(
    clientPlatform: 'android',
    distribution: 'direct',
    overrides: [
      zolnitRealtimeConnectorProvider.overrideWithValue((_) async => wire),
      zolnitBundleClockProvider.overrideWithValue(() => now),
      commonActionProvider.overrideWith(() => updater = _Updater()),
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
        if (req.url.path.endsWith('/realtime/inbox')) {
          return zolnitJson({
            'subject': 'b' * 64,
            'events': [note],
          });
        }
        if (req.url.path.endsWith('/realtime/read')) {
          return zolnitJson({'read': true, 'event_id': note['id']});
        }
        return previous(req);
      };
      await h.mount(tester, ZolnitSkin.android);
      await tester.pumpAndSettle();
      expect(find.text('Fixture popup'), findsOneWidget);
      await tester.tap(find.text('知道了').last);
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
      expect(updater.hints, ['1.1.0']);
      expect(updater.health.first, isTrue);
      for (var i = 1; i < updater.health.length; i++) {
        expect(updater.health[i], isNot(updater.health[i - 1]));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'negotiated reads reconcile a pending order over WSS without an HTTP sweep',
    (tester) async {
      var status = 0;
      final previous = h.panel;
      h.panel = (req) => req.url.path.endsWith('/order/fetch')
          ? zolnitJson([
              {'trade_no': 'pending-1', 'status': status},
            ])
          : previous(req);
      wire.answer = (method, data) => switch (method) {
        'order.status' => {
          'data': {'result': status},
        },
        'notice.list' => {
          'data': {'result': <Object>[]},
        },
        _ => null,
      };
      await h.mount(tester, ZolnitSkin.android);
      await tester.pump();
      wire.receive({
        'op': 'ready',
        'methods': ['order.status', 'inbox.list', 'notice.list'],
      });
      wire.receive({'op': 'pulse'});
      await tester.pumpAndSettle();
      expect(h.session.orders.single['trade_no'], 'pending-1');
      h.requests.clear();
      int reads() => wire.sent.where((s) => s.contains('order.status')).length;
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 15));
        await tester.pump(const Duration(seconds: 15));
        wire.receive({'op': 'pulse'});
        await tester.pumpAndSettle();
      }
      expect(reads(), 3);
      wire.receive({
        'op': 'event',
        'scope': 'global',
        'seq': 1,
        'id': 'd' * 32,
        'type': 'notice.changed',
        'data': {},
      });
      await tester.pumpAndSettle();
      expect(wire.sent.where((s) => s.contains('notice.list')), hasLength(1));
      expect(h.requests, isEmpty);
      status = 3;
      now = now.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(
        h.requests.where((r) => r.url.path.endsWith('/order/fetch')),
        hasLength(1),
      );
      expect(
        h.requests.any((r) => r.url.path.endsWith('/order/check')),
        isFalse,
      );
      expect(h.session.orders.single['status'], 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an old edge checks pending orders by targeted HTTP at a slower cadence',
    (tester) async {
      final previous = h.panel;
      h.panel = (req) => req.url.path.endsWith('/order/fetch')
          ? zolnitJson([
              {'trade_no': 'pending-1', 'status': 0},
            ])
          : previous(req);
      await h.mount(tester, ZolnitSkin.android);
      await tester.pump();
      wire.receive({'op': 'ready'});
      wire.receive({'op': 'pulse'});
      await tester.pumpAndSettle();
      h.requests.clear();
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 15));
        await tester.pump(const Duration(seconds: 15));
        wire.receive({'op': 'pulse'});
        await tester.pumpAndSettle();
      }
      expect(h.requests.map((r) => r.url.path), [
        '/api/v1/user/order/check',
        '/api/v1/user/order/check',
      ]);
      expect(wire.sent.any((s) => s.contains('"request"')), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an active checkout reconciles once on becoming healthy and on account.changed',
    (tester) async {
      await h.mount(tester, ZolnitSkin.android);
      await tester.pump();
      await h.session.checkout.start('pending-1', 1);
      await tester.pumpAndSettle();
      expect(h.session.checkout.stage, CheckoutStage.awaitingPayment);
      final base = h.paymentStatusReads;
      wire.receive({
        'op': 'ready',
        'methods': ['order.status'],
      });
      wire.receive({'op': 'pulse'});
      await tester.pumpAndSettle();
      expect(h.paymentStatusReads, base + 1);
      wire.receive({'op': 'pulse'});
      await tester.pumpAndSettle();
      expect(h.paymentStatusReads, base + 1);
      wire.receive({
        'op': 'event',
        'scope': 'account',
        'seq': 1,
        'id': 'e' * 32,
        'type': 'account.changed',
        'data': {},
      });
      await tester.pumpAndSettle();
      expect(h.paymentStatusReads, base + 2);
      expect(wire.sent.any((s) => s.contains('"ack"')), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
