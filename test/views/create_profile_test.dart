import 'dart:async';
import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../plugins/code_forge/support.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

void main() {
  late Directory root;
  late ProviderContainer container;
  late _MockCore core;
  late List<String> validations;
  Future<String> Function(String path)? validate;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('flclash-create-profile-');
    AppPath.supportDirectory = () async => root;
    AppPath.temporaryDirectory = () async => Directory('${root.path}/temp');
    AppPath.cacheDirectory = () async => Directory('${root.path}/cache');
    await appPath.homeDirPath;
    await initEditorNative();
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  setUp(() {
    for (final entity in root.listSync()) {
      entity.deleteSync(recursive: true);
    }
    validations = [];
    validate = null;
    core = _MockCore();
    when(() => core.validateConfig(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.single as String;
      validations.add(path);
      return validate == null ? '' : validate!(path);
    });
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    container.listen(currentProfileIdProvider, (_, _) {});
    addTearDown(container.dispose);
    globalState.container = container;
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    bool nestedNavigator = false,
    Size size = const Size(1200, 1000),
    GlobalKey<NavigatorState>? pageNavigator,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container.read(viewSizeProvider.notifier).value = size;
    Widget home() => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showAddProfilePage(context),
          child: const Text('open profiles'),
        ),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: nestedNavigator
              ? Navigator(
                  key: pageNavigator,
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => home()),
                )
              : home(),
        ),
      ),
    );
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
    await settle(tester, 2);
    await tester.tap(find.text('open profiles'));
    await settle(tester, 10);
    await tester.tap(find.text(currentAppLocalizations.newProfile));
    await settle(tester, 6);
  }

  Future<void> nameProfile(
    WidgetTester tester, [
    String name = 'Local YAML',
  ]) async {
    await tester.enterText(find.byType(TextFormField), name);
    await tester.tap(find.text(currentAppLocalizations.submit));
    await settle(tester, 14);
  }

  CodeForgeController document(WidgetTester tester) =>
      tester.widget<CodeForge>(find.byType(CodeForge)).controller;

  Future<void> write(WidgetTester tester, String content) async {
    final controller = document(tester);
    controller.replaceRange(0, controller.text.length, content);
    await settle(tester, 2);
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() complete, {
    required String reason,
  }) async {
    final elapsed = Stopwatch()..start();
    while (!complete()) {
      if (elapsed.elapsed > const Duration(seconds: 10)) {
        fail('Timed out waiting for $reason');
      }
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> save(
    WidgetTester tester, {
    bool waitForCompletion = true,
  }) async {
    await tester.tap(find.widgetWithGlyph(IconButton, AppGlyphs.check));
    await tester.pump();
    if (!waitForCompletion) return;
    await waitFor(
      tester,
      () =>
          find.byType(EditorPage).evaluate().isEmpty ||
          tester
                  .widget<IconButton>(
                    find.widgetWithGlyph(IconButton, AppGlyphs.check),
                  )
                  .onPressed !=
              null,
      reason: 'save completion',
    );
    if (container.read(profilesProvider).isNotEmpty) {
      await waitFor(
        tester,
        () => find.byType(EditorPage).evaluate().isEmpty,
        reason: 'saved editor route to close',
      );
    }
  }

  void expectNoProfileFiles() {
    final profiles = Directory('${root.path}/$profilesDirectoryName');
    expect(profiles.existsSync() ? profiles.listSync() : [], isEmpty);
    expect(container.read(profilesProvider), isEmpty);
  }

  testWidgets(
    'requires a name, trims it, and leaves an empty draft uncommitted',
    (tester) async {
      await pumpHost(tester);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(InputDialog),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.focusNode.hasFocus, isTrue);
      await nameProfile(tester, '   ');
      expect(
        find.text(currentAppLocalizations.profileNameNullValidationDesc),
        findsOneWidget,
      );
      expect(find.byType(EditorPage), findsNothing);

      await nameProfile(tester, '  Local YAML  ');
      final editor = tester.widget<EditorPage>(find.byType(EditorPage));
      expect(editor.title, 'Local YAML');
      expect(editor.content, isEmpty);
      expect(document(tester).text, isEmpty);
      expectNoProfileFiles();
      expect(validations, isEmpty);
    },
  );

  testWidgets(
    'cancelling the name leaves the add page and creates no profile',
    (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text(currentAppLocalizations.cancel));
      await settle(tester, 6);

      expect(find.byType(AddProfileView), findsOneWidget);
      expect(find.byType(EditorPage), findsNothing);
      expectNoProfileFiles();
    },
  );

  testWidgets('an untouched mobile draft replaces the add page and backs out', (
    tester,
  ) async {
    await pumpHost(tester, size: const Size(400, 800));
    await nameProfile(tester);
    expect(find.byType(AddProfileView), findsNothing);
    expect(find.byType(EditorPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester, 12);
    expect(find.byType(EditorPage), findsNothing);
    expect(find.text('open profiles'), findsOneWidget);
    expectNoProfileFiles();
    expect(validations, isEmpty);
  });

  testWidgets(
    'the desktop editor belongs to the profiles navigator after the sheet closes',
    (tester) async {
      final pageNavigator = GlobalKey<NavigatorState>();
      await pumpHost(
        tester,
        nestedNavigator: true,
        pageNavigator: pageNavigator,
      );
      await nameProfile(tester);

      expect(find.byType(AddProfileView), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(EditorPage))),
        same(pageNavigator.currentState),
      );
      expect(globalState.navigatorKey.currentState!.canPop(), isFalse);
      await pageNavigator.currentState!.maybePop();
      await settle(tester, 12);
      expect(find.text('open profiles'), findsOneWidget);
      expectNoProfileFiles();
    },
  );

  testWidgets('saving validates and stores the complete YAML unchanged', (
    tester,
  ) async {
    const content = '# keep this comment\nmixed-port: 7890\nmode: rule\n';
    await pumpHost(tester);
    await nameProfile(tester);
    await write(tester, content);
    await save(tester);

    final profile = container.read(profilesProvider).single;
    expect(profile.type, ProfileType.file);
    expect(profile.label, 'Local YAML');
    expect(profile.url, isEmpty);
    expect(profile.lastUpdateDate, isNotNull);
    expect(container.read(currentProfileIdProvider), profile.id);
    final path = await tester.runAsync(
      () => appPath.getProfilePath('${profile.id}'),
    );
    expect(File(path!).readAsStringSync(), content);
    expect(find.byType(EditorPage), findsNothing);
    expect(validations, hasLength(1));
    expect(File(validations.single).existsSync(), isFalse);
    verifyNever(() => core.convertProxies(any()));
  });

  testWidgets('invalid YAML stays in the editor without a file or profile', (
    tester,
  ) async {
    validate = (_) async => 'Invalid configuration';
    await pumpHost(tester);
    await nameProfile(tester);
    await write(tester, 'not: [valid');
    await save(tester);

    expect(document(tester).text, 'not: [valid');
    expectNoProfileFiles();
    expect(File(validations.single).existsSync(), isFalse);
    verifyNever(() => core.convertProxies(any()));
  });

  testWidgets(
    'validation exceptions keep the draft available for a successful retry',
    (tester) async {
      validate = (_) async => throw StateError('Core disconnected');
      await pumpHost(tester);
      await nameProfile(tester);
      await write(tester, 'mode: rule\n');
      await save(tester);
      expectNoProfileFiles();
      expect(document(tester).text, 'mode: rule\n');
      expect(File(validations.single).existsSync(), isFalse);

      validate = null;
      await save(tester);
      expect(container.read(profilesProvider), hasLength(1));
      expect(validations, hasLength(2));
      expect(find.byType(EditorPage), findsNothing);
    },
  );

  testWidgets(
    'a file write failure leaves the draft uncommitted and retryable',
    (tester) async {
      await pumpHost(tester);
      await nameProfile(tester);
      await write(tester, 'mode: rule\n');
      final profilesPath = await tester.runAsync(() => appPath.profilesPath);
      final blockedDirectory = File(profilesPath!)
        ..writeAsStringSync('blocked');

      await save(tester);
      expect(container.read(profilesProvider), isEmpty);
      expect(document(tester).text, 'mode: rule\n');
      expect(blockedDirectory.readAsStringSync(), 'blocked');
      expect(File(validations.single).existsSync(), isFalse);

      blockedDirectory.deleteSync();
      await save(tester);
      expect(container.read(profilesProvider), hasLength(1));
      expect(find.byType(EditorPage), findsNothing);
    },
  );

  testWidgets(
    'an in-flight save rejects a duplicate callback and back navigation',
    (tester) async {
      final validation = Completer<String>();
      validate = (_) => validation.future;
      await pumpHost(tester);
      await nameProfile(tester);
      await write(tester, 'mode: rule\n');
      await save(tester, waitForCompletion: false);
      await waitFor(
        tester,
        () => validations.length == 1,
        reason: 'blocked validation to start',
      );
      final editor = tester.widget<EditorPage>(find.byType(EditorPage));
      final editorContext = tester.element(find.byType(EditorPage));
      await editor.onSave!(editorContext, editor.title, 'mode: global\n');
      await Navigator.of(editorContext).maybePop();
      await settle(tester, 2);
      expect(find.byType(EditorPage), findsOneWidget);
      expect(
        find.text(currentAppLocalizations.hasCacheChange, findRichText: true),
        findsNothing,
      );
      expect(validations, hasLength(1));
      expect(container.read(profilesProvider), isEmpty);

      validation.complete('');
      await waitFor(
        tester,
        () =>
            container.read(profilesProvider).length == 1 &&
            find.byType(EditorPage).evaluate().isEmpty,
        reason: 'released save to commit and close its route',
      );
      final profile = container.read(profilesProvider).single;
      final path = await tester.runAsync(
        () => appPath.getProfilePath('${profile.id}'),
      );
      expect(File(path!).readAsStringSync(), 'mode: rule\n');
      expect(find.byType(EditorPage), findsNothing);
    },
  );

  testWidgets('discarding a changed draft leaves no profile or file', (
    tester,
  ) async {
    await pumpHost(tester);
    await nameProfile(tester);
    await write(tester, 'mode: rule\n');
    await tester.binding.handlePopRoute();
    await settle(tester, 4);
    expect(
      find.text(currentAppLocalizations.hasCacheChange, findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await settle(tester, 12);

    expect(find.byType(EditorPage), findsNothing);
    expectNoProfileFiles();
    expect(validations, isEmpty);
  });

  testWidgets('save on exit keeps a rejected draft open and can retry', (
    tester,
  ) async {
    validate = (_) async => 'Invalid configuration';
    await pumpHost(tester);
    await nameProfile(tester);
    await write(tester, 'mode: rule\n');
    Future<bool> requestExit() => Future<bool>.sync(() {
      final editor = find.byType(EditorPage);
      final scope = tester.widget<CommonPopScope>(
        find
            .descendant(of: editor, matching: find.byType(CommonPopScope))
            .first,
      );
      return scope.onPop!(tester.element(editor));
    });

    bool? firstDecision;
    unawaited(requestExit().then((value) => firstDecision = value));
    await waitFor(
      tester,
      () => find.text(currentAppLocalizations.confirm).evaluate().isNotEmpty,
      reason: 'first exit confirmation',
    );
    await tester.tap(find.text(currentAppLocalizations.confirm));
    await waitFor(
      tester,
      () =>
          firstDecision != null && find.byType(CommonDialog).evaluate().isEmpty,
      reason: 'rejected exit callback and confirmation route to finish',
    );
    expect(firstDecision, isFalse);
    expect(File(validations.single).existsSync(), isFalse);
    expect(document(tester).text, 'mode: rule\n');
    expectNoProfileFiles();

    validate = null;
    bool? secondDecision;
    unawaited(requestExit().then((value) => secondDecision = value));
    await waitFor(
      tester,
      () => find.text(currentAppLocalizations.confirm).evaluate().isNotEmpty,
      reason: 'retry exit confirmation',
    );
    await tester.tap(find.text(currentAppLocalizations.confirm));
    await waitFor(
      tester,
      () =>
          secondDecision != null &&
          container.read(profilesProvider).length == 1 &&
          find.byType(EditorPage).evaluate().isEmpty,
      reason: 'exit save to commit and close its route',
    );
    expect(secondDecision, isFalse);
    expect(container.read(profilesProvider), hasLength(1));
    expect(find.byType(EditorPage), findsNothing);
  });
}
