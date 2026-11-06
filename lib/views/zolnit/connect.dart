import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_connection.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'connect_art.dart';
import 'data.dart';
import 'kit.dart';
import 'motion.dart';
import 'node_groups.dart';
import 'nodes.dart' show zolnitProfileIsCurrent;
import 'notices.dart' show showZolnitNotice;
import 'skin.dart';

String zolnitDisplayName(Json? account, ZolnitUsage? usage) {
  final raw = account?['email'];
  final email = raw is String && raw.isNotEmpty ? raw : usage?.email ?? '';
  final local = email.split('@').first.trim();
  if (local.isEmpty) return 'ZolNit';
  final word = local
      .split(RegExp(r'[._+\-]'))
      .firstWhere((part) => part.isNotEmpty, orElse: () => local);
  final letters = word.characters;
  return letters.first.toUpperCase() + letters.skip(1).string;
}

class ZolnitConnectPage extends ConsumerWidget {
  const ZolnitConnectPage({
    super.key,
    required this.session,
    required this.compact,
    required this.syncing,
    required this.syncFailed,
    required this.connect,
    required this.openNodes,
    required this.openPlans,
  });

  final ZolnitSessionController session;
  final bool compact;
  final bool syncing;
  final bool syncFailed;
  final Future<void> Function() connect;
  final VoidCallback openNodes;
  final VoidCallback openPlans;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = ZolnitLayoutScope.of(context);
      return _layout(
        context,
        viewportHeight: constraints.maxHeight,
        stacked: constraints.maxWidth < 740,
        layout: layout,
      );
    },
  );

  Widget _layout(
    BuildContext context, {
    required bool stacked,
    required double viewportHeight,
    required ZolnitLayout layout,
  }) {
    final skin = ZolnitSkin.of(context);
    final usage = session.usage;
    final padding = zolnitPagePadding(
      skin,
      compact: layout == ZolnitLayout.compact,
    );
    final minimumHeight =
        stacked && layout == ZolnitLayout.compact && viewportHeight.isFinite
        ? (viewportHeight - padding.vertical - 280).clamp(0.0, 310.0)
        : 220.0;
    final connection = _ConnectPanel(
      session: session,
      stacked: stacked,
      syncing: syncing,
      syncFailed: syncFailed,
      connect: connect,
      openNodes: openNodes,
      minimumHeight: minimumHeight,
    );
    final options = _ConnectionOptions(
      session: session,
      syncing: syncing,
      stacked: true,
      openNodes: openNodes,
    );
    final plan = _PlanStrip(usage: usage, onPlans: openPlans);
    if (!stacked) {
      final notice = session.noticeList.firstOrNull;
      return ListView(
        padding: padding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    connection,
                    if (session.nodeList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DashboardServers(session: session, openNodes: openNodes),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    options,
                    const SizedBox(height: 12),
                    plan,
                    if (notice != null) ...[
                      const SizedBox(height: 12),
                      _LatestNotice(notice: notice),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: padding,
      children: [
        connection,
        const SizedBox(height: 12),
        options,
        const SizedBox(height: 12),
        plan,
      ],
    );
  }
}

/// The plan's servers by measured latency, so a wide window shows where the
/// connection can go without opening the server list.
class _DashboardServers extends ConsumerWidget {
  const _DashboardServers({required this.session, required this.openNodes});

  final ZolnitSessionController session;
  final VoidCallback openNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final nodes = session.nodeList;
    final current = zolnitProfileIsCurrent(ref, session, watch: true);
    final delays = current
        ? ref.watch(delayDataSourceProvider)[ref.watch(realTestUrlProvider())]
        : null;
    int rank(ZolnitNode node) => switch (delays?[node.proxyName]) {
      final int delay when delay > 0 => delay,
      _ => 1 << 30,
    };
    final shown = [...nodes]..sort((a, b) => rank(a).compareTo(rank(b)));
    return ZolnitCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZolnitSectionHeading(
            title: text.zolnitAllNodes,
            subtitle: text.zolnitNodesSortedByLatency,
            actionLabel: text.zolnitNodesCount(nodes.length),
            onAction: openNodes,
          ),
          const SizedBox(height: 8),
          for (final node in shown.take(4))
            _ServerRow(
              node: node,
              delay: delays?[node.proxyName],
              onTap: openNodes,
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.node,
    required this.delay,
    required this.onTap,
    required this.colors,
  });

  final ZolnitNode node;
  final int? delay;
  final VoidCallback onTap;
  final ZolnitColors colors;

  @override
  Widget build(BuildContext context) {
    final shown = zolnitNodePresentation(node);
    final delay = this.delay;
    final label = delay == null || delay == 0
        ? '—'
        : delay > 0
        ? '$delay ms'
        : delayFailureText(delay, context.appLocalizations);
    final tint = delay == null || delay == 0
        ? colors.muted
        : context.colorScheme.delayColor(delay) ?? colors.muted;
    return InkWell(
      customBorder: AppShape.sm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ZolnitFlagBadge(flag: shown.flag, label: shown.region, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shown.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: zolnitText(context, 13, weight: FontWeight.w600),
                  ),
                  if (shown.region.isNotEmpty)
                    Text(
                      shown.region,
                      style: zolnitText(context, 11, color: colors.muted),
                    ),
                ],
              ),
            ),
            Text(
              label,
              style: zolnitText(
                context,
                12,
                weight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestNotice extends StatelessWidget {
  const _LatestNotice({required this.notice});

  final ZolnitNotice notice;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    return ZolnitCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZolnitSectionHeading(
            title: text.zolnitNotices,
            subtitle: notice.createdAt == null
                ? null
                : zolnitDotDate(notice.createdAt!),
            onAction: () => unawaited(showZolnitNotice(context, notice)),
          ),
          const SizedBox(height: 10),
          Text(
            notice.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: zolnitText(context, 14, weight: FontWeight.w600),
          ),
          if (notice.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notice.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: zolnitText(context, 12, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

final _routeMetadataProvider = FutureProvider.autoDispose
    .family<ZolnitRouteMetadata, ZolnitClientBundle>(
      (ref, bundle) => loadZolnitRouteMetadata(bundle),
    );

class _Selection {
  const _Selection(this.node, {required this.chosen, this.title});

  final ZolnitNode? node;
  final bool chosen;
  final String? title;
}

_Selection _selectionOf(
  WidgetRef ref,
  ZolnitSessionController session,
  List<ZolnitNode> nodes,
) {
  final bundle = session.clientBundle;
  final profile = ref.watch(currentProfileProvider);
  if (bundle != null &&
      (profile == null ||
          !isCurrentZolnitBundleProfile(profile, session) ||
          profile.zolnitBundleId != bundle.bundleId)) {
    return _Selection(nodes.firstOrNull, chosen: false);
  }
  final allGroups = ref.watch(groupsProvider);
  final metadata = bundle == null
      ? null
      : ref.watch(_routeMetadataProvider(bundle)).value;
  final mode = ref.watch(patchClashConfigProvider).mode;
  if (mode == Mode.direct) return const _Selection(null, chosen: false);
  final group = bundle == null
      ? ref.watch(currentGroupsStateProvider).value.firstOrNull?.name
      : metadata == null ||
            !bundle.isFresh(ref.read(zolnitBundleClockProvider)())
      ? null
      : zolnitNodesGroup(metadata, allGroups, mode)?.name;
  final live =
      !ref.watch(safeModeProvider) &&
      ref.watch(coreStatusProvider) == CoreStatus.connected;
  String? choice(String name) => bundle == null
      ? ref.watch(selectedProxyNameProvider(name))
      : live
      ? allGroups.where((g) => g.name == name).firstOrNull?.now
      : ref.watch(selectedMapProvider.select((map) => map[name]));
  var selected = group == null ? null : choice(group);
  final visited = <String>{};
  while (selected != null && selected.isNotEmpty && visited.add(selected)) {
    final node = nodes.where((n) => n.proxyName == selected).firstOrNull;
    if (node != null) {
      final title = metadata == null
          ? null
          : groupZolnitRoutes(
              nodes,
              hosts: metadata.hosts,
              paths: metadata.paths,
              exitIds: bundle!.exitIds,
            ).where((entry) => entry.contains(selected)).firstOrNull?.title;
      return _Selection(node, chosen: true, title: title);
    }
    selected = choice(selected);
  }
  return _Selection(nodes.firstOrNull, chosen: false);
}

String _latencyText(int? value) =>
    value == null || value <= 0 ? '—' : '$value ms';

class _ConnectPanel extends ConsumerWidget {
  const _ConnectPanel({
    required this.session,
    required this.stacked,
    required this.syncing,
    required this.syncFailed,
    required this.connect,
    required this.openNodes,
    required this.minimumHeight,
  });

  final ZolnitSessionController session;
  final bool stacked;
  final bool syncing;
  final bool syncFailed;
  final Future<void> Function() connect;
  final VoidCallback openNodes;
  final double minimumHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final phase = ref.watch(zolnitConnectionPhaseProvider);
    final safe = ref.watch(safeModeProvider);
    final privateTransport = ref.watch(zolnitClientBundleTransportProvider);
    final nodes = privateTransport && session.clientBundle == null
        ? const <ZolnitNode>[]
        : session.nodeList;
    final running = ref.watch(isStartProvider);
    final configMessage = zolnitConfigurationMessage(
      context,
      session,
      ref.watch(zolnitBundleStatusProvider),
      privateTransport: privateTransport,
      stopped: !running,
    );
    final elapsed = ref.watch(runTimeProvider);
    final duration = Duration(milliseconds: elapsed ?? 0);
    final elapsedText = [
      duration.inHours,
      duration.inMinutes % 60,
      duration.inSeconds % 60,
    ].map((part) => part.toString().padLeft(2, '0')).join(':');
    final blocked =
        safe ||
        (!running &&
            (syncing ||
                phase == ZolnitConnectionPhase.connecting ||
                (nodes.isEmpty && !privateTransport)));
    final label = switch (phase) {
      ZolnitConnectionPhase.connected => text.connected,
      ZolnitConnectionPhase.connecting => text.connecting,
      ZolnitConnectionPhase.unavailable => text.zolnitConnectionIssue,
      _ => text.zolnitNotConnected,
    };
    final actionLabel = running
        ? text.zolnitDisconnectAction
        : phase == ZolnitConnectionPhase.unavailable
        ? text.retry
        : phase == ZolnitConnectionPhase.connecting
        ? text.connecting
        : text.zolnitConnectAction;
    final failureMessage =
        configMessage ??
        (syncFailed
            ? text.zolnitBundleUnavailable
            : phase == ZolnitConnectionPhase.unavailable
            ? text.zolnitConnectFailed
            : session.failure == null
            ? null
            : zolnitFailureText(context, session.failure, null));
    final android = skin == ZolnitSkin.android;
    final (headline, sub) = switch (skin) {
      ZolnitSkin.ios => (19.0, 11.0),
      ZolnitSkin.android => (23.0, 12.0),
      _ => (20.0, 12.0),
    };
    final statusLine = safe && nodes.isNotEmpty
        ? text.zolnitSafeModeConnect
        : syncing && !running
        ? text.zolnitSyncing
        : failureMessage ??
              (nodes.isEmpty ? text.zolnitNoNodes : text.zolnitConnectSub);
    final centered = ZolnitLayoutScope.of(context) == ZolnitLayout.compact;
    final copy = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ZolnitSwitcher(
          switchKey: label,
          duration: zolnitQuick,
          alignment: centered
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          child: Semantics(
            liveRegion: true,
            child: Text(
              label,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: zolnitText(
                context,
                headline,
                leading: headline * 1.4,
                weight: android ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ),
        if (phase == ZolnitConnectionPhase.connected && elapsed != null) ...[
          const SizedBox(height: 4),
          Text(
            elapsedText,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: zolnitText(context, sub, color: colors.muted),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          statusLine,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: zolnitText(context, sub, leading: 18, color: colors.muted),
        ),
        const SizedBox(height: 14),
        ZolnitButton(
          label: actionLabel,
          primary: !running,
          glyph: running ? AppGlyphs.close : AppGlyphs.power,
          onPressed: blocked ? null : connect,
        ),
      ],
    );
    return ZolnitCard(
      padding: EdgeInsets.zero,
      color: android ? colors.blue : colors.solid,
      radius: android
          ? const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(64),
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            )
          : null,
      child: Stack(
        children: [
          Positioned(
            top: 28,
            right: -12,
            width: stacked ? 240 : 360,
            child: Opacity(
              opacity: 0.55,
              child: ZolnitWorldMap(color: colors.muted.withValues(alpha: 0.2)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(skin.desktop ? 24 : 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (minimumHeight - (skin.desktop ? 48 : 44)).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (centered)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusDot(phase: phase, syncing: syncing && !running),
                        const SizedBox(height: 12),
                        copy,
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _StatusDot(phase: phase, syncing: syncing && !running),
                        const SizedBox(width: 16),
                        Expanded(child: copy),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionOptions extends ConsumerWidget {
  const _ConnectionOptions({
    required this.session,
    required this.syncing,
    required this.stacked,
    required this.openNodes,
  });

  final ZolnitSessionController session;
  final bool syncing;
  final bool stacked;
  final VoidCallback openNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privateTransport = ref.watch(zolnitClientBundleTransportProvider);
    final nodes = privateTransport && session.clientBundle == null
        ? const <ZolnitNode>[]
        : session.nodeList;
    final location = _SelectedRow(
      emptyMessage: context.appLocalizations.zolnitSelectServer,
      selection: _selectionOf(ref, session, nodes),
      connected:
          ref.watch(zolnitConnectionPhaseProvider) ==
          ZolnitConnectionPhase.connected,
      stacked: stacked,
      onOpen: openNodes,
    );
    final mode = _ModeControl(
      session: session,
      syncing: syncing,
      openNodes: openNodes,
    );
    return ZolnitCard(
      corner: ZolnitSkin.of(context).tileCorner,
      padding: const EdgeInsets.all(18),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [location, const SizedBox(height: 14), mode],
            )
          : Row(
              children: [
                Expanded(child: location),
                const SizedBox(width: 24),
                SizedBox(width: 250, child: mode),
              ],
            ),
    );
  }
}

class _ModeControl extends ConsumerStatefulWidget {
  const _ModeControl({
    required this.session,
    required this.syncing,
    required this.openNodes,
  });

  final ZolnitSessionController session;
  final bool syncing;
  final VoidCallback openNodes;

  @override
  ConsumerState<_ModeControl> createState() => _ModeControlState();
}

class _ModeControlState extends ConsumerState<_ModeControl> {
  bool _pending = false;
  bool _failed = false;
  Mode? _failedMode;

  bool _ready({bool watch = false}) {
    T read<T>(ProviderListenable<T> provider) =>
        watch ? ref.watch(provider) : ref.read(provider);
    final safe = read(safeModeProvider);
    final core = read(coreStatusProvider);
    final profile = read(currentProfileProvider);
    final groups = read(groupsProvider);
    final transport = read(zolnitClientBundleTransportProvider);
    final bundleStatus = read(zolnitBundleStatusProvider);
    final phase = read(zolnitConnectionPhaseProvider);
    final session = widget.session;
    return !safe &&
        zolnitConnectionConfigReady(read) &&
        phase != ZolnitConnectionPhase.unavailable &&
        phase != ZolnitConnectionPhase.connecting &&
        (!widget.syncing || read(isStartProvider)) &&
        session.authenticated &&
        core == CoreStatus.connected &&
        profile != null &&
        groups.isNotEmpty &&
        (transport
            ? bundleStatus == ZolnitBundleStatus.ready &&
                  (session.clientBundleFailure == null ||
                      read(zolnitBundleActivityProvider).failure ==
                          session.clientBundleFailure) &&
                  isCurrentZolnitBundleProfile(profile, session) &&
                  profile.zolnitBundleId == session.clientBundle?.bundleId
            : profile.label == zolnitProfileLabel(session));
  }

  Future<void> _change(Mode next) async {
    if (_pending) return;
    final session = widget.session;
    final generation = session.api.generation;
    final bundle = session.clientBundle;
    bool sameAccount() =>
        mounted &&
        identical(widget.session, session) &&
        session.api.generation == generation &&
        session.authenticated;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      final applied =
          _ready() &&
          await ref
              .read(setupActionProvider.notifier)
              .changeModeIfCurrent(
                next,
                isCurrent: () =>
                    sameAccount() &&
                    identical(session.clientBundle, bundle) &&
                    _ready(),
              );
      if (sameAccount()) {
        setState(() {
          _failed = !applied;
          _failedMode = applied ? null : next;
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final ready = _ready(watch: true);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZolnitSegmented<Mode>(
          expanded: true,
          value: ready ? mode : null,
          options: [
            (Mode.rule, text.zolnitModeSmart),
            (Mode.global, text.zolnitModeGlobal),
          ],
          onChanged: ready && !_pending
              ? (next) => unawaited(_change(next))
              : null,
        ),
        if (_failed) ...[
          Text(
            text.zolnitModeChangeFailed,
            key: const ValueKey('zolnit-mode-failure'),
          ),
          TextButton(
            onPressed: ready && !_pending && _failedMode != null
                ? () => unawaited(_change(_failedMode!))
                : null,
            child: Text(text.retry),
          ),
        ],
      ],
    );
  }
}

class _SelectedRow extends ConsumerWidget {
  const _SelectedRow({
    required this.emptyMessage,
    required this.selection,
    required this.connected,
    required this.stacked,
    required this.onOpen,
  });

  final _Selection selection;
  final String emptyMessage;
  final bool connected;
  final bool stacked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final node = selection.node;
    final latency = node == null || !selection.chosen
        ? null
        : ref.watch(delayProvider(proxyName: node.proxyName));
    final traffic = connected
        ? ref.watch(trafficsProvider.select((state) => state.list.lastOrNull))
        : null;
    String rate(num? value) {
      if (value == null) return '—';
      final shown = value.traffic;
      return '${shown.value} ${shown.unit}/s';
    }

    final speeds = [
      (AppGlyphs.arrowDown, rate(traffic?.down)),
      (AppGlyphs.arrowUp, rate(traffic?.up)),
    ];
    final cells = [
      for (final (glyph, value) in speeds)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(glyph, size: 13, color: colors.muted),
            const SizedBox(width: 5),
            Text(value, style: zolnitText(context, 11, color: colors.muted)),
          ],
        ),
    ];
    final speed = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 4,
            children: cells,
          )
        : Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: cells);
    return Row(
      children: [
        Expanded(
          child: node == null
              ? TextButton(onPressed: onOpen, child: Text(emptyMessage))
              : InkWell(
                  customBorder: AppShape.sm,
                  onTap: onOpen,
                  child: Row(
                    children: [
                      ZolnitFlagBadge(
                        flag: selection.chosen
                            ? zolnitNodePresentation(node).flag
                            : null,
                        label: selection.chosen
                            ? zolnitNodePresentation(node).region
                            : text.auto,
                        size: skin.desktop ? 31 : 38,
                      ),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selection.chosen
                                  ? selection.title ??
                                        zolnitDisplayTitle(node.title)
                                  : text.auto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: zolnitText(
                                context,
                                12,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${selection.chosen ? text.zolnitCurrentSelection : text.zolnitSelectServer}${latency != null && latency > 0 ? ' · ${_latencyText(latency)}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: zolnitText(
                                      context,
                                      11,
                                      color: colors.muted,
                                    ),
                                  ),
                                ),
                                GlyphIcon(
                                  AppGlyphs.chevronForward,
                                  size: 16,
                                  color: colors.muted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (connected) ...[const SizedBox(width: 12), speed],
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.phase, required this.syncing});

  final ZolnitConnectionPhase phase;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    final (color, glyph) = syncing
        ? (colors.accent, AppGlyphs.refresh)
        : switch (phase) {
            ZolnitConnectionPhase.connected => (
              Theme.of(context).colorScheme.success,
              AppGlyphs.check,
            ),
            ZolnitConnectionPhase.connecting => (
              colors.accent,
              AppGlyphs.refresh,
            ),
            ZolnitConnectionPhase.unavailable => (
              const Color(0xffb86e4b),
              AppGlyphs.warning,
            ),
            _ => (colors.muted, AppGlyphs.power),
          };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.15),
        shape: AppShape.circle,
      ),
      child: SizedBox.square(
        dimension: 64,
        child: Center(child: GlyphIcon(glyph, size: 32, color: color)),
      ),
    );
  }
}

class _PlanStrip extends StatelessWidget {
  const _PlanStrip({required this.usage, required this.onPlans});

  final ZolnitUsage? usage;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final current = usage;
    final expired =
        current != null &&
        current.expiresAt != null &&
        !current.expiresAt!.isAfter(DateTime.now().toUtc());
    final active = current != null && current.hasPlan && !expired;
    final planName = current?.planName ?? text.zolnitNoPlan;
    final days = current?.daysLeftAt(DateTime.now());
    final remaining = (current?.totalBytes ?? 0) > 0
        ? formatBytes(current?.remainingBytes)
        : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: AppShape.all(skin.tileCorner),
        onTap: onPlans,
        child: ZolnitCard(
          corner: skin.tileCorner,
          padding: EdgeInsets.symmetric(
            horizontal: skin.desktop ? 20 : 18,
            vertical: skin.desktop ? 14 : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            planName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: zolnitText(
                              context,
                              skin.desktop ? 13 : 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ZolnitPill(
                          label: active
                              ? text.zolnitStatusActive
                              : text.zolnitStatusNoPlan,
                        ),
                      ],
                    ),
                    if (days != null || remaining != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (remaining != null)
                            Text(
                              '${remaining.value} ${remaining.unit} ${text.zolnitTrafficLeftShort}',
                              style: zolnitText(
                                context,
                                skin.desktop ? 11 : 12,
                                color: colors.muted,
                              ),
                            ),
                          if (days != null)
                            Text(
                              text.zolnitDaysLeftLabel(days),
                              style: zolnitText(
                                context,
                                skin.desktop ? 11 : 12,
                                color: colors.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GlyphIcon(
                AppGlyphs.chevronForward,
                size: 16,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
