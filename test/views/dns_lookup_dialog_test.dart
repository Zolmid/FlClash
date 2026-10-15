import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dns_queries.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  Future<void> pumpLookup(
    WidgetTester tester,
    Future<DnsQuery> Function(String domain, String type) onQuery,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(800, 1000)),
        ],
        child: DnsLookupDialog(onQuery: onQuery),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lookup validates input and prevents a duplicate submission', (
    tester,
  ) async {
    final response = Completer<DnsQuery>();
    var calls = 0;
    await pumpLookup(tester, (domain, type) {
      calls++;
      expect(domain, 'example.com');
      expect(type, 'A');
      return response.future;
    });
    final l = currentAppLocalizations;
    await tester.tap(find.text(l.query));
    await tester.pump();
    expect(calls, 0);

    await tester.enterText(find.byType(TextFormField), ' example.com ');
    await tester.tap(find.text(l.query));
    await tester.pump();
    await tester.tap(find.text(l.query));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CommonCircleLoading), findsOneWidget);

    response.complete(
      DnsQuery(
        domain: 'example.com',
        type: 'A',
        answers: const ['203.0.113.1'],
        rcode: 'NOERROR',
        time: DateTime.utc(2026),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('203.0.113.1'), findsOneWidget);
    expect(find.text('NOERROR'), findsOneWidget);
    expect(find.byType(CommonCircleLoading), findsNothing);
  });

  testWidgets('a failed lookup leaves the action usable for a retry', (
    tester,
  ) async {
    var calls = 0;
    await pumpLookup(tester, (_, _) async {
      calls++;
      throw StateError('lookup failed');
    });
    final l = currentAppLocalizations;
    await tester.enterText(find.byType(TextFormField), 'example.com');
    await tester.tap(find.text(l.query));
    await tester.pumpAndSettle();
    expect(find.textContaining('lookup failed'), findsOneWidget);
    expect(find.byType(CommonCircleLoading), findsNothing);

    await tester.tap(find.text(l.query));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
