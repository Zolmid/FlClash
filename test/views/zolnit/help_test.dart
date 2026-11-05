import 'package:fl_clash/views/zolnit/help.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  final harness = ZolnitHarness.register();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        if (finder.evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(finder, findsOneWidget);
    await tester.pumpAndSettle();
  }

  testWidgets('help and support requests stay inside the app', (tester) async {
    var submitted = false;
    harness.panel = (request) {
      if (request.url.path.endsWith('/knowledge/fetch')) {
        return zolnitJson({
          'FAQ': [
            {
              'id': 1,
              'title': '连接帮助',
              'body': '<p>在连接页选择线路。</p><script>DO_NOT_RENDER_SCRIPT</script>',
            },
          ],
        });
      }
      if (request.url.path.endsWith('/ticket/fetch')) {
        return zolnitJson(
          submitted
              ? [
                  {'id': 5, 'subject': '请帮我检查线路', 'status': 0, 'level': 0},
                ]
              : [],
        );
      }
      if (request.url.path.endsWith('/ticket/save')) {
        submitted = true;
        return zolnitJson(true);
      }
      return zolnitPanelFixture(request);
    };
    await harness.mount(
      tester,
      ZolnitSkin.android,
      child: ZolnitHelpPage(session: harness.session),
      settle: false,
    );
    await waitFor(tester, find.text('连接帮助'));
    await tester.tap(find.text('连接帮助'));
    await tester.pumpAndSettle();
    expect(find.text('在连接页选择线路。'), findsOneWidget);
    expect(find.textContaining('DO_NOT_RENDER_SCRIPT'), findsNothing);
    await tester.tap(find.text('新建工单'));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    await tester.enterText(find.byType(TextField), '请帮我检查线路');
    await tester.tap(find.byTooltip('发送'));
    await waitFor(tester, find.widgetWithText(ListTile, '请帮我检查线路'));
    expect(submitted, isTrue);
    expect(
      harness.requests.where(
        (request) => request.url.path.endsWith('/ticket/save'),
      ),
      hasLength(1),
    );
    expect(find.text('请帮我检查线路'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
