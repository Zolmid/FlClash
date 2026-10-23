import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'connect_art.dart';
import 'data.dart';
import 'kit.dart';
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

String _longDate(DateTime date) {
  try {
    return DateFormat.yMMMMEEEEd().format(date);
  } catch (_) {
    return zolnitDotDate(date);
  }
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
    required this.openNotice,
    required this.openNotices,
  });

  final ZolnitSessionController session;
  final bool compact;
  final bool syncing;
  final bool syncFailed;
  final Future<void> Function() connect;
  final VoidCallback openNodes;
  final VoidCallback openPlans;
  final ValueChanged<ZolnitNotice> openNotice;
  final VoidCallback openNotices;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) => _layout(
      context,
      stacked:
          compact ||
          !ZolnitSkin.of(context).desktop ||
          constraints.maxWidth < 820,
    ),
  );

  Widget _layout(BuildContext context, {required bool stacked}) {
    final skin = ZolnitSkin.of(context);
    final usage = session.usage;
    final connectPanel = _ConnectPanel(
      session: session,
      stacked: stacked,
      syncing: syncing,
      syncFailed: syncFailed,
      connect: connect,
      openNodes: openNodes,
    );
    final membership = ZolnitMembershipCard(usage: usage, onRenew: openPlans);
    final nodes = _NodesPanel(session: session, openNodes: openNodes);
    final notices = _NoticesPanel(
      notices: session.noticeList,
      onOpen: openNotice,
      onOpenAll: openNotices,
    );
    return ListView(
      padding: zolnitPagePadding(skin, compact: compact),
      children: [
        ZolnitPageHeading(
          title: context.appLocalizations.zolnitGreeting(
            zolnitDisplayName(session.account, usage),
          ),
          subtitle: context.appLocalizations.zolnitGreetingSub,
          trailing: skin.desktop && !compact ? const _DateLabel() : null,
        ),
        SizedBox(height: skin.desktop ? 24 : 22),
        if (stacked) ...[
          connectPanel,
          const SizedBox(height: 18),
          membership,
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 135, child: connectPanel),
                const SizedBox(width: 18),
                Expanded(flex: 100, child: membership),
              ],
            ),
          ),
        SizedBox(height: skin.desktop ? 15 : 18),
        _StatRow(usage: usage, gap: skin.desktop ? 15 : 8),
        SizedBox(height: skin.desktop ? 15 : 18),
        if (stacked) ...[
          nodes,
          const SizedBox(height: 18),
          notices,
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 135, child: nodes),
                const SizedBox(width: 18),
                Expanded(flex: 100, child: notices),
              ],
            ),
          ),
      ],
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel();

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlyphIcon(AppGlyphs.calendar, size: 14, color: colors.muted),
          const SizedBox(width: 6),
          Text(
            _longDate(DateTime.now()),
            style: zolnitText(context, 11, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _Selection {
  const _Selection(this.node, {required this.chosen});

  final ZolnitNode? node;
  final bool chosen;
}

_Selection _selectionOf(WidgetRef ref, List<ZolnitNode> nodes) {
  final groups = ref.watch(currentGroupsStateProvider).value;
  final group = groups.isEmpty ? null : groups.first.name;
  final chosen = group == null
      ? null
      : ref.watch(selectedProxyNameProvider(group));
  if (chosen != null && chosen.isNotEmpty) {
    final known = nodes.where((node) => node.name == chosen).firstOrNull;
    return _Selection(
      known ?? ZolnitNode.fromJson({'name': chosen}),
      chosen: true,
    );
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
  });

  final ZolnitSessionController session;
  final bool stacked;
  final bool syncing;
  final bool syncFailed;
  final Future<void> Function() connect;
  final VoidCallback openNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final status = ref.watch(coreStatusProvider);
    final safe = ref.watch(safeModeProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final nodes = session.nodeList;
    final blocked =
        safe || syncing || status == CoreStatus.connecting || nodes.isEmpty;
    final label = syncing
        ? text.zolnitSyncing
        : switch (status) {
            CoreStatus.connected => text.connected,
            CoreStatus.connecting => text.connecting,
            _ => text.zolnitNotConnected,
          };
    final android = skin == ZolnitSkin.android;
    final center = !skin.desktop && android;
    final (headline, sub) = switch (skin) {
      ZolnitSkin.ios => (19.0, 11.0),
      ZolnitSkin.android => (23.0, 12.0),
      _ => (20.0, 12.0),
    };
    final copy = Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.zolnitConnectHeadline,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: zolnitText(
            context,
            headline,
            leading: headline * 1.4,
            weight: android ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          safe
              ? text.zolnitSafeModeConnect
              : nodes.isEmpty
              ? text.zolnitNoNodes
              : text.zolnitConnectSub,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: zolnitText(context, sub, leading: 18, color: colors.muted),
        ),
        const SizedBox(height: 14),
        ZolnitSegmented<Mode>(
          value: mode,
          options: [
            (Mode.rule, text.zolnitModeSmart),
            (Mode.global, text.zolnitModeGlobal),
          ],
          onChanged: (next) {
            if (next != mode) {
              ref.read(setupActionProvider.notifier).changeMode(next);
            }
          },
        ),
      ],
    );
    final power = ZolnitPowerButton(
      status: status,
      label: label,
      onPressed: blocked ? null : connect,
    );
    final selection = _selectionOf(ref, nodes);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: status == CoreStatus.connected
                            ? const Color(0xff5f9b7a)
                            : colors.accent,
                        shape: AppShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 7),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zolnitText(
                          context,
                          skin.desktop ? 12 : 13,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: center
                        ? 22
                        : skin == ZolnitSkin.ios
                        ? 29
                        : 26,
                  ),
                  child: center
                      ? Column(
                          children: [
                            Center(child: power),
                            const SizedBox(height: 14),
                            copy,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            power,
                            SizedBox(width: skin.desktop ? 26 : 14),
                            Expanded(child: copy),
                          ],
                        ),
                ),
                ZolnitFailureMessage(
                  code: syncFailed ? 'profile_sync_failed' : session.failure,
                  serverMessage: syncFailed ? null : session.failureMessage,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colors.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: skin.desktop ? 18 : 14),
                    child: _SelectedRow(
                      selection: selection,
                      connected: status == CoreStatus.connected,
                      stacked: stacked,
                      onOpen: openNodes,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedRow extends ConsumerWidget {
  const _SelectedRow({
    required this.selection,
    required this.connected,
    required this.stacked,
    required this.onOpen,
  });

  final _Selection selection;
  final bool connected;
  final bool stacked;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final node = selection.node;
    final latency = node == null
        ? null
        : ref.watch(delayProvider(proxyName: node.name));
    final traffic = connected
        ? ref.watch(
            trafficsProvider.select(
              (state) => state.list.safeLast(const Traffic()),
            ),
          )
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
              ? Text(
                  text.zolnitNoNodes,
                  style: zolnitText(context, 12, color: colors.muted),
                )
              : InkWell(
                  customBorder: AppShape.sm,
                  onTap: onOpen,
                  child: Row(
                    children: [
                      ZolnitFlagBadge(
                        flag: node.flag,
                        label: node.region,
                        size: skin.desktop ? 31 : 38,
                      ),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              node.title,
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
                                    '${selection.chosen ? text.zolnitCurrentSelection : text.zolnitRecommendedRoute} · ${_latencyText(latency)}',
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
        const SizedBox(width: 12),
        speed,
      ],
    );
  }
}

String _gigabytes(num bytes, {int decimals = 1}) {
  final value = bytes / 1073741824;
  final text = value.toStringAsFixed(decimals);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

class ZolnitMembershipCard extends StatelessWidget {
  const ZolnitMembershipCard({
    super.key,
    required this.usage,
    required this.onRenew,
  });

  final ZolnitUsage? usage;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final now = DateTime.now();
    final current = usage;
    final expires = current?.expiresAt;
    final daysLeft = current?.daysLeftAt(now);
    final expired = expires != null && !expires.isAfter(now.toUtc());
    final active = current != null && current.hasPlan && !expired;
    final status = active
        ? text.zolnitStatusActive
        : current != null && current.hasPlan
        ? text.zolnitStatusExpired
        : text.zolnitStatusNoPlan;
    final planName = current?.planName ?? text.zolnitNoPlan;
    final total = current?.totalBytes ?? 0;
    final usedText = _gigabytes(current?.usedBytes ?? 0);
    final totalText = _gigabytes(total, decimals: 2);
    final (headline, figure) = switch (skin) {
      ZolnitSkin.ios => (23.0, 36.0),
      ZolnitSkin.android => (24.0, 38.0),
      _ => (22.0, 30.0),
    };
    final weight = skin == ZolnitSkin.ios || skin == ZolnitSkin.android
        ? FontWeight.w600
        : FontWeight.w500;
    const onDark = ZolnitColors.onMembership;
    const muted = ZolnitColors.mutedOnMembership;
    TextStyle small(double alpha) =>
        zolnitText(context, 11, color: muted.withValues(alpha: alpha));
    return ZolnitCard(
      padding: EdgeInsets.zero,
      color: ZolnitColors.membership,
      child: Stack(
        children: [
          const Positioned.fill(child: ZolnitMembershipArt()),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.zolnitMembershipEyebrow,
                        style: zolnitText(
                          context,
                          11,
                          weight: FontWeight.w600,
                          color: muted,
                          spacing: 1.8,
                        ),
                      ),
                    ),
                    ZolnitPill(
                      label: status,
                      background: Colors.white.withValues(alpha: 0.082),
                      foreground: onDark,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zolnitText(
                    context,
                    headline,
                    leading: headline * 1.35,
                    weight: weight,
                    color: onDark,
                  ),
                ),
                SizedBox(height: skin.desktop ? 22 : 26),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: usedText),
                      TextSpan(
                        text: total > 0 ? ' / $totalText GB' : ' GB',
                        style: zolnitText(context, 12, color: muted),
                      ),
                    ],
                  ),
                  style: zolnitText(
                    context,
                    figure,
                    leading: figure * 1.2,
                    weight: weight,
                    color: onDark,
                  ),
                ),
                const SizedBox(height: 12),
                ZolnitUsageBar(
                  fraction: current?.fraction ?? 0,
                  height: skin == ZolnitSkin.android ? 8 : 5,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(text.zolnitTrafficUsed, style: small(1)),
                    if ((current?.resetDay ?? 0) > 0)
                      Text(
                        text.zolnitResetInDays(current!.resetDay!),
                        style: small(1),
                      ),
                  ],
                ),
                SizedBox(height: skin.desktop ? 22 : 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expires == null
                            ? ''
                            : '${text.zolnitExpiresOn(zolnitDotDate(expires))} · ${text.zolnitDaysLeftLabel(daysLeft ?? 0)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: small(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ZolnitButton(
                      onDark: true,
                      label: active
                          ? text.zolnitRenewPlan
                          : text.zolnitSubscribePlan,
                      glyph: AppGlyphs.arrowForward,
                      onPressed: onRenew,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.usage, required this.gap});

  final ZolnitUsage? usage;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final current = usage;
    final hasQuota = current != null && current.totalBytes > 0;
    final left = hasQuota ? formatBytes(current.remainingBytes) : null;
    final days = current?.daysLeftAt(DateTime.now());
    final online = current?.onlineDevices;
    final limit = current?.deviceLimit;
    final tiles = [
      ZolnitStatTile(
        label: text.zolnitTrafficLeft,
        value: left?.value ?? '—',
        unit: left?.unit,
        glyph: AppGlyphs.dataUsage,
        tint: colors.lavender,
      ),
      ZolnitStatTile(
        label: text.zolnitPlanValidity,
        value: days?.toString() ?? '—',
        unit: days == null ? null : text.zolnitDaysUnit,
        glyph: AppGlyphs.calendar,
        tint: colors.blue,
      ),
      ZolnitStatTile(
        label: text.zolnitOnlineDevices,
        value: online?.toString() ?? '—',
        unit: limit == null ? null : text.zolnitOutOfDevices(limit),
        glyph: AppGlyphs.devices,
        tint: colors.clay,
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(child: tile),
          ],
        ],
      ),
    );
  }
}

class _NodesPanel extends ConsumerWidget {
  const _NodesPanel({required this.session, required this.openNodes});

  final ZolnitSessionController session;
  final VoidCallback openNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final nodes = session.nodeList.take(3).toList();
    final selection = _selectionOf(ref, session.nodeList);
    final head = zolnitText(context, 11, color: colors.muted);
    final group = ref.watch(currentGroupsStateProvider).value.firstOrNull;
    void choose(ZolnitNode node) {
      if (group != null &&
          group.type == GroupType.Selector &&
          group.all.any((proxy) => proxy.name == node.name)) {
        selectGroupProxy(
          ref,
          groupName: group.name,
          groupType: group.type,
          proxyName: node.name,
        );
      } else {
        openNodes();
      }
    }

    return ZolnitCard(
      padding: EdgeInsets.all(skin.desktop ? 23 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZolnitSectionHeading(
            title: text.zolnitRecommendedNodes,
            subtitle: text.zolnitRecommendedNodesSub,
            actionLabel: text.zolnitAllNodes,
            onAction: openNodes,
          ),
          const SizedBox(height: 18),
          if (nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  text.zolnitNoNodes,
                  style: zolnitText(context, 12, color: colors.muted),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(text.zolnitNodeName, style: head)),
                  SizedBox(
                    width: 76,
                    child: Text(text.zolnitLatency, style: head),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      text.zolnitSelectColumn,
                      textAlign: TextAlign.end,
                      style: head,
                    ),
                  ),
                ],
              ),
            ),
            for (final node in nodes)
              _NodeRow(
                node: node,
                selected: selection.chosen && selection.node?.name == node.name,
                onTap: () => choose(node),
              ),
          ],
        ],
      ),
    );
  }
}

class _NodeRow extends ConsumerWidget {
  const _NodeRow({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final ZolnitNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ZolnitColors.of(context);
    final latency = ref.watch(delayProvider(proxyName: node.name));
    final tags = node.tags.isEmpty ? '' : ' · ${node.tags.first}';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line(0.08))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Row(
              children: [
                ZolnitFlagBadge(flag: node.flag, label: node.region),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zolnitText(context, 12, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${node.region}$tags',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: zolnitText(context, 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    _latencyText(latency),
                    style: zolnitText(context, 11, color: colors.muted),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: selected ? colors.accent : Colors.transparent,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: selected ? colors.accent : colors.line(0.3),
                          ),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 17,
                        child: selected
                            ? Center(
                                child: GlyphIcon(
                                  AppGlyphs.check,
                                  size: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? colors.paper
                                      : Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticesPanel extends StatelessWidget {
  const _NoticesPanel({
    required this.notices,
    required this.onOpen,
    required this.onOpenAll,
  });

  final List<ZolnitNotice> notices;
  final ValueChanged<ZolnitNotice> onOpen;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    return ZolnitCard(
      padding: EdgeInsets.all(skin.desktop ? 23 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZolnitSectionHeading(
            title: text.zolnitLatestNotices,
            onAction: notices.isEmpty ? null : onOpenAll,
          ),
          const SizedBox(height: 14),
          if (notices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  text.zolnitNoNotices,
                  style: zolnitText(context, 12, color: colors.muted),
                ),
              ),
            )
          else
            for (final notice in notices.take(3))
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.line(0.08))),
                ),
                child: InkWell(
                  onTap: () => onOpen(notice),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        if (notice.tags.isNotEmpty) ...[
                          ZolnitPill(
                            label: notice.tags.first,
                            background: colors.soft,
                            foreground: colors.muted,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notice.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: zolnitText(
                                  context,
                                  12,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (notice.createdAt != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  zolnitDotDate(
                                    notice.createdAt!,
                                  ).replaceAll('.', '-'),
                                  style: zolnitText(
                                    context,
                                    11,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        GlyphIcon(
                          AppGlyphs.chevronForward,
                          size: 16,
                          color: colors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
