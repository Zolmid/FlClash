import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_registration.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'account.dart';
import 'auth.dart';
import 'catalogue.dart';
import 'connect.dart';
import 'notices.dart';
import 'preferences.dart';
import 'plans.dart';
import 'shell.dart';
import 'skin.dart';
import 'help.dart';
import 'kit.dart';

class ZolnitHomePage extends ConsumerStatefulWidget {
  const ZolnitHomePage({super.key, this.skin});

  final ZolnitSkin? skin;

  @override
  ConsumerState<ZolnitHomePage> createState() => _ZolnitHomePageState();
}

class _ZolnitHomePageState extends ConsumerState<ZolnitHomePage>
    with WidgetsBindingObserver {
  int _selected = 0;
  ZolnitAccountTab _accountTab = ZolnitAccountTab.info;
  bool _showingPreferences = false;
  bool _syncing = false;
  bool _syncFailed = false;
  int? _syncGeneration;
  Future<int?>? _syncFlight;
  Future<void>? _refreshFlight;
  Timer? _refreshTimer;
  DateTime? _nextRefresh;
  int _refreshFailures = 0;
  int? _observedGeneration;
  bool _foreground = true;
  late final ZolnitSessionController _session;
  late final ZolnitRegistrationCoordinator _registration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ref.read(zolnitSessionProvider)..addListener(_sessionChanged);
    _registration = ref.read(zolnitRegistrationProvider);
    ref.listenManual(initProvider, (_, ready) {
      if (ready) unawaited(_refreshData(force: true));
    });
    _armRefresh();
    scheduleMicrotask(_sessionChanged);
  }

  DateTime get _now => ref.read(zolnitBundleClockProvider)();

  void _armRefresh() {
    _refreshTimer?.cancel();
    if (_foreground) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_refreshData());
      });
    }
  }

  void _sessionChanged() {
    if (!_session.authenticated) {
      if (_observedGeneration != null) _nextRefresh = null;
      _observedGeneration = null;
      return;
    }
    if (_observedGeneration != _session.api.generation) {
      _observedGeneration = _session.api.generation;
      _nextRefresh = null;
      _refreshFailures = 0;
      scheduleMicrotask(() => unawaited(_refreshData(force: true)));
    }
  }

  Future<void> _refreshData({bool force = false}) {
    if (!mounted || !_foreground) return Future.value();
    if (!_session.authenticated) {
      if (_session.restoreState == ZolnitRestoreState.offline &&
          (force || _nextRefresh?.isAfter(_now) != true)) {
        _refreshFailures = (_refreshFailures + 1).clamp(0, 4);
        _nextRefresh = _now.add(
          Duration(seconds: 15 * (1 << _refreshFailures)),
        );
        return _session.restore();
      }
      return Future.value();
    }
    if (!ref.read(initProvider)) return Future.value();
    if (_refreshFlight case final pending?) return pending;
    if (!force && _nextRefresh?.isAfter(_now) == true) {
      return Future.value();
    }
    final generation = _session.api.generation;
    late final Future<void> work;
    work = () async {
      try {
        await _session.refresh();
        if (!mounted ||
            !_foreground ||
            !_session.authenticated ||
            _session.api.generation != generation) {
          return;
        }
        await Future.wait([_session.refreshBilling(), _sync()]);
        if (!mounted || _session.api.generation != generation) return;
        if (_syncFailed ||
            _session.failure != null ||
            _session.billingFailure != null) {
          _refreshFailures = (_refreshFailures + 1).clamp(0, 4);
        } else {
          _refreshFailures = 0;
        }
        _nextRefresh = _now.add(
          Duration(
            seconds: _refreshFailures == 0 ? 120 : 15 * (1 << _refreshFailures),
          ),
        );
      } finally {
        if (identical(_refreshFlight, work)) _refreshFlight = null;
        if (mounted &&
            _session.authenticated &&
            _session.api.generation != generation) {
          scheduleMicrotask(() => unawaited(_refreshData(force: true)));
        }
      }
    }();
    _refreshFlight = work;
    return work;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _armRefresh();
    if (_foreground) unawaited(_refreshData(force: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _registration.cancel();
    _session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _website([String path = '/']) async {
    final mode = await supportsLaunchMode(LaunchMode.inAppBrowserView)
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;
    await launchUrl(
      Uri.parse('https://link.zolmid.com').replace(fragment: path),
      mode: mode,
    );
  }

  Future<void> _register() async {
    await _registration.start();
  }

  void _openHelp(BuildContext from) {
    unawaited(
      openZolnitPage<void>(
        from,
        ZolnitHelpPage(session: ref.read(zolnitSessionProvider)),
      ),
    );
  }

  Future<int?> _sync() {
    final generation = ref.read(zolnitSessionProvider).api.generation;
    if (_syncGeneration == generation && _syncFlight != null) {
      return _syncFlight!;
    }
    final operation = _performSync(generation);
    _syncFlight = operation;
    return operation;
  }

  Future<int?> _performSync(int generation) async {
    bool current() =>
        mounted &&
        _syncGeneration == generation &&
        ref.read(zolnitSessionProvider).api.generation == generation;
    setState(() {
      _syncGeneration = generation;
      _syncing = true;
      _syncFailed = false;
    });
    try {
      final id = await ref.read(zolnitSyncProfileProvider)();
      return id;
    } catch (_) {
      if (current()) setState(() => _syncFailed = true);
      return null;
    } finally {
      if (current()) {
        _syncFlight = null;
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _signedIn() async {
    final session = ref.read(zolnitSessionProvider);
    await Future.wait([session.refreshBilling(), _sync()]);
  }

  Future<void> _connect() async {
    final session = ref.read(zolnitSessionProvider);
    final generation = session.api.generation;
    var applied = false;
    try {
      applied = await _setConnection(!ref.read(isStartProvider));
    } catch (_) {
      applied = false;
    }
    if (mounted &&
        session.authenticated &&
        session.api.generation == generation &&
        !applied) {
      setState(() => _syncFailed = true);
    }
  }

  Future<bool> _setConnection(bool running) async {
    if (ref.read(safeModeProvider)) return false;
    if (!running) {
      return ref.read(setupActionProvider.notifier).setRunning(false);
    }
    if (ref.read(isStartProvider)) return true;
    final generation = ref.read(zolnitSessionProvider).api.generation;
    var id = await _sync();
    if (mounted &&
        id == null &&
        ref.read(zolnitSessionProvider).api.generation == generation) {
      id = cachedManualZolnitBundleProfile(
        ref.read(profilesProvider),
        ref.read(zolnitSessionProvider),
        enabled: ref.read(zolnitClientBundleTransportProvider),
      )?.id;
    }
    if (!mounted ||
        id == null ||
        ref.read(zolnitSessionProvider).api.generation != generation ||
        !ref.read(zolnitSessionProvider).authenticated) {
      return false;
    }
    ref.read(currentProfileIdProvider.notifier).value = id;
    return ref.read(setupActionProvider.notifier).setRunning(true);
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _accountTab = ZolnitAccountTab.info;
      _showingPreferences = false;
    });
    unawaited(_refreshData());
    if (index == 3) unawaited(ref.read(zolnitSessionProvider).refreshBilling());
    if (index == 2) {
      final session = ref.read(zolnitSessionProvider);
      if (session.checkout.allowStripe &&
          session.api.distribution != 'apple-app-store') {
        unawaited(session.refreshRecurringOptions());
      }
    }
  }

  void _showOrders() {
    setState(() {
      _selected = 3;
      _accountTab = ZolnitAccountTab.orders;
      _showingPreferences = false;
    });
  }

  void _showPreferences() {
    setState(() {
      _selected = 3;
      _showingPreferences = true;
    });
  }

  Future<void> _logout() async {
    final deletion = ref.read(zolnitSessionProvider).logout();
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoRun: false));
    setState(() {
      _selected = 0;
      _accountTab = ZolnitAccountTab.info;
      _showingPreferences = false;
      _syncFailed = false;
      _syncing = false;
      _syncGeneration = null;
    });
    try {
      if (!ref.read(safeModeProvider)) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    } finally {
      await deletion;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(zolnitSessionProvider);
    final brightness = Theme.of(context).brightness;
    final colors =
        seededColorScheme(
          seedColor: const Color(0xff506a7a),
          brightness: brightness,
          style: ColorStyle.soft,
        ).copyWith(
          surface: brightness == Brightness.dark
              ? const Color(0xff151e24)
              : const Color(0xfff3f1eb),
        );
    return ZolnitSkinScope(
      skin: widget.skin ?? ZolnitSkin.host,
      child: Theme(
        data: Theme.of(context)
            .copyWith(
              colorScheme: colors,
              scaffoldBackgroundColor: colors.surface,
            )
            .withAppSurfaces
            .copyWith(scaffoldBackgroundColor: colors.surface),
        child: Builder(
          builder: (context) => Material(
            color: colors.surface,
            child: ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                if (!session.authenticated) {
                  return ZolnitLoginPage(
                    session: session,
                    onSignedIn: _signedIn,
                    openWebsite: () => unawaited(_website()),
                    openRegistration: () => unawaited(_register()),
                    openRecovery: () => unawaited(_website('/forgetpassword')),
                  );
                }
                final text = context.appLocalizations;
                final labels = [
                  text.connection,
                  text.zolnitAllNodes,
                  text.zolnitPlans,
                  text.account,
                ];
                final glyphs = [
                  AppGlyphs.home,
                  AppGlyphs.proxies,
                  AppGlyphs.layers,
                  AppGlyphs.account,
                ];
                final title = _showingPreferences
                    ? text.zolnitPreferences
                    : labels[_selected];
                final name = zolnitDisplayName(session.account, session.usage);
                final page = _showingPreferences
                    ? ZolnitPreferencesPage(
                        key: const ValueKey('zolnit-preferences'),
                        compact: false,
                        openWebsite: () => unawaited(_website()),
                      )
                    : switch (_selected) {
                        0 => ZolnitConnectPage(
                          key: const ValueKey('zolnit-connect'),
                          session: session,
                          compact: false,
                          syncing: _syncing,
                          syncFailed: _syncFailed,
                          connect: _connect,
                          openNodes: () => _select(1),
                          openPlans: () => _select(2),
                        ),
                        1 => ZolnitNodesPage(
                          key: const ValueKey('zolnit-nodes'),
                          session: session,
                          sync: _sync,
                          compact: false,
                        ),
                        2 => ZolnitPlansPage(
                          key: const ValueKey('zolnit-plans'),
                          session: session,
                          onOrderCreated: _showOrders,
                          onManageRenewals: () => _select(3),
                          compact: false,
                        ),
                        _ => ZolnitAccountPage(
                          key: const ValueKey('zolnit-account'),
                          session: session,
                          tab: _accountTab,
                          onTabChanged: (tab) => setState(() {
                            _accountTab = tab;
                            _showingPreferences = false;
                          }),
                          showPlans: () => _select(2),
                          showPreferences: _showPreferences,
                          openHelp: () => _openHelp(context),
                          compact: false,
                          logout: _logout,
                        ),
                      };
                return DisplayFeatureSubScreen(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final layout = ZolnitLayout.fromWidth(width);
                      final body = ZolnitLayoutScope(
                        layout: layout,
                        width: width,
                        child: Column(
                          children: [
                            ZolnitTopBar(
                              compact: !layout.useSidebar,
                              title: title,
                              showBrand: _selected == 0 && !_showingPreferences,
                              initial: name.characters.first,
                              onNotices: () => unawaited(
                                showZolnitNotices(context, session.noticeList),
                              ),
                              onHelp: () => _openHelp(context),
                              onAccount: () => _select(3),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1200,
                                  ),
                                  child: page,
                                ),
                              ),
                            ),
                            if (layout.useBottomNav)
                              SafeArea(
                                top: false,
                                child: NavigationDock(
                                  selectedIndex: _selected,
                                  onSelected: _select,
                                  destinations: [
                                    for (var i = 0; i < labels.length; i++)
                                      NavigationDockDestination(
                                        glyph: glyphs[i],
                                        label: labels[i],
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                      return Row(
                        children: [
                          if (layout.useRail)
                            ZolnitNavRail(
                              labels: labels,
                              glyphs: glyphs,
                              selected: _selected,
                              onSelected: _select,
                            )
                          else if (layout.useSidebar)
                            ZolnitSidebar(
                              labels: labels,
                              glyphs: glyphs,
                              selected: _selected,
                              onSelected: _select,
                              onHelp: () => _openHelp(context),
                              onPreferences: _showPreferences,
                            ),
                          Expanded(
                            key: const ValueKey('zolnit-content'),
                            child: body,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
