import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'l10n_labels.dart';
import 'app_ports.dart';
import 'constant.dart';
import 'compute.dart';
import 'string.dart';
import 'keyboard.dart';
import 'provider_reader.dart';
import 'system.dart';
import 'window.dart';

@visibleForTesting
({String? label, TrayMenuItemSublabelStyle style}) getTrayDelayPresentation(
  int? delay, {
  required String loadingLabel,
  required String timeoutLabel,
  String? failureLabel,
  bool testing = false,
}) {
  if (testing) {
    return (label: loadingLabel, style: TrayMenuItemSublabelStyle.muted);
  }
  if (delay == null) {
    return (label: null, style: TrayMenuItemSublabelStyle.badge);
  }
  if (delay < 0) {
    return (
      label: delay == delayTimedOutValue
          ? timeoutLabel
          : failureLabel ?? timeoutLabel,
      style: TrayMenuItemSublabelStyle.destructive,
    );
  }
  return (
    label: '$delay ms',
    style: delay < 600
        ? TrayMenuItemSublabelStyle.badge
        : TrayMenuItemSublabelStyle.warning,
  );
}

@visibleForTesting
String? getTrayGroupSelectionLabel(
  Group group,
  Map<String, String> selectedMap,
) {
  final label = group.getCurrentSelectedName(selectedMap[group.name] ?? '');
  return label.isEmpty ? null : label;
}

String _trayDelayTestKey(String groupName) {
  return 'delay-test:${Uri.encodeComponent(groupName)}';
}

String _trayProxyDelayKey(String groupName, String proxyName) {
  return 'delay:${Uri.encodeComponent(groupName)}:'
      '${Uri.encodeComponent(proxyName)}';
}

class _TrayDelaySnapshot {
  final List<Group> _groups;
  final Map<String, String> _selectedMap;
  final DelayMap _delays;
  final Map<String, DelayTestPhase> _pending;
  final String _defaultTestUrl;
  final Map<String, SelectedProxyState> _selections = {};

  _TrayDelaySnapshot(ProviderReader read)
    : _groups = read(groupsProvider),
      _selectedMap = read(selectedMapProvider),
      _delays = read(delayDataSourceProvider),
      _pending = read(pendingDelayTestsProvider),
      _defaultTestUrl = read(appSettingProvider).testUrl;

  ({String proxyName, String testUrl}) targetFor(
    String proxyName,
    String? testUrl,
  ) {
    final selected = _selections.putIfAbsent(
      proxyName,
      () => computeRealSelectedProxyState(
        proxyName,
        groups: _groups,
        selectedMap: _selectedMap,
      ),
    );
    final effectiveUrl = selected.testUrl.takeFirstValid([
      testUrl,
      _defaultTestUrl,
    ]);
    return (proxyName: selected.proxyName, testUrl: effectiveUrl);
  }

  int? delayFor(String proxyName, String? testUrl) {
    final target = targetFor(proxyName, testUrl);
    return _delays[target.testUrl]?[target.proxyName];
  }

  bool isPending(String proxyName, String? testUrl) {
    final target = targetFor(proxyName, testUrl);
    return _pending.containsKey(delayTestKey(target.testUrl, target.proxyName));
  }

  String selectedNameFor(Group group) {
    final currentGroup = _groups.getGroup(group.name) ?? group;
    return currentGroup.getCurrentSelectedName(_selectedMap[group.name] ?? '');
  }
}

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;

  bool _isShutDown = false;
  final Set<String> _testingGroups = {};
  final Map<String, ({String proxyName, String testUrl, List<String> itemKeys})>
  _delayTargets = {};
  final Map<String, ({String? label, TrayMenuItemSublabelStyle style})>
  _delayPresentations = {};

  AppTray._internal({required this.isMacOS, required this.isWindows});

  factory AppTray() {
    _instance ??= AppTray._internal(
      isMacOS: system.isMacOS,
      isWindows: system.isWindows,
    );
    return _instance!;
  }

  @visibleForTesting
  factory AppTray.forPlatform({
    required bool isMacOS,
    required bool isWindows,
  }) {
    return AppTray._internal(isMacOS: isMacOS, isWindows: isWindows);
  }

  String get _trayIconSuffix {
    return isWindows ? 'ico' : (isMacOS ? 'png' : 'svg');
  }

  String get _trayIconDir {
    if (isWindows) {
      return 'assets/images/tray/windows';
    }
    return isMacOS ? 'assets/images/tray/macos' : 'assets/images/tray/linux';
  }

  String getTrayIcon({
    required bool isStart,
    required bool tunEnable,
    required bool safeMode,
  }) {
    final status = switch ((safeMode, isMacOS || !isStart, tunEnable)) {
      (true, _, _) => 4,
      (false, true, _) => 1,
      (false, false, false) => 2,
      (false, false, true) => 3,
    };
    return '$_trayIconDir/status_$status.$_trayIconSuffix';
  }

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) {
      return;
    }
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(
          getTrayIcon(
            isStart: trayState.isStart,
            tunEnable: trayState.tunEnable,
            safeMode: trayState.safeMode,
          ),
          isTemplate: isMacOS,
          size: isMacOS ? 18 : 16,
        ),
        toolTip: trayState.safeMode
            ? currentAppLocalizations.safeModeAppTitle(appName)
            : appName,
        menu: _buildMenu(trayState: trayState, read: read),
        brightness: read(currentBrightnessProvider),
      ),
    );
    await updateTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(showTrayTitle ? traffic.trayTitle : '');
  }

  List<TrayMenuItem> _buildMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    final commonAction = read(commonActionProvider.notifier);
    final systemAction = read(systemActionProvider.notifier);
    final setupAction = read(setupActionProvider.notifier);
    final appLocalizations = currentAppLocalizations;
    String? shortcut(HotAction action) => _shortcut(trayState, action);
    final showItem = TrayMenuAction(
      label: appLocalizations.show,
      detail: shortcut(HotAction.view),
      onSelectedWithDetails: (details) {
        window?.show(
          activationTimestamp: details.activationTimestamp,
          activationToken: details.activationToken,
        );
      },
    );
    final exitItem = TrayMenuAction(
      label: appLocalizations.exit,
      detail: shortcut(HotAction.exit),
      onSelected: () {
        systemAction.handleExit();
      },
    );

    return [
      showItem,
      TrayMenuCheckbox(
        label: trayState.isStart
            ? appLocalizations.stop
            : appLocalizations.start,
        checked: false,
        detail: shortcut(HotAction.start),
        onSelected: commonAction.toggleRunning,
      ),
      if (isMacOS)
        TrayMenuCheckbox(
          label: appLocalizations.speedStatistics,
          checked: trayState.showTrayTitle,
          onSelected: commonAction.updateSpeedStatistics,
        ),
      const TrayMenuSeparator(),
      for (final mode in Mode.values)
        TrayMenuCheckbox(
          label: mode.label,
          checked: mode == trayState.mode,
          detail: shortcut(switch (mode) {
            Mode.rule => HotAction.ruleMode,
            Mode.global => HotAction.globalMode,
            Mode.direct => HotAction.directMode,
          }),
          onSelected: () {
            setupAction.changeMode(mode);
          },
        ),
      const TrayMenuSeparator(),
      _buildProfileMenu(read),
      const TrayMenuSeparator(),
      ..._buildGroupMenu(trayState: trayState, read: read),
      if (trayState.isStart) ...[
        TrayMenuCheckbox(
          label: appLocalizations.tun,
          checked: trayState.tunEnable,
          detail: shortcut(HotAction.tun),
          onSelected: systemAction.updateTun,
        ),
        TrayMenuCheckbox(
          label: appLocalizations.systemProxy,
          checked: trayState.systemProxy,
          detail: shortcut(HotAction.proxy),
          onSelected: systemAction.updateSystemProxy,
        ),
        const TrayMenuSeparator(),
      ],
      TrayMenuCheckbox(
        label: appLocalizations.autoLaunch,
        checked: trayState.autoLaunch,
        onSelected: systemAction.updateAutoLaunch,
      ),
      TrayMenuAction(
        label: appLocalizations.copyEnvVar,
        detail: shortcut(HotAction.copyEnv),
        onSelected: systemAction.copyProxyEnv,
      ),
      const TrayMenuSeparator(),
      exitItem,
    ];
  }

  String? _shortcut(TrayState trayState, HotAction action) {
    final hotKey = trayState.hotKeys[action];
    final key = hotKey?.key;
    if (hotKey == null || key == null) {
      return null;
    }
    return ShortcutLabels(
      isMacOS: isMacOS,
      isWindows: isWindows,
    ).text(hotKey.modifiers, key);
  }

  String? _delayText(int? delay) {
    if (delay == null) {
      return null;
    }
    return delay >= 0
        ? '$delay'
        : delayFailureText(delay, currentAppLocalizations);
  }

  TrayMenuSubmenu _buildProfileMenu(ProviderReader read) {
    final profiles = read(profilesProvider);
    final currentProfile = read(currentProfileProvider);
    return TrayMenuSubmenu(
      key: 'profiles',
      label: currentAppLocalizations.profile,
      sublabel: currentProfile?.realLabel,
      usesCustomView: isMacOS,
      items: [
        for (final profile in profiles)
          TrayMenuCheckbox(
            key: 'profile:${profile.id}',
            label: profile.realLabel,
            checked: profile.id == currentProfile?.id,
            onSelected: () {
              if (read(profilesProvider).any((item) => item.id == profile.id)) {
                read(currentProfileIdProvider.notifier).value = profile.id;
              }
            },
          ),
        if (profiles.isNotEmpty) const TrayMenuSeparator(),
        TrayMenuAction(
          key: 'profile:update',
          label: currentAppLocalizations.sync,
          enabled:
              currentProfile != null &&
              currentProfile.type != ProfileType.file &&
              !read(isUpdatingProvider(currentProfile.updatingKey)),
          onSelected: () async {
            final profile = read(currentProfileProvider);
            if (profile == null ||
                profile.type == ProfileType.file ||
                read(isUpdatingProvider(profile.updatingKey))) {
              return;
            }
            await globalState.safeRun(() async {
              await read(
                profilesActionProvider.notifier,
              ).updateProfile(profile, showLoading: true);
            });
          },
        ),
      ],
    );
  }

  List<TrayMenuItem> _buildGroupMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    _delayTargets.clear();
    _delayPresentations.clear();
    if (trayState.groups.isEmpty ||
        !read(appSettingProvider).showTrayProxySelection) {
      return const [];
    }
    final delays = _TrayDelaySnapshot(read);
    final selectedNames = {
      for (final group in trayState.groups)
        group.name: delays.selectedNameFor(group),
    };
    final proxiesAction = read(proxiesActionProvider.notifier);
    return [
      for (final group in trayState.groups)
        TrayMenuSubmenu(
          key: 'group:${Uri.encodeComponent(group.name)}',
          label: group.name,
          detail: _delayText(
            delays.delayFor(selectedNames[group.name]!, group.testUrl),
          ),
          sublabel: selectedNames[group.name]!.isEmpty
              ? null
              : selectedNames[group.name],
          usesCustomView: isMacOS,
          items: [
            TrayMenuAction(
              key: _trayDelayTestKey(group.name),
              label: currentAppLocalizations.delayTest,
              enabled: !_testingGroups.contains(group.name),
              keepsMenuOpen: true,
              onSelected: () {
                unawaited(_testGroupDelay(group, read));
              },
            ),
            const TrayMenuSeparator(),
            for (final proxy in group.all)
              _buildProxyMenuItem(
                group: group,
                proxy: proxy,
                selectedName: selectedNames[group.name],
                delays: delays,
                read: read,
              ),
          ],
        ),
      TrayMenuAction(
        label: HotAction.delayTest.label,
        detail: _shortcut(trayState, HotAction.delayTest),
        onSelected: () {
          proxiesAction.delayTestGroups(trayState.groups);
        },
      ),
      const TrayMenuSeparator(),
    ];
  }

  TrayMenuCheckbox _buildProxyMenuItem({
    required Group group,
    required Proxy proxy,
    required String? selectedName,
    required _TrayDelaySnapshot delays,
    required ProviderReader read,
  }) {
    final key = _trayProxyDelayKey(group.name, proxy.name);
    final target = delays.targetFor(proxy.name, group.testUrl);
    final targetKey = delayTestKey(target.testUrl, target.proxyName);
    _delayTargets
        .putIfAbsent(
          targetKey,
          () => (
            proxyName: target.proxyName,
            testUrl: target.testUrl,
            itemKeys: <String>[],
          ),
        )
        .itemKeys
        .add(key);
    final delay = delays.delayFor(proxy.name, group.testUrl);
    final presentation = _delayPresentation(
      delay,
      testing: delays.isPending(proxy.name, group.testUrl),
    );
    _delayPresentations[key] = presentation;
    return TrayMenuCheckbox(
      key: key,
      label: proxy.name,
      detail: _delayText(delay),
      sublabel: presentation.label,
      sublabelStyle: presentation.style,
      usesCustomView: isMacOS,
      checked: selectedName == proxy.name,
      onSelected: () {
        read(
          proxiesActionProvider.notifier,
        ).changeProxy(groupName: group.name, proxyName: proxy.name);
      },
    );
  }

  ({String? label, TrayMenuItemSublabelStyle style}) _delayPresentation(
    int? delay, {
    bool testing = false,
  }) {
    return getTrayDelayPresentation(
      delay,
      loadingLabel: '...',
      timeoutLabel: currentAppLocalizations.timeout,
      failureLabel: currentAppLocalizations.delayFailed,
      testing: testing,
    );
  }

  Future<void> updateDelays({
    required ProviderReader read,
    Set<String>? changedTargets,
  }) async {
    if (_isShutDown || changedTargets?.isEmpty == true) return;
    final delays = read(delayDataSourceProvider);
    final pending = read(pendingDelayTestsProvider);
    final updates = <TrayMenuItemUpdate>[];
    final presentations =
        <String, ({String? label, TrayMenuItemSublabelStyle style})>{};
    for (final changed in changedTargets ?? _delayTargets.keys) {
      final target = _delayTargets[changed];
      if (target == null) continue;
      final delay = delays[target.testUrl]?[target.proxyName];
      final presentation = _delayPresentation(
        delay,
        testing: pending.containsKey(changed),
      );
      for (final key in target.itemKeys) {
        if (_delayPresentations[key] == presentation) continue;
        presentations[key] = presentation;
        updates.add(
          TrayMenuItemUpdate(
            key: key,
            sublabel: presentation.label ?? '',
            sublabelStyle: presentation.style,
          ),
        );
      }
    }
    if (await Tray.instance.updateMenuItems(updates)) {
      _delayPresentations.addAll(presentations);
    }
  }

  Future<void> _testGroupDelay(Group group, ProviderReader read) async {
    if (_isShutDown || !_testingGroups.add(group.name)) return;
    try {
      await Tray.instance.updateMenuItems([
        TrayMenuItemUpdate(key: _trayDelayTestKey(group.name), enabled: false),
      ]);
      await read(
        proxiesActionProvider.notifier,
      ).delayTest(group.all, group.testUrl);
    } finally {
      _testingGroups.remove(group.name);
      if (!_isShutDown) {
        await Tray.instance.updateMenuItems([
          TrayMenuItemUpdate(key: _trayDelayTestKey(group.name), enabled: true),
        ]);
      }
    }
  }
}

final appTray = system.isDesktop ? AppTray() : null;
