import 'dart:async';

import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_status.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:fl_clash/views/zolnit/update.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

const _asset = ReleaseAsset(
  name: 'ZolNit.apk',
  url: 'https://link.zolmid.com/client/downloads/v1.3.0/ZolNit.apk',
  size: 1,
  sha256: '0000000000000000000000000000000000000000000000000000000000000000',
);

AppUpdateStatus _status(
  AppUpdatePhase phase, {
  String tag = 'v1.3.0',
  UpdatePackage? package,
}) => AppUpdateStatus(
  phase: phase,
  release: ReleaseManifest(tag: tag, notes: ''),
  plan: package == null
      ? null
      : AppUpdatePlan(target: UpdateTarget(package, 'arm64'), asset: _asset),
);

class _Actions extends CommonAction {
  int applies = 0;
  final pending = Completer<void>();

  @override
  void build() {}

  @override
  Future<void> applyStagedAppUpdate() {
    applies++;
    return pending.future;
  }
}

void main() {
  ZolnitUpdateKind? kind(AppUpdateStatus status) =>
      zolnitUpdateNoticeOf(status, currentVersion: '1.2.0')?.kind;

  test('ordinary launches and the running version say nothing', () {
    for (final phase in [
      AppUpdatePhase.idle,
      AppUpdatePhase.checking,
      AppUpdatePhase.staging,
    ]) {
      expect(kind(_status(phase, package: UpdatePackage.androidApk)), isNull);
    }
    expect(kind(const AppUpdateStatus()), isNull);
    expect(kind(_status(AppUpdatePhase.announcement, tag: 'v1.2.0')), isNull);
    expect(kind(_status(AppUpdatePhase.announcement, tag: 'v1.1.0')), isNull);
    expect(kind(const AppUpdateStatus(phase: AppUpdatePhase.failed)), isNull);
    expect(kind(_status(AppUpdatePhase.failed, tag: 'v1.2.0')), isNull);
    expect(
      zolnitUpdateNoticeOf(
        _status(AppUpdatePhase.announcement),
        currentVersion: null,
      ),
      isNull,
    );
  });

  test('each update state names what the user can do', () {
    expect(
      kind(_status(AppUpdatePhase.staged, package: UpdatePackage.macosDmg)),
      ZolnitUpdateKind.readyOnRestart,
    );
    expect(
      kind(_status(AppUpdatePhase.staged, package: UpdatePackage.androidApk)),
      ZolnitUpdateKind.readyToInstall,
    );
    expect(
      kind(_status(AppUpdatePhase.applying, package: UpdatePackage.androidApk)),
      ZolnitUpdateKind.installing,
    );
    expect(
      kind(_status(AppUpdatePhase.applying, package: UpdatePackage.macosDmg)),
      isNull,
    );
    expect(
      kind(_status(AppUpdatePhase.announcement)),
      ZolnitUpdateKind.available,
    );
    expect(
      kind(_status(AppUpdatePhase.failed, package: UpdatePackage.androidApk)),
      ZolnitUpdateKind.manual,
    );
    expect(
      zolnitUpdateNoticeOf(
        _status(AppUpdatePhase.failed),
        currentVersion: '1.2.0',
      )?.version,
      '1.3.0',
    );
  });

  group('banner', () {
    late ProviderContainer container;
    late _Actions actions;

    setUp(() {
      actions = _Actions();
      container = ProviderContainer(
        overrides: [commonActionProvider.overrideWith(() => actions)],
      );
    });
    tearDown(() => container.dispose());

    Future<void> mount(WidgetTester tester, {bool still = false}) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            includeNavigatorKey: false,
            locale: const Locale('zh', 'CN'),
            theme: ThemeData().withAppShapes.withAppSurfaces,
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: still),
              child: const ZolnitSkinScope(
                skin: ZolnitSkin.android,
                child: Material(
                  child: ZolnitUpdateBanner(currentVersion: '1.2.0'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    void set(AppUpdateStatus status) =>
        container.read(appUpdateStatusProvider.notifier).set(status);

    final banner = find.byKey(const ValueKey('zolnit-update-banner'));

    testWidgets('stays away for an ordinary launch', (tester) async {
      await mount(tester);
      set(_status(AppUpdatePhase.checking));
      await tester.pumpAndSettle();
      set(_status(AppUpdatePhase.announcement, tag: 'v1.2.0'));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a restart update says when it takes effect', (tester) async {
      await mount(tester);
      set(_status(AppUpdatePhase.staged, package: UpdatePackage.macosDmg));
      await tester.pumpAndSettle();
      expect(find.text('更新已准备好，重启 ZolNit 后生效'), findsOneWidget);
      expect(find.text('安装更新'), findsNothing);
    });

    testWidgets('Android installs once however often it is tapped', (
      tester,
    ) async {
      await mount(tester);
      set(_status(AppUpdatePhase.staged, package: UpdatePackage.androidApk));
      await tester.pumpAndSettle();
      expect(find.text('ZolNit 1.3.0 已下载，可以安装'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('zolnit-update-download')),
        findsOneWidget,
      );
      final install = find.byKey(const ValueKey('zolnit-update-install'));
      await tester.tap(install);
      await tester.pump();
      await tester.tap(install, warnIfMissed: false);
      await tester.pump();
      expect(actions.applies, 1);
      set(_status(AppUpdatePhase.applying, package: UpdatePackage.androidApk));
      await tester.pumpAndSettle();
      expect(find.text('正在打开安装程序…'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsNothing);
    });

    testWidgets('install permission offers later and explicit authorization', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        TestApp(
          includeNavigatorKey: false,
          locale: const Locale('zh', 'CN'),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmUpdateInstallation(
                context,
                () async => false,
              ),
              child: const Text('test permission'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('test permission'));
      await tester.pumpAndSettle();
      expect(find.text('前往授权'), findsOneWidget);
      await tester.tap(find.text('稍后安装'));
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.tap(find.text('test permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('前往授权'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('already granted install permission does not open a prompt', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        TestApp(
          includeNavigatorKey: false,
          locale: const Locale('zh', 'CN'),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmUpdateInstallation(
                context,
                () async => true,
              ),
              child: const Text('test granted'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('test granted'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.text('前往授权'), findsNothing);
    });

    testWidgets('a failed update offers the website download', (tester) async {
      await mount(tester);
      set(_status(AppUpdatePhase.failed, package: UpdatePackage.androidApk));
      await tester.pumpAndSettle();
      expect(find.text('自动更新未完成，请从官网下载 ZolNit 1.3.0。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('zolnit-update-download')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      set(_status(AppUpdatePhase.failed, package: UpdatePackage.androidApk));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
    });

    testWidgets(
      'a denied install keeps retry and opens the official page fallback',
      (tester) async {
        await mount(tester);
        final staged = _status(
          AppUpdatePhase.staged,
          package: UpdatePackage.androidApk,
        );
        set(
          AppUpdateStatus(
            phase: staged.phase,
            release: staged.release,
            plan: staged.plan,
            failure: const MessageException('ZolNit 未获得安装应用的权限，因此未安装更新。'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('zolnit-update-install')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('zolnit-update-download')));
        await tester.pumpAndSettle();
        expect(
          find.text('https://link.zolmid.com/theme/ZolNit/downloads.html'),
          findsOneWidget,
        );
      },
    );

    testWidgets('reduced motion shows the status in one frame', (tester) async {
      await mount(tester, still: true);
      set(_status(AppUpdatePhase.announcement));
      await tester.pump();
      expect(banner, findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
