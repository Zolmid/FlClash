import 'app_update.dart';

enum AppUpdatePhase {
  idle,
  checking,
  announcement,
  staging,
  staged,
  applying,
  failed,
}

enum AppUpdateApplyMode { onRestart, userAction, announcementOnly }

class AppUpdateStatus {
  const AppUpdateStatus({
    this.phase = AppUpdatePhase.idle,
    this.release,
    this.plan,
    this.failure,
  });

  final AppUpdatePhase phase;
  final ReleaseManifest? release;
  final AppUpdatePlan? plan;
  final Object? failure;

  AppUpdateApplyMode get applyMode => switch (plan?.target.package) {
    UpdatePackage.windowsInstaller ||
    UpdatePackage.macosDmg ||
    UpdatePackage.linuxAppImage => AppUpdateApplyMode.onRestart,
    UpdatePackage.androidApk => AppUpdateApplyMode.userAction,
    _ => AppUpdateApplyMode.announcementOnly,
  };

  bool get isTerminal => switch (phase) {
    AppUpdatePhase.idle ||
    AppUpdatePhase.announcement ||
    AppUpdatePhase.staged ||
    AppUpdatePhase.failed => true,
    _ => false,
  };
}

AppUpdateApplyMode appUpdateApplyModeFor(AppUpdatePlan? plan) =>
    AppUpdateStatus(plan: plan).applyMode;

bool canStageAppUpdate(AppUpdatePlan plan) =>
    appUpdateApplyModeFor(plan) != AppUpdateApplyMode.announcementOnly;

bool canApplyStagedAppUpdate(AppUpdatePlan plan, {required bool allowRestart}) {
  final mode = appUpdateApplyModeFor(plan);
  return switch (mode) {
    AppUpdateApplyMode.onRestart => allowRestart,
    AppUpdateApplyMode.userAction => !allowRestart,
    AppUpdateApplyMode.announcementOnly => false,
  };
}
