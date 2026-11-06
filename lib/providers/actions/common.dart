part of '../action.dart';

const appUpdateDiscoveryInterval = Duration(hours: 12);

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;
  Future<void>? _appUpdateOperation;
  Future<void>? _appUpdateCheckOperation;
  File? _stagedUpdate;
  CancelToken? _stagingCancelToken;
  bool _restartFailureDetected = false;
  Timer? _updateDiscoveryTimer;
  bool _realtimeUpdateHintsHealthy = false;
  ReleaseManifest? _pendingUpdateHint;
  DateTime? _lastUpdateDiscovery;

  void _setUpdateStatus(AppUpdateStatus value) =>
      ref.read(appUpdateStatusProvider.notifier).set(value);

  @override
  void build() {
    appUpdateClient.attach(ref.read);
    ref.onDispose(() => _updateDiscoveryTimer?.cancel());
    ref.listen(appVisibleProvider, (_, visible) {
      if (visible &&
          _updateDiscoveryTimer != null &&
          !_realtimeUpdateHintsHealthy) {
        unawaited(checkForAppUpdate());
      }
    });
  }

  void startUpdateDiscovery() {
    _updateDiscoveryTimer ??= Timer.periodic(appUpdateDiscoveryInterval, (_) {
      if (!_realtimeUpdateHintsHealthy) unawaited(checkForAppUpdate());
    });
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

  Future<bool> autoCheckUpdate() => checkForAppUpdate();

  Future<void> restoreAppUpdateResult() async {
    final String? failedTag;
    try {
      failedTag = await appInstaller.consumeRestartFailure(
        globalState.packageInfo.version,
      );
    } catch (error) {
      commonPrint.log(
        'unable to read the previous update result: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      if (!ref.mounted) return;
      _restartFailureDetected = true;
      _setUpdateStatus(
        AppUpdateStatus(phase: AppUpdatePhase.failed, failure: error),
      );
      return;
    }
    if (failedTag == null || !ref.mounted) return;
    _restartFailureDetected = true;
    _setUpdateStatus(
      AppUpdateStatus(
        phase: AppUpdatePhase.failed,
        release: failedTag == 'unknown'
            ? null
            : ReleaseManifest(tag: failedTag, notes: ''),
        failure: StateError(
          'The previous update did not start the new version',
        ),
      ),
    );
  }

  /// Re-checks the first-party manifest after a server hint. The hint never
  /// supplies a URL, checksum, or package to trust.
  Future<bool> notifyAppUpdateHint({String? version}) {
    final validVersion =
        version != null &&
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) &&
        version.length <= 32;
    if (validVersion) {
      _pendingUpdateHint = ReleaseManifest(tag: 'v$version', notes: '');
    }
    return checkForAppUpdate(force: true);
  }

  void setAppUpdateRealtimeHintsHealthy(bool healthy) {
    _realtimeUpdateHintsHealthy = healthy;
    if (!healthy) unawaited(checkForAppUpdate());
  }

  void cancelAppUpdateStaging() => _stagingCancelToken?.cancel();

  Future<bool> checkForAppUpdate({bool isUser = false, bool force = false}) {
    if (!isUser && !force && !_updateDiscoveryDue) {
      return Future<bool>.value(_hasStagedOrAnnouncement);
    }
    final active = _appUpdateCheckOperation;
    if (active != null) return active.then((_) => _hasStagedOrAnnouncement);
    late final Future<void> operation;
    _lastUpdateDiscovery = DateTime.now();
    operation = _checkForAppUpdate(isUser: isUser).whenComplete(() {
      if (identical(_appUpdateCheckOperation, operation)) {
        _appUpdateCheckOperation = null;
      }
    });
    _appUpdateCheckOperation = operation;
    return operation.then((_) => _hasStagedOrAnnouncement);
  }

  bool get _hasStagedOrAnnouncement =>
      switch (ref.read(appUpdateStatusProvider).phase) {
        AppUpdatePhase.announcement || AppUpdatePhase.staged => true,
        _ => false,
      };

  bool get _updateDiscoveryDue {
    final last = _lastUpdateDiscovery;
    return last == null ||
        DateTime.now().difference(last) >= appUpdateDiscoveryInterval;
  }

  Future<void> _checkForAppUpdate({required bool isUser}) async {
    final previousStatus = ref.read(appUpdateStatusProvider);
    if (!isUser && !ref.read(appSettingProvider).autoCheckUpdate) return;
    if (!isUser && _restartFailureDetected) return;
    if (isUser) _restartFailureDetected = false;
    _setUpdateStatus(const AppUpdateStatus(phase: AppUpdatePhase.checking));
    final UpdateTarget target;
    try {
      target = await detectAppUpdateTarget();
    } catch (error) {
      commonPrint.log(
        'update target detection failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      _setUpdateStatus(
        AppUpdateStatus(phase: AppUpdatePhase.failed, failure: error),
      );
      return;
    }
    final ReleaseManifest? release;
    try {
      release = await appUpdateClient.latestRelease(
        currentVersion: globalState.packageInfo.version,
        target: target == UpdateTarget.unsupported && isUser ? null : target,
      );
    } catch (error) {
      commonPrint.log(
        'checkForUpdate failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      _setUpdateStatus(
        AppUpdateStatus(phase: AppUpdatePhase.failed, failure: error),
      );
      return;
    }
    if (release == null) {
      final hint = _pendingUpdateHint;
      if (hint != null && _isNewerHint(hint)) {
        _setUpdateStatus(
          AppUpdateStatus(phase: AppUpdatePhase.announcement, release: hint),
        );
      } else {
        _setUpdateStatus(const AppUpdateStatus());
      }
      return;
    }
    final comparison = compareVersions(
      release.tag,
      globalState.packageInfo.version,
    );
    if (comparison <= 0) {
      final hint = _pendingUpdateHint;
      _setUpdateStatus(
        hint != null && _isNewerHint(hint)
            ? AppUpdateStatus(phase: AppUpdatePhase.announcement, release: hint)
            : const AppUpdateStatus(),
      );
      return;
    }
    final plan = await _planAppUpdate(release);
    if (plan == null || !canStageAppUpdate(plan)) {
      _setUpdateStatus(
        AppUpdateStatus(
          phase: AppUpdatePhase.announcement,
          release: release,
          plan: plan,
        ),
      );
      return;
    }
    if (previousStatus.phase == AppUpdatePhase.staged &&
        _sameUpdatePlan(previousStatus.plan, plan) &&
        _stagedUpdate != null) {
      _setUpdateStatus(previousStatus);
      return;
    }
    _setUpdateStatus(
      AppUpdateStatus(
        phase: AppUpdatePhase.staging,
        release: release,
        plan: plan,
      ),
    );
    final cancelToken = CancelToken();
    _stagingCancelToken = cancelToken;
    try {
      final staged = await appInstaller.download(
        plan,
        cancelToken: cancelToken,
      );
      if (!ref.mounted) return;
      _stagedUpdate = staged;
      _setUpdateStatus(
        AppUpdateStatus(
          phase: AppUpdatePhase.staged,
          release: release,
          plan: plan,
        ),
      );
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        if (ref.mounted) {
          _setUpdateStatus(
            AppUpdateStatus(
              phase: AppUpdatePhase.announcement,
              release: release,
              plan: plan,
            ),
          );
        }
        return;
      }
      commonPrint.log(
        'update staging failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      if (ref.mounted) {
        _setUpdateStatus(
          AppUpdateStatus(
            phase: AppUpdatePhase.failed,
            release: release,
            plan: plan,
            failure: error,
          ),
        );
      }
    } finally {
      if (identical(_stagingCancelToken, cancelToken)) {
        _stagingCancelToken = null;
      }
    }
  }

  bool _sameUpdatePlan(AppUpdatePlan? left, AppUpdatePlan right) =>
      left != null &&
      left.target == right.target &&
      left.asset.url == right.asset.url &&
      left.asset.sha256 == right.asset.sha256 &&
      left.asset.size == right.asset.size;

  bool _isNewerHint(ReleaseManifest hint) {
    try {
      return compareVersions(hint.tag, globalState.packageInfo.version) > 0;
    } on FormatException {
      return false;
    }
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
    await _installWithRestartJournal(plan, file, exitAfterInstall: true);
  }

  Future<void> applyStagedAppUpdate() =>
      _applyStagedAppUpdate(allowRestart: false);

  /// Called only from the normal application exit path. It never stops the
  /// Core or VPN; the existing exit coordinator performs that work afterwards.
  Future<void> applyStagedAppUpdateOnExit() =>
      _applyStagedAppUpdate(allowRestart: true);

  Future<void> _applyStagedAppUpdate({required bool allowRestart}) async {
    final status = ref.read(appUpdateStatusProvider);
    final plan = status.plan;
    final file = _stagedUpdate;
    if (status.phase != AppUpdatePhase.staged || plan == null || file == null) {
      return;
    }
    if (!canApplyStagedAppUpdate(plan, allowRestart: allowRestart)) {
      return;
    }
    _setUpdateStatus(
      AppUpdateStatus(
        phase: AppUpdatePhase.applying,
        release: status.release,
        plan: plan,
      ),
    );
    try {
      await _installWithRestartJournal(
        plan,
        file,
        exitAfterInstall: false,
        markRestart: allowRestart,
      );
    } catch (error) {
      if (ref.mounted) {
        _setUpdateStatus(
          AppUpdateStatus(
            phase: AppUpdatePhase.failed,
            release: status.release,
            plan: plan,
            failure: error,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _installWithRestartJournal(
    AppUpdatePlan plan,
    File file, {
    required bool exitAfterInstall,
    bool markRestart = true,
  }) async {
    final restart = appUpdateApplyModeFor(plan) == AppUpdateApplyMode.onRestart;
    if (restart && markRestart) await appInstaller.markRestartPending(plan);
    try {
      await _installDownloadedAppUpdate(
        plan,
        file,
        exitAfterInstall: exitAfterInstall,
      );
    } catch (_) {
      if (restart && markRestart) await appInstaller.clearRestartPending();
      rethrow;
    }
  }

  Future<void> _installDownloadedAppUpdate(
    AppUpdatePlan plan,
    File file, {
    required bool exitAfterInstall,
  }) async {
    final package = plan.target.package;
    switch (package) {
      case UpdatePackage.windowsInstaller:
        await appInstaller.startWindowsInstaller(
          file,
          relaunch: exitAfterInstall,
        );
        if (exitAfterInstall) await _exitForUpdate();
      case UpdatePackage.macosDmg:
        await appInstaller.startMacosInstall(file, relaunch: exitAfterInstall);
        if (exitAfterInstall) await _exitForUpdate();
      case UpdatePackage.linuxAppImage:
        await appInstaller.replaceAppImage(file);
        if (exitAfterInstall) await appInstaller.startAppImageRelaunch();
        if (exitAfterInstall) await _exitForUpdate();
      case UpdatePackage.androidApk:
        await _installApk(file);
      case UpdatePackage.linuxDeb ||
          UpdatePackage.linuxRpm ||
          UpdatePackage.linuxPacman:
        if (await installPackageUpdate(plan, file)) {
          await appInstaller.startRelaunch();
          if (exitAfterInstall) await _exitForUpdate();
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
