import 'dart:async';

import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  Future<void> openInviteTab(
    WidgetTester tester,
    ZolnitSkin skin, {
    bool dark = false,
  }) async {
    await harness.mount(tester, skin, dark: dark);
    await tester.tap(find.text('账号').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('邀请有礼'));
    await tester.pumpAndSettle();
  }

  for (final skin in ZolnitSkin.values) {
    testWidgets('invite tab shows stats and codes on ${skin.name}', (
      tester,
    ) async {
      await openInviteTab(tester, skin);
      expect(find.text('好体验，值得分享。'), findsOneWidget);
      expect(find.text('TESTINVITE'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
      await harness.capture(tester, 'invite-${skin.name}');
    });

    testWidgets('invite keeps its dark contrast on ${skin.name}', (
      tester,
    ) async {
      await openInviteTab(tester, skin, dark: true);
      expect(find.text('TESTINVITE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.capture(tester, 'invite-${skin.name}-dark');
    });
  }

  testWidgets(
    'a code is created only after a tap and cannot be submitted twice',
    (tester) async {
      final pending = Completer<http.Response>();
      var saves = 0;
      var created = false;
      harness.panel = (request) {
        if (request.url.path.endsWith('/invite/fetch')) {
          return zolnitJson({
            'codes': created
                ? [
                    {'code': 'NEWCODE1'},
                  ]
                : <Map<String, dynamic>>[],
            'stat': null,
          });
        }
        if (request.url.path.endsWith('/invite/save')) {
          saves++;
          return pending.future;
        }
        return zolnitPanelFixture(request);
      };
      await harness.relogin();
      await openInviteTab(tester, ZolnitSkin.macos);
      expect(saves, 0);
      final button = find.text('生成邀请码');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(saves, 1);
      created = true;
      pending.complete(zolnitJson(true));
      await tester.pumpAndSettle();
      expect(find.text('NEWCODE1'), findsOneWidget);
    },
  );

  testWidgets('copy link uses the verified website and reports success', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await openInviteTab(tester, ZolnitSkin.macos);
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(copied, 'https://link.zolmid.com/#/register?code=TESTINVITE');
    expect(find.text('邀请链接已复制'), findsOneWidget);
  });

  testWidgets('failed code creation unlocks the button for a retry', (
    tester,
  ) async {
    var saves = 0;
    harness.panel = (request) {
      if (request.url.path.endsWith('/invite/fetch')) {
        return zolnitJson({
          'codes': saves == 2
              ? [
                  {'code': 'RETRYCODE'},
                ]
              : <Map<String, dynamic>>[],
          'stat': null,
        });
      }
      if (request.url.path.endsWith('/invite/save')) {
        saves++;
        return saves == 1
            ? http.Response('{"message":"Server Error"}', 503)
            : zolnitJson(true);
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await openInviteTab(tester, ZolnitSkin.macos);
    await tester.tap(find.text('生成邀请码'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    await tester.tap(find.text('生成邀请码'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(find.text('RETRYCODE'), findsOneWidget);
  });

  testWidgets('invite tab shows failure on error', (tester) async {
    harness.panel = (request) => request.url.path.endsWith('/invite/fetch')
        ? http.Response('{"message":"Server Error"}', 503)
        : zolnitPanelFixture(request);
    await harness.relogin();
    await harness.mount(tester, ZolnitSkin.macos);
    await tester.tap(find.text('账号').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('邀请有礼'));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法获取'), findsOneWidget);
  });

  testWidgets('null invite stats show em dashes', (tester) async {
    harness.panel = (request) {
      if (request.url.path.endsWith('/invite/fetch')) {
        return zolnitJson({
          'codes': <Map<String, dynamic>>[
            {'code': 'NODASH', 'pv': 0},
          ],
          'stat': null,
        });
      }
      return zolnitPanelFixture(request);
    };
    await harness.relogin();
    await openInviteTab(tester, ZolnitSkin.macos);
    expect(find.text('NODASH'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });
}
