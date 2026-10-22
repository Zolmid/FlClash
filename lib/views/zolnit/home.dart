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

import 'account.dart';
import 'auth.dart';
import 'catalogue.dart';
import 'connect.dart';
import 'notices.dart';
import 'shell.dart';
import 'skin.dart';

class ZolnitHomePage extends ConsumerStatefulWidget {
  const ZolnitHomePage({super.key, this.skin});

  final ZolnitSkin? skin;

  @override
  ConsumerState<ZolnitHomePage> createState() => _ZolnitHomePageState();
}

class _ZolnitHomePageState extends ConsumerState<ZolnitHomePage> {
  int _selected = 0;
  bool _orders = false;
  bool _syncing = false;
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
    return ZolnitSkinScope(
      skin: widget.skin ?? ZolnitSkin.host,
      child: Theme(
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
                  AppGlyphs.home,
                  AppGlyphs.proxies,
                  AppGlyphs.layers,
                  AppGlyphs.account,
                ];
                final title = _orders ? text.zolnitOrders : labels[_selected];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 760;
                    final page = _orders
                        ? ZolnitOrdersPage(session: session)
                        : switch (_selected) {
                            0 => ZolnitConnectPage(
                              session: session,
                              compact: !desktop,
                              syncing: _syncing,
                              syncFailed: _syncFailed,
                              connect: _connect,
                              openNodes: () => _select(1),
                              openPlans: () => _select(2),
                              openNotice: (notice) =>
                                  unawaited(showZolnitNotice(context, notice)),
                              openNotices: () => unawaited(
                                showZolnitNotices(context, session.noticeList),
                              ),
                            ),
                            1 => ZolnitNodesPage(session: session, sync: _sync),
                            2 => ZolnitPlansPage(
                              session: session,
                              onOrderCreated: _showOrders,
                              compact: !desktop,
                            ),
                            _ => ZolnitAccountPage(
                              session: session,
                              showOrders: _showOrders,
                              logout: _logout,
                            ),
                          };
                    final name = zolnitDisplayName(
                      session.account,
                      session.usage,
                    );
                    final content = Column(
                      children: [
                        ZolnitTopBar(
                          compact: !desktop,
                          title: title,
                          showBrand:
                              (_selected == 0 || _selected == 2) && !_orders,
                          initial: name.characters.first,
                          busy: session.busy || _syncing,
                          onRefresh: _refresh,
                          onNotices: () => unawaited(
                            showZolnitNotices(context, session.noticeList),
                          ),
                          onHelp: () => unawaited(_website()),
                          onAccount: () => _select(3),
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
                        ZolnitSidebar(
                          labels: labels,
                          glyphs: glyphs,
                          selected: _selected,
                          onSelected: _select,
                          onHelp: () => unawaited(_website()),
                          onPreferences: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const HomePage(),
                            ),
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
