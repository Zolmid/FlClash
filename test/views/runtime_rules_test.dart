import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/rules/rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _profile = Profile(id: 42, autoUpdateDuration: Duration(minutes: 20));
const _rule = CoreRule(
  index: 0,
  type: 'Domain',
  payload: 'example.com',
  proxy: 'DIRECT',
  hitCount: 12,
  missCount: 3,
);

void main() {
  late _MockCore core;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      const SetRuleDisabledParams(
        index: 0,
        type: 'Domain',
        payload: '',
        disabled: false,
      ),
    );
  });

  setUp(() => core = _MockCore());

  Future<void> pumpRules(
    WidgetTester tester, {
    List<Rule> addedRules = const [],
  }) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        currentProfileProvider.overrideWithValue(_profile),
        selectedMapProvider.overrideWithValue(const {}),
        addedRulesStreamProvider(
          _profile.id,
        ).overrideWith((_) => Stream.value(addedRules)),
        profileAddedRulesProvider(
          _profile.id,
        ).overrideWith((_) => Stream.value(addedRules)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1000, 1200);
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: RulesView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows runtime rules, statistics and the matching added source', (
    tester,
  ) async {
    when(core.getRules).thenAnswer(
      (_) async => [
        _rule,
        const CoreRule(
          index: 1,
          type: 'RuleSet',
          payload: 'remote-rules',
          proxy: 'REJECT',
          hitCount: 7,
          missCount: 2,
        ),
      ],
    );
    await pumpRules(
      tester,
      addedRules: const [
        Rule(content: 'example.com', ruleTarget: 'DIRECT'),
        Rule(content: 'configured-only.example', ruleTarget: 'REJECT'),
      ],
    );
    final l10n = currentAppLocalizations;

    expect(
      find.text('Domain(example.com)', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('RuleSet(remote-rules)', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('${l10n.ruleHits} 12 · ${l10n.ruleMisses} 3'),
      findsOneWidget,
    );
    expect(
      find.text('${l10n.ruleHits} 7 · ${l10n.ruleMisses} 2'),
      findsOneWidget,
    );
    expect(find.text(l10n.addedRules), findsOneWidget);
    expect(find.textContaining('configured-only.example'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));
    verify(core.getRules).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'toggles through Core and ignores a mutation from the old session',
    (tester) async {
      var rules = [_rule];
      var reads = 0;
      final mutations = <SetRuleDisabledParams>[];
      final oldMutation = Completer<bool>();
      when(core.getRules).thenAnswer((_) async {
        reads++;
        return rules;
      });
      when(() => core.setRuleDisabled(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.single as SetRuleDisabledParams;
        mutations.add(params);
        if (mutations.length == 1) {
          rules = [_rule.copyWith(disabled: true)];
          return true;
        }
        return oldMutation.future;
      });
      await pumpRules(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        mutations.single,
        const SetRuleDisabledParams(
          index: 0,
          type: 'Domain',
          payload: 'example.com',
          disabled: true,
        ),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text(currentAppLocalizations.ruleDisabled), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(mutations.last.disabled, isFalse);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      await tester.pump();
      rules = [_rule.copyWith(payload: 'new-session.example')];
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pumpAndSettle();
      final readsAfterReconnect = reads;

      oldMutation.complete(false);
      await tester.pumpAndSettle();
      expect(reads, readsAfterReconnect);
      expect(
        find.text('Domain(new-session.example)', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Domain(example.com)', findRichText: true),
        findsNothing,
      );
      expect(find.text(currentAppLocalizations.ruleUpdateFailed), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disconnect clears rules and a late refresh cannot restore controls',
    (tester) async {
      final lateRefresh = Completer<List<CoreRule>>();
      var reads = 0;
      when(core.getRules).thenAnswer((_) {
        reads++;
        return reads == 1 ? Future.value([_rule]) : lateRefresh.future;
      });
      await pumpRules(tester);
      expect(find.byType(Switch), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(reads, 2);

      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pumpAndSettle();
      expect(find.text(currentAppLocalizations.disconnected), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(
        find.text('Domain(example.com)', findRichText: true),
        findsNothing,
      );

      lateRefresh.complete([_rule.copyWith(hitCount: 99)]);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(reads, 2);
      expect(find.byType(Switch), findsNothing);
      final l10n = currentAppLocalizations;
      expect(
        find.text('${l10n.ruleHits} 99 · ${l10n.ruleMisses} 3'),
        findsNothing,
      );
      verifyNever(() => core.setRuleDisabled(any()));
      expect(tester.takeException(), isNull);
    },
  );
}
