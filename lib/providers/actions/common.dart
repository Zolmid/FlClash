part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;
  Future<void>? _appUpdateOperation;

  @override
  void build() {
    appUpdateClient.attach(ref.read);
  }

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    unawaited(
      globalState.safeRun(
        () => ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            ),
      ),
    );
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    if (_isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final [traffic, totalTraffic] = await Future.wait([
        _readTraffic(() => _core.getTraffic(onlyStatisticsProxy)),
        _readTraffic(() => _core.getTotalTraffic(onlyStatisticsProxy)),
      ]);
      if (traffic != null) {
        ref.read(trafficsProvider.notifier).addTraffic(traffic);
      }
      if (totalTraffic != null) {
        ref.read(totalTrafficProvider.notifier).value = totalTraffic;
      }
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<Traffic?> _readTraffic(Future<Traffic> Function() request) async {
    try {
      return await request();
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<bool> autoCheckUpdate() async {
    if (system.isIOS) return false;
    if (!ref.read(appSettingProvider).autoCheckUpdate) return false;
    final ReleaseManifest? res;
    try {
      res = await appUpdateClient.checkForUpdate(
        currentVersion: globalState.packageInfo.version,
        target: await detectAppUpdateTarget(),
      );
    } catch (error) {
      commonPrint.log(
        'checkForUpdate failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    await checkUpdateResultHandle(data: res);
    return res != null;
  }

  TextSpan _releaseSpan(BuildContext context, String tagName, String? body) {
    final version = parseReleaseChangelog(body);
    return TextSpan(
      text: '$tagName \n',
      style: AppTextStyle.title2.of(context),
      children: version == null
          ? [
              TextSpan(text: '\n', style: AppTextStyle.subheadline.of(context)),
              for (final submit in parseReleaseBody(body))
                TextSpan(
                  text: '- $submit \n',
                  style: AppTextStyle.subheadline.of(context),
                ),
            ]
          : _changelogSpans(context, version),
    );
  }

  List<TextSpan> _changelogSpans(
    BuildContext context,
    ChangelogVersion version,
  ) {
    return [
      for (final group in version.visibleGroups) ...[
        TextSpan(
          text:
              '\n${changelogGroupTitle(currentAppLocalizations, group.type)}\n',
          style: AppTextStyle.subheadline
              .of(context, emphasized: true)
              .copyWith(
                color: group.type == ChangelogType.breaking
                    ? context.colorScheme.error
                    : context.colorScheme.primary,
              ),
        ),
        for (final entry in group.entries)
          TextSpan(
            text: '• ${entry.text}\n',
            style: AppTextStyle.subheadline.of(context),
          ),
      ],
    ];
  }

  Future<void> checkUpdateResultHandle({
    Object? data,
    bool isUser = false,
  }) async {
    final release = switch (data) {
      null => null,
      ReleaseManifest() => data,
      _ => ReleaseManifest.fromGitHubRelease(data),
    };
    if (release != null) {
      final message = _releaseSpan(
        globalState.navigatorKey.currentContext!,
        release.tag,
        release.notes,
      );
      final plan = await _planAppUpdate(release);
      final updatesInApp = plan?.target.package.updatesInApp ?? false;
      final res = await dialogs.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: message,
        leadingAction: TextButton(
          onPressed: () => launchUrl(
            release.releaseUri,
            mode: LaunchMode.externalApplication,
          ),
          child: Text(currentAppLocalizations.zolnitWebsite),
        ),
        confirmText: updatesInApp
            ? currentAppLocalizations.updateNow
            : currentAppLocalizations.goDownload,
        cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        if (plan == null || !updatesInApp) {
          unawaited(launchUrl(browserDownloadUri(plan, release: release)));
        } else {
          await globalState.safeRun(
            () => applyAppUpdate(plan),
            title: currentAppLocalizations.checkUpdate,
            silence: false,
          );
        }
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      unawaited(
        dialogs.showMessage(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: currentAppLocalizations.checkUpdateError),
        ),
      );
    }
  }

  @visibleForTesting
  Future<UpdateTarget> Function() detectAppUpdateTarget = detectUpdateTarget;

  Future<AppUpdatePlan?> _planAppUpdate(ReleaseManifest release) async {
    if (release.assets.isEmpty) return null;
    try {
      return planAppUpdate(release, await detectAppUpdateTarget());
    } catch (error) {
      commonPrint.log(
        'update target detection failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  @visibleForTesting
  Future<void> applyAppUpdate(AppUpdatePlan plan) {
    final active = _appUpdateOperation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _runAppUpdate(plan).whenComplete(() {
      if (identical(_appUpdateOperation, operation)) {
        _appUpdateOperation = null;
      }
    });
    _appUpdateOperation = operation;
    return operation;
  }

  Future<void> _runAppUpdate(AppUpdatePlan plan) async {
    try {
      await installAppUpdate(plan);
    } on UpdaterException catch (error) {
      throw MessageException(switch (error.reason) {
        UpdaterFailureReason.checksumMismatch =>
          currentAppLocalizations.updateChecksumMismatch,
        UpdaterFailureReason.notWritable =>
          currentAppLocalizations.updateNotWritable,
        UpdaterFailureReason.installFailed =>
          currentAppLocalizations.updateInstallFailed,
      });
    }
  }

  @protected
  Future<void> installAppUpdate(AppUpdatePlan plan) async {
    final file = await _downloadAppUpdate(plan);
    if (file == null) {
      return;
    }
    final package = plan.target.package;
    switch (package) {
      case UpdatePackage.windowsInstaller:
        await appInstaller.startWindowsInstaller(file);
        await _exitForUpdate();
      case UpdatePackage.macosDmg:
        await appInstaller.startMacosInstall(file);
        await _exitForUpdate();
      case UpdatePackage.linuxAppImage:
        await appInstaller.replaceAppImage(file);
        await appInstaller.startAppImageRelaunch();
        await _exitForUpdate();
      case UpdatePackage.androidApk:
        await _installApk(file);
      case UpdatePackage.linuxDeb ||
          UpdatePackage.linuxRpm ||
          UpdatePackage.linuxPacman:
        if (await installPackageUpdate(plan, file)) {
          await appInstaller.startRelaunch();
          await _exitForUpdate();
        }
      case UpdatePackage.windowsPortable ||
          UpdatePackage.linuxPortable ||
          UpdatePackage.unsupported:
        throw StateError('$package cannot be installed in place');
    }
  }

  @visibleForTesting
  Future<bool> installPackageUpdate(AppUpdatePlan plan, File file) async {
    final setup = ref.read(setupActionProvider.notifier);
    final core = ref.read(coreActionProvider.notifier);
    final intent = setup._latestRunRequest;
    final restartRevision = core._requestedRestartRevision;
    final wasRunning = ref.read(isStartProvider);
    final stopped = await _core.stop();
    if (stopped.outcome == CoreLifecycleOutcome.superseded ||
        !ref.mounted ||
        !identical(setup._latestRunRequest, intent) ||
        core._requestedRestartRevision != restartRevision ||
        ref.read(isStartProvider) != wasRunning) {
      throw StateError(
        'Core shutdown was superseded before the package update',
      );
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    var installed = false;
    try {
      installed = await installPackage(plan, file);
      return installed;
    } finally {
      if (!installed &&
          ref.mounted &&
          identical(setup._latestRunRequest, intent) &&
          core._requestedRestartRevision == restartRevision &&
          ref.read(isStartProvider) == wasRunning &&
          ref.read(coreStatusProvider) == CoreStatus.disconnected) {
        try {
          await recoverPackageCore(wasRunning);
        } catch (error) {
          commonPrint.log(
            'Unable to restore Core after the package update: $error',
            logLevel: LogLevel.error,
          );
        }
      }
    }
  }

  @protected
  Future<bool> installPackage(AppUpdatePlan plan, File file) =>
      appInstaller.installWithPackageManager(plan, file);

  @protected
  Future<void> recoverPackageCore(bool running) async {
    final setup = ref.read(setupActionProvider.notifier);
    final core = ref.read(coreActionProvider.notifier);
    final intent = setup._latestRunRequest;
    final restartRevision = core._requestedRestartRevision;
    final applied = await core.startCore();
    if (!applied ||
        !ref.mounted ||
        !identical(setup._latestRunRequest, intent) ||
        core._requestedRestartRevision != restartRevision ||
        ref.read(isStartProvider) != running ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    if (running) {
      await setup.setRunning(true, initialize: true);
    } else {
      await setup.applyProfile(force: true);
    }
  }

  Future<File?> _downloadAppUpdate(AppUpdatePlan plan) async {
    final outcome = await dialogs.showCommonDialog<ProgressOutcome<File>>(
      dismissible: false,
      child: UpdateProgressDialog<File>(
        expectedTotal: plan.asset.size,
        task: (onProgress, cancelToken) => appInstaller.download(
          plan,
          onReceiveProgress: onProgress,
          cancelToken: cancelToken,
        ),
      ),
    );
    if (outcome == null) {
      return null;
    }
    final error = outcome.error;
    if (error == null) {
      return outcome.value;
    }
    if (error is DioException && error.type == DioExceptionType.cancel) {
      return null;
    }
    Error.throwWithStackTrace(error, outcome.stackTrace!);
  }

  Future<void> _exitForUpdate() {
    return ref.read(systemActionProvider.notifier).handleExit();
  }

  Future<void> _installApk(File apk) async {
    final status = await appInstaller.installApk(apk);
    switch (status) {
      case ApkInstallStatus.started:
        return;
      case ApkInstallStatus.permissionDenied:
        throw MessageException(currentAppLocalizations.updateInstallPermission);
      case ApkInstallStatus.failed:
        throw MessageException(currentAppLocalizations.updateInstallFailed);
    }
  }
}
