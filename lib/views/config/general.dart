import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/on_demand.dart';
import 'package:fl_clash/views/config/user_agents.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'general/port_form.dart';

class LogLevelItem extends ConsumerWidget {
  const LogLevelItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<LogLevel>(
      title: (l) => l.logLevel,
      options: LogLevel.values,
      textBuilder: (logLevel) => logLevel.name,
      selector: patchClashConfigProvider.select((state) => state.logLevel),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(logLevel: value)),
    );
  }
}

class UaItem extends ConsumerWidget {
  const UaItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final globalUa = ref.watch(
      patchClashConfigProvider.select((state) => state.globalUa),
    );
    return ListItem.open(
      title: Text(appLocalizations.userAgent),
      subtitle: Text(globalUa ?? appLocalizations.defaultText),
      widget: const UserAgentsView(),
    );
  }
}

class TestUrlItem extends ConsumerWidget {
  const TestUrlItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final testUrl = ref.watch(
      appSettingProvider.select((state) => state.testUrl),
    );
    return ListItem.input(
      title: Text(appLocalizations.testUrl),
      subtitle: Text(testUrl),
      resetValue: defaultTestUrl,
      dialogTitle: appLocalizations.testUrl,
      value: testUrl,
      maxLength: TextInputLimits.url,
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.testUrl);
        }
        if (!value.isUrl) {
          return appLocalizations.urlTip(appLocalizations.testUrl);
        }
        return null;
      },
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(testUrl: value));
      },
    );
  }
}

class PortItem extends ConsumerWidget {
  const PortItem({super.key});

  Future<void> handleShowPortForm(BuildContext context) async {
    await showFormSheet<void>(
      context: context,
      builder: (_) => const _PortForm(),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return ListItem(
      title: Text(appLocalizations.port),
      subtitle: Text('$mixedPort'),
      onTap: () {
        handleShowPortForm(context);
      },
    );
  }
}

class HostsItem extends ConsumerWidget {
  const HostsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final hosts = ref.watch(
      patchClashConfigProvider.select((state) => state.hosts),
    );
    return ListItem.open(
      title: const Text('Hosts'),
      subtitle: Text(
        hosts.isEmpty
            ? appLocalizations.none
            : appLocalizations.itemsCount(hosts.length),
      ),
      widget: MapEditView(
        title: 'Hosts',
        entries: hosts,
        keyMaxLength: TextInputLimits.domain,
        valueMaxLength: TextInputLimits.hostValue,
        titleBuilder: (item) => Text(item.key),
        subtitleBuilder: (item) => Text(item.value),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(hosts: value));
      },
    );
  }
}

class AuthenticationItem extends ConsumerWidget {
  const AuthenticationItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigToggleItem(
      title: (l) => l.authentication,
      selector: networkSettingProvider.select(
        (state) => state.authentication.enable,
      ),
      onChanged: (ref, value) =>
          ref.read(networkSettingProvider.notifier).update((state) {
            var authentication = state.authentication.copyWith(enable: value);
            if (value && authentication.username.isEmpty) {
              authentication = authentication.copyWith(
                username: generateRandomSecret(8),
                password: generateRandomSecret(16),
              );
            }
            return state.copyWith(authentication: authentication);
          }),
    );
  }
}

class AuthenticationAccountItem extends ConsumerWidget {
  const AuthenticationAccountItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.account,
      maxLength: TextInputLimits.userName,
      selector: networkSettingProvider.select(
        (state) => state.authentication.username,
      ),
      // mihomo and the Dart proxy string both split user:pass on the first
      // colon, so a colon in the username breaks authentication.
      normalize: (value) => value.trim().replaceAll(':', ''),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(username: value)),
    );
  }
}

class AuthenticationPasswordItem extends ConsumerWidget {
  const AuthenticationPasswordItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.password,
      maxLength: TextInputLimits.password,
      selector: networkSettingProvider.select(
        (state) => state.authentication.password,
      ),
      normalize: (value) => value.trim(),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(password: value)),
    );
  }
}

class ExternalControllerSecretItem extends ConsumerWidget {
  const ExternalControllerSecretItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.externalControllerSecret,
      maxLength: TextInputLimits.password,
      selector: patchClashConfigProvider.select((state) => state.secret),
      normalize: (value) => value.trim(),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(secret: value)),
    );
  }
}

ConfigToggleItem _clashToggle({
  required ConfigLabel title,
  required bool Function(PatchClashConfig state) select,
  required PatchClashConfig Function(PatchClashConfig state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: patchClashConfigProvider.select(select),
    onChanged: (ref, value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => update(state, value)),
  );
}

ConfigToggleItem _appSettingToggle({
  required ConfigLabel title,
  required bool Function(AppSettingProps state) select,
  required AppSettingProps Function(AppSettingProps state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: appSettingProvider.select(select),
    onChanged: (ref, value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => update(state, value)),
  );
}

class GeneralView extends ConsumerWidget {
  const GeneralView({super.key, this.platform});

  final SupportPlatform? platform;

  SupportPlatform get _platform => platform ?? SupportPlatform.currentPlatform;

  bool get _isIOS => _platform == SupportPlatform.IOS;

  bool get _isAndroid => _platform == SupportPlatform.Android;

  bool get _isDesktop => desktopPlatforms.contains(_platform);

  List<Widget> _startupItems(AppLocalizations appLocalizations) {
    return [
      if (_isDesktop) ...[
        _appSettingToggle(
          title: (l) => l.autoLaunch,
          select: (state) => state.autoLaunch,
          update: (state, value) => state.copyWith(autoLaunch: value),
        ),
        if (_platform == SupportPlatform.Windows)
          _appSettingToggle(
            title: (l) => l.highPriorityAutoLaunch,
            select: (state) => state.highPriorityAutoLaunch,
            update: (state, value) =>
                state.copyWith(highPriorityAutoLaunch: value),
          ),
        _appSettingToggle(
          title: (l) => l.silentLaunch,
          select: (state) => state.silentLaunch,
          update: (state, value) => state.copyWith(silentLaunch: value),
        ),
      ],
      _appSettingToggle(
        title: (l) => l.autoRun,
        select: (state) => state.autoRun,
        update: (state, value) => state.copyWith(autoRun: value),
      ),
      ListItem.open(
        title: Text(appLocalizations.onDemand),
        widget: const OnDemandView(),
      ),
      if (!_isIOS)
        _appSettingToggle(
          title: (l) => l.minimizeOnExit,
          select: (state) => state.minimizeOnExit,
          update: (state, value) => state.copyWith(minimizeOnExit: value),
        ),
      _appSettingToggle(
        title: (l) => l.backToDashboard,
        select: (state) => state.backToDashboard,
        update: (state, value) => state.copyWith(backToDashboard: value),
      ),
      _appSettingToggle(
        title: (l) => l.tvMode,
        select: (state) => state.tvMode,
        update: (state, value) => state.copyWith(tvMode: value),
      ),
      if (_isAndroid || _isIOS)
        _appSettingToggle(
          title: (l) => l.showQuickSettingsProfileName,
          select: (state) => state.showQuickSettingsProfileName,
          update: (state, value) =>
              state.copyWith(showQuickSettingsProfileName: value),
        ),
      if (_isAndroid) ...[
        ConfigToggleItem(
          title: (l) => l.networkSpeedNotification,
          selector: vpnSettingProvider.select(
            (state) => state.networkSpeedNotification,
          ),
          onChanged: (ref, value) => ref
              .read(vpnSettingProvider.notifier)
              .update(
                (state) => state.copyWith(networkSpeedNotification: value),
              ),
        ),
        _appSettingToggle(
          title: (l) => l.collapseQuickSettingsPanel,
          select: (state) => state.collapseQuickSettingsPanel,
          update: (state, value) =>
              state.copyWith(collapseQuickSettingsPanel: value),
        ),
        _appSettingToggle(
          title: (l) => l.exclude,
          select: (state) => state.hidden,
          update: (state, value) => state.copyWith(hidden: value),
        ),
        _appSettingToggle(
          title: (l) => l.showNotificationStopAction,
          select: (state) => state.showNotificationStopAction,
          update: (state, value) =>
              state.copyWith(showNotificationStopAction: value),
        ),
      ],
    ];
  }

  List<Widget> _inboundItems({
    required bool authentication,
    required bool externalController,
  }) {
    return [
      const PortItem(),
      _clashToggle(
        title: (l) => l.allowLan,
        select: (state) => state.allowLan,
        update: (state, value) => state.copyWith(allowLan: value),
      ),
      _clashToggle(
        title: (l) => l.externalController,
        select: (state) =>
            state.externalController == ExternalControllerStatus.open,
        update: (state, value) => state
            .copyWith(
              externalController: value
                  ? ExternalControllerStatus.open
                  : ExternalControllerStatus.close,
            )
            .ensureControllerSecret(),
      ),
      if (externalController) const ExternalControllerSecretItem(),
      const AuthenticationItem(),
      if (authentication) ...const [
        AuthenticationAccountItem(),
        AuthenticationPasswordItem(),
      ],
    ];
  }

  List<Widget> _connectionItems() {
    return [
      const TestUrlItem(),
      _clashToggle(
        title: (l) => l.unifiedDelay,
        select: (state) => state.unifiedDelay,
        update: (state, value) => state.copyWith(unifiedDelay: value),
      ),
      _clashToggle(
        title: (l) => l.tcpConcurrent,
        select: (state) => state.tcpConcurrent,
        update: (state, value) => state.copyWith(tcpConcurrent: value),
      ),
      if (!_isIOS)
        _clashToggle(
          title: (l) => l.findProcessMode,
          select: (state) => state.findProcessMode == FindProcessMode.always,
          update: (state, value) => state.copyWith(
            findProcessMode: value
                ? FindProcessMode.always
                : FindProcessMode.off,
          ),
        ),
      _appSettingToggle(
        title: (l) => l.collapseProxyChains,
        select: (state) => state.collapseProxyChains,
        update: (state, value) => state.copyWith(collapseProxyChains: value),
      ),
      _appSettingToggle(
        title: (l) => l.autoCloseConnections,
        select: (state) => state.closeConnections,
        update: (state, value) => state.copyWith(closeConnections: value),
      ),
      _appSettingToggle(
        title: (l) => l.promptCloseConnections,
        select: (state) => state.promptCloseConnections,
        update: (state, value) => state.copyWith(promptCloseConnections: value),
      ),
      _appSettingToggle(
        title: (l) => l.onlyStatisticsProxy,
        select: (state) => state.onlyStatisticsProxy,
        update: (state, value) => state.copyWith(onlyStatisticsProxy: value),
      ),
    ];
  }

  List<Widget> _requestItems() {
    return [
      const UaItem(),
      _appSettingToggle(
        title: (l) => l.checkCertificate,
        select: (state) => state.checkCertificate,
        update: (state, value) => state.copyWith(checkCertificate: value),
      ),
      if (!_isIOS)
        _appSettingToggle(
          title: (l) => l.autoCheckUpdate,
          select: (state) => state.autoCheckUpdate,
          update: (state, value) => state.copyWith(autoCheckUpdate: value),
        ),
    ];
  }

  List<Widget> _coreItems() {
    return [
      _clashToggle(
        title: (l) => 'IPv6',
        select: (state) => state.ipv6,
        update: (state, value) => state.copyWith(ipv6: value),
      ),
      const HostsItem(),
      if (!_isIOS)
        ConfigToggleItem(
          title: (l) => l.appendSystemDns,
          selector: networkSettingProvider.select(
            (state) => state.appendSystemDns,
          ),
          onChanged: (ref, value) => ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(appendSystemDns: value)),
        ),
      _clashToggle(
        title: (l) => l.geodataLoader,
        select: (state) => state.geodataLoader == GeodataLoader.memconservative,
        update: (state, value) => state.copyWith(
          geodataLoader: value
              ? GeodataLoader.memconservative
              : GeodataLoader.standard,
        ),
      ),
    ];
  }

  List<Widget> _logItems() {
    return [
      const _ForegroundTickerIntervalItem(),
      const LogLevelItem(),
      _appSettingToggle(
        title: (l) => l.logcat,
        select: (state) => state.openLogs,
        update: (state, value) => state.copyWith(openLogs: value),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final authentication = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    final externalController = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.externalController == ExternalControllerStatus.open,
      ),
    );
    return BaseScaffold(
      title: appLocalizations.general,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.appBarInset, bottom: 16),
        children: [
          generateSection(
            title: appLocalizations.startupAndBackground,
            items: _startupItems(appLocalizations),
            footer: [
              if (_isDesktop) appLocalizations.silentLaunchDesc,
              if (_platform == SupportPlatform.Windows)
                appLocalizations.highPriorityAutoLaunchDesc,
              appLocalizations.autoRunDesc,
              appLocalizations.onDemandDesc,
            ].join('\n'),
          ),
          generateSection(
            title: appLocalizations.requestsAndUpdates,
            items: _requestItems(),
            footer: appLocalizations.checkCertificateDesc,
          ),
          generateSection(
            title: appLocalizations.inbound,
            items: _inboundItems(
              authentication: authentication,
              externalController: externalController,
            ),
            footer: [
              appLocalizations.externalControllerDesc,
              appLocalizations.authenticationDesc,
            ].join('\n'),
          ),
          generateSection(
            title: appLocalizations.connection,
            items: _connectionItems(),
            footer: appLocalizations.autoCloseConnectionsDesc,
          ),
          generateSection(
            title: appLocalizations.core,
            items: _coreItems(),
            footer: appLocalizations.ipv6Desc,
          ),
          generateSection(
            title: appLocalizations.logsAndDiagnostics,
            items: _logItems(),
            footer: appLocalizations.logcatDesc,
          ),
        ],
      ),
    );
  }
}

class _ForegroundTickerIntervalItem extends ConsumerWidget {
  const _ForegroundTickerIntervalItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(
      appSettingProvider.select(
        (state) => (
          state.foregroundTickerInterval,
          state.foregroundTickerIdleWhenUnfocused,
          state.foregroundTickerIdleInterval,
        ),
      ),
    );
    final l = context.appLocalizations;
    final interval = '${setting.$1} ${l.seconds}';
    final idleInterval = '${setting.$3} ${l.seconds}';
    return ListItem(
      title: Text(l.uiUpdateInterval),
      subtitle: Text(
        setting.$2
            ? l.uiUpdateIntervalDesc(interval, idleInterval)
            : l.uiUpdateIntervalIdleDisabledDesc(interval),
      ),
      onTap: () => dialogs.showCommonDialog<void>(
        child: const _ForegroundTickerIntervalDialog(),
      ),
    );
  }
}

class _ForegroundTickerIntervalDialog extends ConsumerStatefulWidget {
  const _ForegroundTickerIntervalDialog();

  @override
  ConsumerState<_ForegroundTickerIntervalDialog> createState() =>
      _ForegroundTickerIntervalDialogState();
}

class _ForegroundTickerIntervalDialogState
    extends ConsumerState<_ForegroundTickerIntervalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _intervalController;
  late final TextEditingController _idleIntervalController;
  late bool _idleWhenUnfocused;

  @override
  void initState() {
    super.initState();
    final setting = ref.read(appSettingProvider);
    _intervalController = TextEditingController(
      text: setting.foregroundTickerInterval.toString(),
    );
    _idleIntervalController = TextEditingController(
      text: setting.foregroundTickerIdleInterval.toString(),
    );
    _idleWhenUnfocused = setting.foregroundTickerIdleWhenUnfocused;
  }

  String? _validateSeconds(String? value) {
    final l = context.appLocalizations;
    if (value == null || value.isEmpty) return l.emptyTip(l.interval);
    if (int.tryParse(value) == null) return l.numberTip(l.interval);
    return int.parse(value) > 0 ? null : l.positiveIntegerTip;
  }

  void _reset() {
    setState(() {
      _intervalController.text = (const AppSettingProps())
          .foregroundTickerInterval
          .toString();
      _idleIntervalController.text = (const AppSettingProps())
          .foregroundTickerIdleInterval
          .toString();
      _idleWhenUnfocused = true;
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() == false) return;
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            foregroundTickerInterval: int.parse(_intervalController.text),
            foregroundTickerIdleWhenUnfocused: _idleWhenUnfocused,
            foregroundTickerIdleInterval: _idleWhenUnfocused
                ? int.parse(_idleIntervalController.text)
                : state.foregroundTickerIdleInterval,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _idleIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return CommonDialog(
      title: l.uiUpdateInterval,
      actions: [
        TextButton(onPressed: _reset, child: Text(l.reset)),
        TextButton(onPressed: _submit, child: Text(l.submit)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            TextFormField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.uiUpdateInterval,
                suffixText: l.seconds,
              ),
              validator: _validateSeconds,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.uiUpdateIdleWhenUnfocused),
              subtitle: Text(l.uiUpdateIdleWhenUnfocusedDesc),
              value: _idleWhenUnfocused,
              onChanged: (value) => setState(() => _idleWhenUnfocused = value),
            ),
            AnimatedSize(
              duration: midDuration,
              curve: Curves.easeOutQuad,
              alignment: Alignment.topCenter,
              child: _idleWhenUnfocused
                  ? TextFormField(
                      controller: _idleIntervalController,
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l.uiUpdateIdleInterval,
                        suffixText: l.seconds,
                      ),
                      validator: _validateSeconds,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
