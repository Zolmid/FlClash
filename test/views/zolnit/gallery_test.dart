import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_status.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/help.dart';
import 'package:fl_clash/views/zolnit/home.dart';
import 'package:fl_clash/views/zolnit/shell.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contrast.dart';
import 'harness.dart';

/// Every product screen and modal in light and dark, on phones, a tablet and
/// desktop windows, with each screen's text and icons held to WCAG AA.
///
/// With ZOLNIT_CAPTURE_DIR set it writes `gallery/<locale>-<form>-<mode>/`
/// PNGs and the visible copy of each screen; ZOLNIT_GALLERY_LOCALE=en renders
/// in English.
void main() {
  final harness = ZolnitHarness.register();
  final locale = Locale(
    Platform.environment['ZOLNIT_GALLERY_LOCALE'] ?? 'zh',
    Platform.environment['ZOLNIT_GALLERY_LOCALE'] == null ? 'CN' : null,
  );
  const forms = <String, (ZolnitSkin, Size)>{
    'ios-phone': (ZolnitSkin.ios, Size(390, 844)),
    'android-phone': (ZolnitSkin.android, Size(412, 915)),
    'android-tablet': (ZolnitSkin.android, Size(820, 1180)),
    'macos-wide': (ZolnitSkin.macos, Size(1440, 900)),
    'windows-wide': (ZolnitSkin.windows, Size(1280, 800)),
  };

  setUp(() {
    WidgetsApp.debugAllowBannerOverride = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => WidgetsApp.debugAllowBannerOverride = true);

  for (final MapEntry(key: form, value: (skin, size)) in forms.entries) {
    final selectedForms = Platform.environment['ZOLNIT_GALLERY_FORMS']?.split(
      ',',
    );
    if (selectedForms != null && !selectedForms.contains(form)) continue;
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('gallery $form $mode stays legible', (tester) async {
        final directory = Platform.environment['ZOLNIT_CAPTURE_DIR'];
        final folder = 'gallery/${locale.languageCode}-$form-$mode';
        final issues = <String>[];
        final copy = StringBuffer();
        globalState.packageInfo = PackageInfo(
          appName: 'ZolNit',
          packageName: 'com.zolmid.zolnit',
          version: '1.2.0',
          buildNumber: '120',
        );
        var ordered = false;
        final giftName = locale.languageCode == 'zh' ? '流量礼品' : 'Traffic gift';
        final giftDescription = locale.languageCode == 'zh'
            ? '活动赠送'
            : 'A gift for you';
        harness.panel = (request) {
          final path = request.url.path;
          if (path.endsWith('/user/info')) {
            return zolnitJson({
              'email': 'lin@example.com',
              'balance': 0,
              'uuid': 'gallery-fixture-account',
            });
          }
          if (path.endsWith('/zolnit-rewards/config')) {
            return zolnitJson({'enabled': true, 'gift_card_enabled': true});
          }
          if (path.endsWith('/gift-card/check')) {
            return zolnitJson({
              'template': {
                'name': giftName,
                'description': giftDescription,
                'type': 3,
              },
              'can_redeem': true,
              'rewards': {'balance': 500},
              'possible_rewards': [
                {'weight': 1, 'transfer_enable': 1073741824},
                {'weight': 1, 'expire_days': 7},
              ],
            });
          }
          if (path.endsWith('/gift-card/redeem')) {
            return zolnitJson({
              'template_name': giftName,
              'rewards': {'transfer_enable': 1073741824},
            });
          }
          if (path.endsWith('/gift-card/history')) {
            return zolnitJson({
              'records': [
                {
                  'id': 1,
                  'template_name': giftName,
                  'rewards': {'transfer_enable': 1073741824},
                  'created_at': 1794000000,
                },
              ],
              'total': 1,
              'current_page': 1,
              'last_page': 1,
            });
          }
          if (path.endsWith('/order/save')) ordered = true;
          if (ordered && path.endsWith('/order/fetch')) {
            return zolnitJson([
              {
                'trade_no': 'trade-1',
                'status': 0,
                'plan_id': 2,
                'period': 'month_price',
                'total_amount': 4800,
                'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                'plan': {'id': 2, 'name': '畅享'},
              },
              {
                'trade_no': 'trade-0',
                'status': 2,
                'plan_id': 1,
                'period': 'month_price',
                'total_amount': 2800,
                'created_at': 1790000000,
                'plan': {'id': 1, 'name': '轻享'},
              },
            ]);
          }
          return zolnitPanelFixture(request);
        };
        await harness.relogin();
        await harness.mount(
          tester,
          skin,
          dark: dark,
          size: size,
          locale: locale,
        );
        final t = tester.element(find.byType(ZolnitHomePage)).appLocalizations;

        Future<void> shot(String name) async {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: name);
          for (final issue in auditContrast(tester)) {
            issues.add('$name: $issue');
          }
          copy.writeln('## $name');
          final seen = <String>{};
          for (final element in find.byType(RichText).evaluate()) {
            final line = (element.renderObject! as RenderParagraph).text
                .toPlainText()
                .trim();
            if (line.isNotEmpty && seen.add(line)) copy.writeln(line);
          }
          if (directory == null) return;
          await tester.runAsync(() async {
            final view = tester.binding.renderViews.first;
            final layer = view.debugLayer! as OffsetLayer;
            final image = await layer.toImage(Offset.zero & view.size);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$directory/$folder/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> scrolled(String name) async {
          final list = find.byType(Scrollable);
          if (list.evaluate().isEmpty) return;
          await tester.drag(list.first, const Offset(0, -700));
          await shot(name);
          await tester.drag(list.first, const Offset(0, 2000));
          await tester.pumpAndSettle();
        }

        Future<void> close(Finder route) async {
          Navigator.of(tester.element(route.last)).pop();
          await tester.pumpAndSettle();
        }

        Future<void> go(String label) => tap(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (w) =>
                      w is NavigationDock ||
                      w is ZolnitNavRail ||
                      w is ZolnitSidebar,
                ),
                matching: find.text(label),
              )
              .first,
        );

        Future<void> giftShots() async {
          await tester.ensureVisible(find.text(t.zolnitGiftCard).first);
          await shot('20-gift-entry');
          await tap(find.text(t.zolnitGiftCard).first);
          if (size.width >= 1200) {
            expect(find.byType(ZolnitSidebar), findsOneWidget);
          } else if (size.width < 600) {
            expect(find.byType(NavigationDock), findsOneWidget);
          }
          expect(find.byTooltip(t.back), findsOneWidget);
          final secret = tester.widget<SecretTextFormField>(
            find.byType(SecretTextFormField),
          );
          expect(secret.showVisibilityToggle, isFalse);
          expect(secret.keyboardType, TextInputType.text);
          await shot('21-gift-available');
          await tester.enterText(find.byType(TextField), 'GALLERY123');
          await tap(find.text(t.zolnitGiftCheck));
          await shot('22-gift-preview');
          await tap(find.text(t.zolnitGiftConfirm));
          await shot('23-gift-result');
          await tester.ensureVisible(find.text(t.zolnitGiftHistory));
          await shot('24-gift-history');
          await tap(find.byTooltip(t.back));
        }

        if (Platform.environment['ZOLNIT_GALLERY_GIFT_ONLY'] == '1') {
          await go(t.account);
          await giftShots();
          expect(issues, isEmpty, reason: issues.join('\n'));
          return;
        }

        await shot('01-connect');
        await scrolled('02-connect-scrolled');
        await go(t.zolnitAllNodes);
        await shot('03-nodes');
        await go(t.zolnitPlans);
        await shot('04-plans');
        await scrolled('05-plans-scrolled');
        await tap(find.byKey(const ValueKey('zolnit-plan-option-2')));
        await tap(find.text(t.zolnitChoosePlan).first);
        await shot('06-plan-confirm');
        await tap(find.text(t.zolnitBuy).last);
        await shot('07-cashier');
        await tap(find.byTooltip(t.back));
        await tap(find.text(t.zolnitTabAccount).first);
        await shot('08-account');
        await scrolled('09-account-scrolled');
        await giftShots();
        await tap(find.text(t.zolnitTabOrders).first);
        await shot('10-orders');
        await tap(find.text(t.zolnitTabInvite).first);
        await shot('11-invite');
        await tap(find.text(t.zolnitTabAccount).first);
        await tap(find.text(t.zolnitPreferences).last);
        await shot('12-preferences');
        await tap(find.byTooltip(t.zolnitNotices));
        await shot('13-notices');
        await close(find.byType(AlertDialog));
        await go(t.zolnitPlans);
        await go(t.account);
        await tap(find.text(t.zolnitHelpSupport).last);
        await shot('14-help');
        await close(find.byType(ZolnitHelpPage));

        harness.panel = zolnitEmptyPanelFixture;
        await harness.relogin();
        await go(t.connection);
        await shot('15-connect-empty');

        final package = switch (skin) {
          ZolnitSkin.android => UpdatePackage.androidApk,
          ZolnitSkin.macos => UpdatePackage.macosDmg,
          ZolnitSkin.windows => UpdatePackage.windowsInstaller,
          _ => null,
        };
        harness.container
            .read(appUpdateStatusProvider.notifier)
            .set(
              AppUpdateStatus(
                phase: package == null
                    ? AppUpdatePhase.announcement
                    : AppUpdatePhase.staged,
                release: const ReleaseManifest(tag: 'v1.3.0', notes: ''),
                plan: package == null
                    ? null
                    : AppUpdatePlan(
                        target: UpdateTarget(package, 'arm64'),
                        asset: const ReleaseAsset(
                          name: 'ZolNit',
                          url: 'https://link.zolmid.com/client/downloads/x/z',
                          size: 1,
                          sha256: '',
                        ),
                      ),
              ),
            );
        await shot('16-update');

        await harness.session.logout();
        await shot('17-login-update');
        harness.container
            .read(appUpdateStatusProvider.notifier)
            .set(const AppUpdateStatus());
        await shot('18-login');
        await tap(find.byKey(const ValueKey('zolnit-sign-in')));
        await shot('19-login-invalid');

        if (directory != null) {
          await tester.runAsync(() async {
            await File('$directory/$folder/copy.md').writeAsString('$copy');
            await File(
              '$directory/$folder/contrast.txt',
            ).writeAsString(issues.join('\n'));
          });
        }
        expect(issues, isEmpty, reason: issues.join('\n'));
      });
    }
  }
}
