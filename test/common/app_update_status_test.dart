import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_status.dart';
import 'package:test/test.dart';

AppUpdatePlan _plan(UpdatePackage package) => AppUpdatePlan(
  target: UpdateTarget(package, 'x64'),
  asset: const ReleaseAsset(
    name: 'unused',
    url: 'https://example.invalid/unused',
    size: 1,
    sha256: '',
  ),
);

void main() {
  test('only verified installer formats may be staged automatically', () {
    for (final package in [
      UpdatePackage.windowsInstaller,
      UpdatePackage.macosDmg,
      UpdatePackage.linuxAppImage,
      UpdatePackage.androidApk,
    ]) {
      expect(canStageAppUpdate(_plan(package)), isTrue, reason: package.name);
    }
    for (final package in [
      UpdatePackage.windowsPortable,
      UpdatePackage.linuxPortable,
      UpdatePackage.linuxDeb,
      UpdatePackage.linuxRpm,
      UpdatePackage.linuxPacman,
      UpdatePackage.unsupported,
    ]) {
      expect(canStageAppUpdate(_plan(package)), isFalse, reason: package.name);
    }
  });

  test(
    'staged packages distinguish restart, explicit Android, and fallback',
    () {
      expect(
        appUpdateApplyModeFor(_plan(UpdatePackage.windowsInstaller)),
        AppUpdateApplyMode.onRestart,
      );
      expect(
        appUpdateApplyModeFor(_plan(UpdatePackage.macosDmg)),
        AppUpdateApplyMode.onRestart,
      );
      expect(
        appUpdateApplyModeFor(_plan(UpdatePackage.linuxAppImage)),
        AppUpdateApplyMode.onRestart,
      );
      expect(
        appUpdateApplyModeFor(_plan(UpdatePackage.androidApk)),
        AppUpdateApplyMode.userAction,
      );
      expect(
        appUpdateApplyModeFor(_plan(UpdatePackage.windowsPortable)),
        AppUpdateApplyMode.announcementOnly,
      );
      expect(
        canApplyStagedAppUpdate(
          _plan(UpdatePackage.windowsInstaller),
          allowRestart: true,
        ),
        isTrue,
      );
      expect(
        canApplyStagedAppUpdate(
          _plan(UpdatePackage.windowsInstaller),
          allowRestart: false,
        ),
        isFalse,
      );
      expect(
        canApplyStagedAppUpdate(
          _plan(UpdatePackage.androidApk),
          allowRestart: true,
        ),
        isFalse,
      );
      expect(
        canApplyStagedAppUpdate(
          _plan(UpdatePackage.androidApk),
          allowRestart: false,
        ),
        isTrue,
      );
    },
  );
}
