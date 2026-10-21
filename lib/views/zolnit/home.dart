import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'account.dart';
import 'auth.dart';
import 'brand.dart';
import 'catalogue.dart';
import 'data.dart';

class ZolnitHomePage extends ConsumerStatefulWidget {
  const ZolnitHomePage({super.key});

  @override
  ConsumerState<ZolnitHomePage> createState() => _ZolnitHomePageState();
}

class _ZolnitHomePageState extends ConsumerState<ZolnitHomePage> {
  int _selected = 0;
  bool _orders = false;
  bool _syncing = false;
  bool _synced = false;
  bool _syncFailed = false;
  int? _syncGeneration;

  Future<void> _website() async {
    await launchUrl(
      Uri.parse('https://link.zolmid.com'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<int?> _sync() async {
    final generation = ref.read(zolnitSessionProvider).api.generation;
    if (_syncing && _syncGeneration == generation) return null;
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
      if (current()) setState(() => _synced = id != null);
      return id;
    } catch (_) {
      if (current()) setState(() => _syncFailed = true);
      return null;
    } finally {
      if (current()) setState(() => _syncing = false);
    }
  }

  Future<void> _signedIn() async {
    final session = ref.read(zolnitSessionProvider);
    await Future.wait([session.refreshBilling(), _sync()]);
  }

  Future<void> _refresh() async {
    final session = ref.read(zolnitSessionProvider);
    await session.refresh();
    if (session.authenticated) await _signedIn();
  }

  Future<void> _connect() async {
    if (ref.read(safeModeProvider)) return;
    if (ref.read(coreStatusProvider) == CoreStatus.connected) {
      ref.read(commonActionProvider.notifier).toggleRunning();
      return;
    }
    final id = await _sync();
    if (!mounted ||
        id == null ||
        !ref.read(zolnitSessionProvider).authenticated) {
      return;
    }
    ref.read(currentProfileIdProvider.notifier).value = id;
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _orders = false;
    });
    if (index == 3) unawaited(ref.read(zolnitSessionProvider).refreshBilling());
    if (index == 2) {
      unawaited(ref.read(zolnitSessionProvider).refreshRecurringOptions());
    }
  }

  void _showOrders() {
    setState(() {
      _selected = 3;
      _orders = true;
    });
  }

  void _logout() {
    setState(() {
      _selected = 0;
      _orders = false;
      _synced = false;
      _syncFailed = false;
      _syncing = false;
      _syncGeneration = null;
    });
    ref.read(zolnitSessionProvider).logout();
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
    return Theme(
      data: Theme.of(context)
          .copyWith(
            colorScheme: colors,
            scaffoldBackgroundColor: colors.surface,
          )
          .withAppSurfaces,
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
                );
              }
              final text = context.appLocalizations;
              final labels = [
                text.connection,
                text.nodes,
                text.zolnitPlans,
                text.account,
              ];
              final glyphs = [
                AppGlyphs.dashboard,
                AppGlyphs.proxies,
                AppGlyphs.profiles,
                AppGlyphs.account,
              ];
              final title = _orders ? text.zolnitOrders : labels[_selected];
              final page = _orders
                  ? ZolnitOrdersPage(session: session)
                  : switch (_selected) {
                      0 => _Dashboard(
                        session: session,
                        syncing: _syncing,
                        synced: _synced,
                        syncFailed: _syncFailed,
                        sync: _sync,
                        connect: _connect,
                      ),
                      1 => ZolnitNodesPage(session: session, sync: _sync),
                      2 => ZolnitPlansPage(
                        session: session,
                        onOrderCreated: _showOrders,
                      ),
                      _ => ZolnitAccountPage(
                        session: session,
                        showOrders: _showOrders,
                        logout: _logout,
                      ),
                    };
              return LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 760;
                  final content = Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextStyle.pageTitle.of(context),
                              ),
                            ),
                            IconButton(
                              tooltip: text.zolnitRefresh,
                              onPressed: session.busy || _syncing
                                  ? null
                                  : _refresh,
                              icon: const GlyphIcon(AppGlyphs.refresh),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: page),
                      if (!desktop)
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
                  );
                  if (!desktop) return content;
                  return Row(
                    children: [
                      SizedBox(
                        width: 228,
                        child: ColoredBox(
                          color: colors.chromeSurface,
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 24, 16, 20),
                                child: ZolnitBrand(),
                              ),
                              Expanded(
                                child: NavigationSidebar(
                                  expanded: true,
                                  selectedIndex: _selected,
                                  onSelected: _select,
                                  destinations: [
                                    for (var i = 0; i < labels.length; i++)
                                      SidebarDestination(
                                        glyph: glyphs[i],
                                        label: labels[i],
                                      ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => unawaited(_website()),
                                child: Text(text.zolnitWebsite),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const HomePage(),
                                  ),
                                ),
                                child: Text(text.zolnitAdvanced),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({
    required this.session,
    required this.syncing,
    required this.synced,
    required this.syncFailed,
    required this.sync,
    required this.connect,
  });

  final ZolnitSessionController session;
  final bool syncing;
  final bool synced;
  final bool syncFailed;
  final Future<int?> Function() sync;
  final Future<void> Function() connect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final subscription = session.subscription;
    final plan = subscription?['plan'];
    final uploaded = subscription?['u'];
    final downloaded = subscription?['d'];
    final used =
        (uploaded is num ? uploaded : 0) + (downloaded is num ? downloaded : 0);
    final status = ref.watch(coreStatusProvider);
    final safe = ref.watch(safeModeProvider);
    final label = switch (status) {
      CoreStatus.connected => text.connected,
      CoreStatus.connecting => text.connecting,
      _ => text.disconnected,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ZolnitPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.zolnitTagline, style: AppTextStyle.title1.of(context)),
              const SizedBox(height: 24),
              Text(label, style: AppTextStyle.headline.of(context)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    safe ||
                        syncing ||
                        status == CoreStatus.connecting ||
                        session.nodes.isEmpty
                    ? null
                    : connect,
                icon: const GlyphIcon(AppGlyphs.vpn, fill: 1),
                label: Text(label),
              ),
              const SizedBox(height: 12),
              Text(text.zolnitProfileSource),
              if (session.nodes.isEmpty) Text(text.zolnitNoNodes),
              const SizedBox(height: 12),
              TextButton(
                onPressed: syncing || session.busy ? null : sync,
                child: Text(
                  syncing
                      ? text.zolnitSyncing
                      : synced
                      ? text.zolnitSynced
                      : text.zolnitSync,
                ),
              ),
              ZolnitFailureMessage(
                code: syncFailed ? 'profile_sync_failed' : session.failure,
                serverMessage: syncFailed ? null : session.failureMessage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ZolnitPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan is Json && plan['name'] is String
                    ? plan['name'] as String
                    : text.zolnitNoPlan,
                style: AppTextStyle.title2.of(context),
              ),
              ZolnitValue(
                label: text.trafficUsage,
                value:
                    '${zolnitBytes(used)} / ${zolnitBytes(subscription?['transfer_enable'])}',
              ),
              ZolnitValue(
                label: text.subscriptionInfo,
                value: zolnitDate(subscription?['expired_at']),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
