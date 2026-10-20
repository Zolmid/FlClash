part of '../action.dart';

enum _SetupTaskResult { completed, handoffToCoreRestart, failed }

typedef _SetupInputs = (
  SetupState,
  PatchClashConfig,
  NetworkProps,
  SetupParams,
);

typedef BuiltProfile = ({
  String yaml,
  String md5,
  ConfigCounts counts,
  SetupBase? base,
  ProfileTun tun,
});

class _RunRequest {
  final bool running;
  final bool initialize;
  final DateTime? previousStartTime;
  bool retryProfileBuild = false;

  _RunRequest({
    required this.running,
    required this.initialize,
    required this.previousStartTime,
  });
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  @protected
  bool get listenerManagedByService => system.isIOS;

  Timer? _runtimeTimer;
  final _setupScheduler = SerialTaskScheduler();
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;
  _SetupInputs? _appliedInputs;
  var _pendingForceApply = false;

  bool get _isRunning => _startTime != null && _startTime!.isBeforeNow;

  @override
  void build() {
    ref.onDispose(_stopRuntimeTicker);
    ref.listen(appVisibleProvider, (_, _) => _syncRuntimeTicker());
    ref.listen(
      appSettingProvider.select((state) => state.showTrayTitle),
      (_, _) => _syncRuntimeTicker(),
    );
  }

  bool get _isTrafficShown =>
      ref.read(appVisibleProvider) ||
      (system.isMacOS &&
          !ref.read(safeModeProvider) &&
          ref.read(appSettingProvider).showTrayTitle);

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final appSetting = ref.read(appSettingProvider);
    return SetupParams(
      selectedMap: selectedMap,
      testUrl: appSetting.testUrl,
      skipCertVerify: !appSetting.checkCertificate,
    );
  }

  // The selection reaches the Core through changeProxy, not through an apply.
  SetupParams get _appliedParams =>
      _setupParams.copyWith(selectedMap: const {});

  Future<bool> fullSetup() async {
    if (!ref.read(initProvider)) return true;
    ref.read(proxiesActionProvider.notifier).cancelDelayTests();
    ref.read(delayDataSourceProvider.notifier).value = {};
    final setupResult = applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(maxLogsLength);
    ref.read(requestsProvider.notifier).value = FixedList(maxRequestsLength);
    ref.read(dnsQueriesProvider.notifier).value = FixedList(
      maxDnsQueriesLength,
    );
    ref.read(dnsQueryCountProvider.notifier).value = 0;
    ref.read(requestCountProvider.notifier).value = 0;
    try {
      return await setupResult;
    } catch (e, s) {
      commonPrint.log('fullSetup ===> ${compactError(e)}, $s');
      return false;
    }
  }

  void _setLocalRunning(bool running) {
    _stopRuntimeTicker();
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _pendingForceApply = false;
      _updateRunTime();
      return;
    }

    _startTime ??= DateTime.now();
    _updateRunTime();
    _syncRuntimeTicker();
  }

  void _syncRuntimeTicker() {
    if (_startTime == null || !_isTrafficShown) {
      _stopRuntimeTicker();
      return;
    }
    if (_runtimeTimer != null) {
      return;
    }
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _stopRuntimeTicker() {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
  }

  void _refreshRunningState() {
    _updateRunTime();
    unawaited(ref.read(commonActionProvider.notifier).updateTraffic());
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  Future<void> _updateStartTime() async {
    _startTime = await service?.getRunTime();
  }

  void syncRunningState(bool running, {DateTime? startTime}) {
    if (running && startTime != null) {
      _startTime = startTime;
    }
    _setLocalRunning(running);
    if (!running) {
      ref.read(runningVpnOptionsProvider.notifier).value = null;
    }
  }

  Future<void> restoreServiceState() async {
    if (!system.isIOS ||
        !ref.read(initProvider) ||
        service?.tunnelState.value == TunnelState.pending) {
      return;
    }
    final request = _latestRunRequest;
    final tunnelState = service?.tunnelState.value;
    final startTime = await service?.getRunTime();
    if (!ref.mounted ||
        !identical(request, _latestRunRequest) ||
        tunnelState != service?.tunnelState.value) {
      return;
    }
    syncRunningState(startTime != null, startTime: startTime);
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      return;
    }
    if (system.isMobile) {
      await _updateStartTime();
    }
    final shouldRun = _isRunning || ref.read(appSettingProvider).autoRun;
    if (shouldRun) {
      await setRunning(true, initialize: true);
    } else {
      await globalState.safeRun(() => applyProfile(force: true));
    }
  }

  Future<bool> setRunning(bool running, {bool initialize = false}) {
    if (running && !initialize && !ref.read(initProvider)) {
      return Future.value(true);
    }

    final request = _RunRequest(
      running: running,
      initialize: running && initialize,
      previousStartTime: _startTime,
    );
    _latestRunRequest = request;
    _setLocalRunning(running);
    if (request.initialize) {
      globalState.needInitStatus = false;
    }
    return running ? _start(request) : _stop(request);
  }

  Future<bool> _start(_RunRequest request) async {
    while (_isCurrent(request)) {
      request.retryProfileBuild = false;
      if (request.initialize ||
          (listenerManagedByService &&
              (ref.read(effectiveProfileTunProvider) == null ||
                  !await _inputsApplied()))) {
        var applied = false;
        try {
          applied = await applyProfile(
            force: true,
            preloadInvoke: () => _startCoreRunning(request),
          );
        } catch (_) {
          applied = false;
        }
        if (!_isCurrent(request)) return true;
        if (request.retryProfileBuild) continue;
        if (!applied) {
          await globalState.safeRun(() => setRunning(false));
        }
        return applied;
      }

      try {
        await _startCoreRunning(request);
      } catch (_) {
        _rollbackRunning(request);
        rethrow;
      }
      if (!_isCurrent(request)) return true;
      if (request.retryProfileBuild) continue;
      final inputsApplied = await _inputsApplied();
      if (_isCurrent(request) && !inputsApplied) {
        applyProfileDebounce(force: true, silence: true);
      }
      return true;
    }
    return true;
  }

  Future<void> _startCoreRunning(_RunRequest request) async {
    if (!await _setCoreRunning(request) && _isCurrent(request)) {
      throw _unanswered(CoreMethod.startListener);
    }
  }

  Future<bool> _stop(_RunRequest request) async {
    final bool answered;
    try {
      answered = await _setCoreRunning(request);
    } catch (_) {
      _rollbackRunning(request);
      rethrow;
    }
    if (!_isCurrent(request)) {
      return true;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    // A silent Core is gone or hung; running again would proxy traffic to it.
    if (!answered) {
      throw _unanswered(CoreMethod.stopListener);
    }
    return true;
  }

  Future<bool> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request)) {
        return true;
      }
      if (request.running && !system.isIOS && ref.read(suspendProvider)) {
        return true;
      }
      if (ref.read(safeModeProvider)) {
        return true;
      }
      return _setListening(request.running, request: request);
    });
  }

  Future<bool> _setListening(bool running, {_RunRequest? request}) async {
    final snapshot = running && listenerManagedByService
        ? ref.read(builtProfileTunProvider)
        : null;
    bool isCurrent() =>
        ref.mounted &&
        (request == null || _isCurrent(request)) &&
        snapshot != null &&
        identical(
          ref.read(builtProfileTunProvider)?.generation,
          snapshot.generation,
        ) &&
        ref.read(effectiveProfileTunProvider) != null;
    bool superseded() {
      if (request != null) request.retryProfileBuild = true;
      return true;
    }

    if (running && listenerManagedByService && !isCurrent()) {
      return superseded();
    }
    final VpnOptions? vpnOptions;
    if (running) {
      // Keep an awaited async provider subscribed so dependency changes can
      // rebuild it instead of leaving its transferred future unresolved.
      final subscription = ref.listen(vpnOptionsProvider, (_, _) {});
      try {
        vpnOptions = await ref.read(vpnOptionsProvider.future);
      } finally {
        subscription.close();
      }
    } else {
      vpnOptions = null;
    }
    final SharedState? startState;
    if (running && listenerManagedByService) {
      if (!isCurrent()) return superseded();
      startState = ref
          .read(sharedStateProvider)
          .copyWith(vpnOptions: vpnOptions);
    } else {
      startState = null;
    }
    final answered = await setCoreRunning(
      running,
      startState: startState,
      isCurrent: startState == null ? null : isCurrent,
    );
    if (startState != null && !isCurrent()) return superseded();
    if (listenerManagedByService && !answered) {
      throw _unanswered(
        running ? CoreMethod.startListener : CoreMethod.stopListener,
      );
    }
    ref.read(runningVpnOptionsProvider.notifier).value = running && answered
        ? vpnOptions
        : null;
    return answered;
  }

  CoreMethodException _unanswered(CoreMethod method) => CoreMethodException(
    code: 'no_response',
    message: 'Core did not answer ${method.name}',
  );

  /// An excluded SSID parks the listener without ending the run.
  void syncSuspend() {
    if (system.isIOS) {
      return;
    }
    debouncer.call(FunctionTag.suspend, () {
      return _listenerScheduler.run(() async {
        if (!ref.read(isStartProvider) || ref.read(safeModeProvider)) {
          return;
        }
        await _setListening(!ref.read(suspendProvider));
      });
    });
  }

  Future<void> restartVpn() async {
    if (!ref.read(isStartProvider)) {
      return;
    }
    await setRunning(false);
    await setRunning(true);
  }

  void _rollbackRunning(_RunRequest request) {
    if (!_isCurrent(request)) {
      return;
    }
    _startTime = request.previousStartTime;
    _setLocalRunning(!request.running);
  }

  bool _isCurrent(_RunRequest request) =>
      ref.mounted && identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<bool> setCoreRunning(
    bool running, {
    SharedState? startState,
    bool Function()? isCurrent,
  }) {
    return running
        ? _core.startListener(startState: startState, isCurrent: isCurrent)
        : _core.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    _core.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await globalState.safeRun(() async {
      final patchConfig = ref.read(patchClashConfigProvider);
      final shouldContinueSetup = await requestAdmin(patchConfig.tun.enable);
      if (!shouldContinueSetup) {
        await _restartCoreAfterAuthorization();
        return;
      }
      final networkSetting = ref.read(networkSettingProvider);
      final message = await _core.updateConfig(
        _effectivePatchConfig(patchConfig).toUpdateParams(
          authentication: networkSetting.authentication.credentials,
          skipCertVerify: !ref.read(appSettingProvider).checkCertificate,
        ),
      );
      if (message.isNotEmpty) throw MessageException(message);
    });
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    _pendingForceApply |= force;
    debouncer.call(FunctionTag.applyProfile, (silence) {
      final force = _pendingForceApply;
      _pendingForceApply = false;
      applyProfile(silence: silence, force: force);
    }, args: [silence]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  /// For leaving an editor: a profile whose inputs match the config the Core
  /// already runs is not rebuilt, which on a large profile takes a while.
  void autoApplyProfile() {
    runAfterFrame(() async {
      if (!await _inputsApplied()) {
        await applyProfile();
      }
    });
  }

  Future<bool> _inputsApplied() async {
    final applied = _appliedInputs;
    if (applied == null) {
      return false;
    }
    final profileId = ref.read(currentProfileIdProvider);
    final SetupState setupState;
    try {
      setupState = await ref.read(setupStateProvider(profileId).future);
    } catch (_) {
      return false;
    }
    return applied ==
        (
          setupState,
          _effectivePatchConfig(ref.read(patchClashConfigProvider)),
          ref.read(networkSettingProvider),
          _appliedParams,
        );
  }

  // False means building the profile, the config write, or the Core setup
  // step failed; a profile that fails to build is still pushed to the Core
  // as the empty config so it never keeps serving the previous one.
  // authorizeCore failures still throw.
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _runSetup(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
    );
    return result != _SetupTaskResult.failed;
  }

  Future<_SetupTaskResult> _runSetup({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      return _setupConfig(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        onUpdated: () async {
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return result;
    }
    // Release the current serial task before restartCore reapplies the profile.
    final restarted = await _restartCoreAfterAuthorization();
    return restarted ? _SetupTaskResult.completed : _SetupTaskResult.failed;
  }

  Future<bool> _restartCoreAfterAuthorization() async {
    try {
      return await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  /// With a base, [BuiltProfile.yaml] is only the overlay the Core applies.
  Future<BuiltProfile> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) {
      return (
        yaml: '',
        md5: '',
        counts: configCountsOf(const {}),
        base: null,
        tun: const ProfileTun(),
      );
    }
    final defaultUA = globalState.packageInfo.ua;
    final networkSetting = ref.read(
      networkSettingProvider.select(
        (state) => (
          appendSystemDns: state.appendSystemDns,
          bypassPrivateRoute: state.bypassPrivateRoute,
          authentication: state.authentication,
        ),
      ),
    );
    final appendSystemDns = networkSetting.appendSystemDns;
    final isCustom = setupState.profileType == ProfileType.custom;
    final scriptContent =
        !isCustom && setupState.extendType == ExtendType.script
        ? await setupState.script?.content
        : null;
    final hasScript = scriptContent?.isNotEmpty == true;
    final profileBase = !isCustom && !hasScript
        ? await _core.getProfileBase(profileId)
        : null;
    Map<String, dynamic> rawConfig = isCustom
        ? {
            'proxies': appProxiesPayload(
              setupState.appProxies,
              dialers: setupState.proxyDialers,
              groups: setupState.proxyGroups,
            ),
          }
        : profileBase?.base.config ?? await _core.getConfig(profileId);
    final proxyGroups = isCustom ? setupState.proxyGroups : <ProxyGroup>[];
    final rules = isCustom ? setupState.rules : <Rule>[];
    if (hasScript) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final injected = await _resolveInjectedProviders(
      setupState,
      proxyGroups: proxyGroups,
      rules: rules,
    );
    final res = await makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        injectedProxyProviders: injected.proxies,
        injectedRuleProviders: injected.rules,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: patchConfig,
        overrides: setupState.overrides,
        bypassPrivateRoute: networkSetting.bypassPrivateRoute,
        keepEmptyDnsOverrides: setupState.profileType != ProfileType.custom,
        appendSystemDns: appendSystemDns,
        addedRules: setupState.addedRules,
        defaultUA: defaultUA,
        authentication: networkSetting.authentication.credentials,
        matchTarget:
            profileBase == null ||
                setupState.matchTarget?.trim().isNotEmpty == true
            ? setupState.matchTarget
            : lastMatchTarget(profileBase.base.matchRules),
        safeMode: ref.read(safeModeProvider),
      ),
    );
    if (profileBase == null) {
      return (
        yaml: res.yaml,
        md5: res.md5,
        counts: res.counts,
        base: null,
        tun: res.tun,
      );
    }
    final (:base, :path) = profileBase;
    return (
      yaml: res.yaml,
      md5: '${res.md5}${base.digest}'.toMd5(),
      counts: (
        groups: res.counts.groups + base.proxyGroups,
        proxies: res.counts.proxies + base.proxies,
        rules: res.counts.rules + base.rules,
      ),
      base: SetupBase(path: path, overlay: res.yaml),
      tun: res.tun,
    );
  }

  /// Only what the custom profile actually references is injected, so an
  /// app-level provider costs nothing in the profiles that never name it.
  Future<({Map<String, dynamic> proxies, Map<String, dynamic> rules})>
  _resolveInjectedProviders(
    SetupState setupState, {
    required List<ProxyGroup> proxyGroups,
    required List<Rule> rules,
  }) async {
    final usedProxyProviders = <String>{
      for (final proxyGroup in proxyGroups) ...?proxyGroup.use,
    };
    final usedRuleProviders = <String>{
      for (final rule in rules) ...rule.ruleSets,
      if (setupState.profileType == ProfileType.custom)
        ...setupState.overrides.ruleSets,
    };
    if (usedProxyProviders.isEmpty && usedRuleProviders.isEmpty) {
      return (
        proxies: const <String, dynamic>{},
        rules: const <String, dynamic>{},
      );
    }
    final options = setupState.overrides.proxyProviders;
    final proxies = <String, dynamic>{};
    for (final entry in setupState.profileProviders.entries) {
      if (!usedProxyProviders.contains(entry.key)) {
        continue;
      }
      proxies[entry.key] = {
        'type': 'file',
        'path': await appPath.getProfilePath(entry.value.toString()),
        ...?options[entry.key]?.definition,
      };
    }
    final clashProvidersAction = ref.read(
      clashProvidersActionProvider.notifier,
    );
    final ruleProviders = <String, dynamic>{};
    for (final provider in setupState.clashProviders) {
      if (!usedRuleProviders.contains(provider.label)) {
        continue;
      }
      final prepared = await clashProvidersAction.prepare(provider);
      ruleProviders[prepared.label] = prepared.definition(
        await prepared.corePath,
      );
    }
    return (proxies: proxies, rules: ruleProviders);
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return switch (res.base) {
        final base? => await _core.buildProfile(base),
        null => res.yaml,
      };
    } catch (e) {
      dialogs.showNotifier(e.toString(), level: MessageLevel.error);
    }
    return '';
  }

  PatchClashConfig _effectivePatchConfig(PatchClashConfig patchConfig) {
    if (ref.read(safeModeProvider)) {
      return patchConfig.copyWith(
        tun: patchConfig.tun.copyWith(enable: false),
        externalController: ExternalControllerStatus.close,
      );
    }
    final authorized =
        ref.read(authorizedTunEnableProvider) ==
        TunAuthorizationState.authorized;
    return patchConfig.copyWith(
      tun: patchConfig.tun.copyWith(
        enable: patchConfig.tun.enable && authorized,
      ),
      externalController: patchConfig.secret.isEmpty
          ? ExternalControllerStatus.close
          : patchConfig.externalController,
    );
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) async {
    if (!enableTun || ref.read(safeModeProvider)) {
      return true;
    }
    final authorizationState = ref.read(authorizedTunEnableProvider);
    if (authorizationState != TunAuthorizationState.none) {
      return true;
    }

    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    authorizationNotifier.value = TunAuthorizationState.unauthorized;

    final code = await authorizeCore();

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return true;
      case AuthorizeCode.error:
        authorizationNotifier.value = TunAuthorizationState.none;
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: false));
        dialogs.showNotifier(
          currentAppLocalizations.tunAuthorizationFailed,
          level: MessageLevel.error,
        );
        return true;
    }
  }

  /// An empty profile list is left alone: it is the first-run state, and it is
  /// what the profile stream holds before its first emission.
  @visibleForTesting
  Profile? recoverMissingProfile() {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return null;
    final profiles = ref.read(profilesProvider);
    if (profiles.isEmpty) return null;
    final fallback = profiles.first;
    commonPrint.log(
      'profile $profileId is missing, falling back to ${fallback.id}',
      logLevel: LogLevel.warning,
    );
    ref.read(currentProfileIdProvider.notifier).value = fallback.id;
    return fallback;
  }

  Future<_SetupTaskResult> _setupConfig({
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider) ?? recoverMissingProfile();
    // A refresh failure is surfaced by safeRun; setup uses the latest profile.
    if (profile != null) {
      final profileId = profile.id;
      await globalState.safeRun(
        () => ref
            .read(profilesActionProvider.notifier)
            .ensureProfileFile(profileId),
      );
      profile = ref.read(currentProfileProvider) ?? recoverMissingProfile();
    }
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final shouldContinueSetup = await requestAdmin(patchConfig.tun.enable);
    if (!shouldContinueSetup) {
      return _SetupTaskResult.handoffToCoreRestart;
    }
    final realPatchConfig = _effectivePatchConfig(patchConfig);
    final networkSetting = ref.read(networkSettingProvider);
    final tunGeneration = Object();
    final tunIdentity = profileTunIdentity(
      profile,
      patchConfig,
      networkSetting,
    );
    ref.read(builtProfileTunProvider.notifier).value = null;
    var completed = false;
    try {
      SetupState? setupState;
      final realProfile = await globalState.safeRun(() async {
        final state = await ref.read(setupStateProvider(profile?.id).future);
        setupState = state;
        return getProfile(setupState: state, patchConfig: realPatchConfig);
      }, title: 'build profile');
      final profileFailed = realProfile == null;
      final setupParams = _setupParams.copyWith(base: realProfile?.base);
      final inputs = switch (setupState) {
        final state? when !profileFailed => (
          state,
          realPatchConfig,
          networkSetting,
          _appliedParams,
        ),
        _ => null,
      };
      if (realProfile != null) {
        ref.read(builtProfileTunProvider.notifier).value = (
          generation: tunGeneration,
          identity: tunIdentity,
          tun: realProfile.tun,
        );
      }
      final yamlString = realProfile?.yaml ?? '';
      final yamlMd5 = realProfile?.md5 ?? '';
      if (!profileFailed && yamlMd5 == globalState.lastConfigMd5 && !force) {
        _appliedInputs = inputs;
        completed = true;
        return _SetupTaskResult.completed;
      }
      // Go answers a config it rejects by running its built-in default, which
      // has no proxies, so until this push succeeds no applied config is known.
      _appliedInputs = null;
      globalState.lastConfigMd5 = null;
      globalState.lastConfigCounts = null;
      if (system.isMobile) {
        await ref.read(vpnOptionsProvider.future);
        await preferences.saveShareState(ref.read(sharedStateProvider));
      }
      // Recaptured so _start's catch can roll back after safeRun swallows it.
      (Object, StackTrace)? handoffFailure;
      var setupFailed = false;
      await globalState.loadingRun(
        () async {
          try {
            if (setupParams.base == null) {
              final configFilePath = await appPath.configFilePath;
              await File(configFilePath).writeAsStringAtomically(yamlString);
            }
            final profileId = profile?.id;
            if (profileId != null) {
              await appPath.ensureProviderDirs(profileId);
            }
            final message = await _core.setupConfig(
              params: setupParams,
              preloadInvoke: listenerManagedByService ? null : preloadInvoke,
            );
            if (message.isNotEmpty) {
              globalState.lastConfigCounts = configCountsOf(const {});
              await globalState.safeRun(() => onUpdated?.call());
              throw MessageException(message);
            }
            if (listenerManagedByService) {
              await preloadInvoke?.call();
            }
          } catch (e, s) {
            setupFailed = true;
            if (preloadInvoke != null) {
              handoffFailure = (e, s);
            }
            rethrow;
          }
          globalState.lastConfigMd5 = yamlMd5;
          globalState.lastConfigCounts =
              realProfile?.counts ?? configCountsOf(const {});
          _appliedInputs = inputs;
          await onUpdated?.call();
        },
        silence: true,
        tag: !silence ? LoadingTag.proxies : null,
      );
      if (handoffFailure != null) {
        Error.throwWithStackTrace(handoffFailure!.$1, handoffFailure!.$2);
      }
      if (setupFailed || profileFailed) {
        return _SetupTaskResult.failed;
      }
      completed = true;
      return _SetupTaskResult.completed;
    } finally {
      if (!completed &&
          identical(
            ref.read(builtProfileTunProvider)?.generation,
            tunGeneration,
          )) {
        ref.read(builtProfileTunProvider.notifier).value = null;
      }
    }
  }
}
