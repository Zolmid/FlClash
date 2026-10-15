import 'dart:async';

import 'package:fl_clash/common/navigator.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _desktop = Size(1200, 800);
const _mobile = Size(500, 800);

Finder _editor(PageLabel label) => find.byKey(ValueKey('${label.name}:draft'));

EditableText _editable(WidgetTester tester, PageLabel label) =>
    tester.widget<EditableText>(
      find.descendant(of: _editor(label), matching: find.byType(EditableText)),
    );

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  Size size, {
  Future<bool> Function()? onDashboardBack,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      navigationItemsStateProvider.overrideWithValue(
        NavigationItemsState(
          value: [
            NavigationItem(
              glyph: AppGlyphs.dashboard,
              label: PageLabel.dashboard,
              builder: (_) => _EditorLauncher(
                key: const GlobalObjectKey(PageLabel.dashboard),
                label: PageLabel.dashboard,
                onBack: onDashboardBack,
              ),
            ),
            NavigationItem(
              glyph: AppGlyphs.tools,
              label: PageLabel.tools,
              builder: (_) => const _EditorLauncher(
                key: GlobalObjectKey(PageLabel.tools),
                label: PageLabel.tools,
              ),
            ),
          ],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).value = size;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(includeNavigatorKey: false, child: HomePage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _resize(
  WidgetTester tester,
  ProviderContainer container,
  Size size,
) async {
  tester.view.physicalSize = size;
  container.read(viewSizeProvider.notifier).value = size;
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, PageLabel label, String draft) async {
  await tester.tap(find.text('Open ${label.name}'));
  await tester.pumpAndSettle();
  await tester.enterText(_editor(label), draft);
}

Future<void> _selectDesktopTab(WidgetTester tester, Glyph glyph) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationSidebar),
      matching: find.byGlyph(glyph),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'desktop routes keep draft, navigator and focus across resizing',
    (tester) async {
      final container = await _pumpHome(tester, _desktop);
      await _open(tester, PageLabel.dashboard, 'unsaved desktop draft');
      final editable = _editable(tester, PageLabel.dashboard);
      final navigator = Navigator.of(
        tester.element(_editor(PageLabel.dashboard)),
      );

      await _resize(tester, container, _mobile);

      expect(
        _editable(tester, PageLabel.dashboard).controller,
        editable.controller,
      );
      expect(editable.controller.text, 'unsaved desktop draft');
      expect(editable.focusNode.hasFocus, isTrue);
      expect(
        Navigator.of(tester.element(_editor(PageLabel.dashboard))),
        navigator,
      );
      expect(find.byType(NavigationSidebar), findsNothing);
      expect(find.byType(FloatingNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await _resize(tester, container, _desktop);

      expect(
        _editable(tester, PageLabel.dashboard).controller,
        editable.controller,
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(find.byType(NavigationSidebar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_editor(PageLabel.dashboard), findsNothing);
      expect(find.text('Open dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile routes and two independent tab stacks survive resizing', (
    tester,
  ) async {
    final container = await _pumpHome(tester, _mobile);
    expect(find.byType(FloatingNavigationBar), findsOneWidget);
    await _open(tester, PageLabel.dashboard, 'dashboard draft');
    final dashboard = _editable(tester, PageLabel.dashboard).controller;
    await _resize(tester, container, _desktop);
    await _selectDesktopTab(tester, AppGlyphs.tools);
    await _open(tester, PageLabel.tools, 'tools draft');
    final tools = _editable(tester, PageLabel.tools).controller;
    await _selectDesktopTab(tester, AppGlyphs.dashboard);
    expect(_editable(tester, PageLabel.dashboard).controller, dashboard);
    expect(dashboard.text, 'dashboard draft');

    await _resize(tester, container, _mobile);
    await _resize(tester, container, _desktop);
    await _selectDesktopTab(tester, AppGlyphs.tools);

    expect(_editable(tester, PageLabel.tools).controller, tools);
    expect(tools.text, 'tools draft');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_editor(PageLabel.tools), findsNothing);
    expect(find.text('Open tools'), findsOneWidget);
    await _selectDesktopTab(tester, AppGlyphs.dashboard);
    expect(_editable(tester, PageLabel.dashboard).controller, dashboard);
    expect(dashboard.text, 'dashboard draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back preserves async unsaved guards across resizing', (
    tester,
  ) async {
    var decision = Completer<bool>();
    var attempts = 0;
    final container = await _pumpHome(
      tester,
      _desktop,
      onDashboardBack: () {
        attempts++;
        return decision.future;
      },
    );
    await _open(tester, PageLabel.dashboard, 'guarded draft');
    final controller = _editable(tester, PageLabel.dashboard).controller;
    await _resize(tester, container, _mobile);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(attempts, 1);
    expect(_editor(PageLabel.dashboard), findsOneWidget);

    decision.complete(false);
    await tester.pumpAndSettle();
    expect(_editable(tester, PageLabel.dashboard).controller, controller);
    expect(controller.text, 'guarded draft');

    decision = Completer<bool>();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(attempts, 2);
    await _resize(tester, container, _desktop);
    expect(_editable(tester, PageLabel.dashboard).controller, controller);
    decision.complete(true);
    await tester.pumpAndSettle();
    expect(_editor(PageLabel.dashboard), findsNothing);
    expect(find.text('Open dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher({super.key, required this.label, this.onBack});

  final PageLabel label;
  final Future<bool> Function()? onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () {
          BaseNavigator.push<void>(
            context,
            CommonPopScope(
              onPop: onBack == null ? null : (_) => onBack!(),
              child: CommonScaffold(
                title: '${label.name} editor',
                body: TextField(key: ValueKey('${label.name}:draft')),
              ),
            ),
          );
        },
        child: Text('Open ${label.name}'),
      ),
    );
  }
}
