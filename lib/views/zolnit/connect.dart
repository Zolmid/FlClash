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
    builder: (context, constraints) => _layout(
      context,
      viewportHeight: constraints.maxHeight,
      stacked:
          compact ||
          !ZolnitSkin.of(context).desktop ||
          constraints.maxWidth < 820,
    ),
  );

  Widget _layout(
    BuildContext context, {
    required bool stacked,
    required double viewportHeight,
  }) {
    final skin = ZolnitSkin.of(context);
    final usage = session.usage;
    final padding = zolnitPagePadding(skin, compact: compact);
    final minimumHeight = viewportHeight.isFinite
        ? (viewportHeight - padding.vertical - (stacked ? 256 : 188)).clamp(
            0.0,
            520.0,
          )
        : 0.0;
    return ListView(
      padding: padding,
      children: [
        _ConnectPanel(
          session: session,
          stacked: stacked,
          syncing: syncing,
          syncFailed: syncFailed,
          connect: connect,
          openNodes: openNodes,
          minimumHeight: minimumHeight,
        ),
        SizedBox(height: skin.desktop ? 16 : 14),
        _ConnectionOptions(
          session: session,
          syncing: syncing,
          stacked: stacked,
          openNodes: openNodes,
        ),
        SizedBox(height: skin.desktop ? 16 : 14),
        _PlanStrip(usage: usage, onPlans: openPlans),
      ],
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
  var chosen = group == null
      ? null
      : ref.watch(selectedProxyNameProvider(group));
  final allGroups = ref.watch(groupsProvider);
  final visited = <String>{};
  while (chosen != null && chosen.isNotEmpty && visited.add(chosen)) {
    final known = nodes.where((node) => node.proxyName == chosen).firstOrNull;
    if (known != null) return _Selection(known, chosen: true);
    chosen = allGroups.where((entry) => entry.name == chosen).firstOrNull?.now;
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
    final configMessage = zolnitConfigurationMessage(
      context,
      session,
      ref.watch(zolnitBundleStatusProvider),
      privateTransport: privateTransport,
    );
    final running = ref.watch(isStartProvider);
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
    final label = syncing
        ? text.zolnitSyncing
        : switch (phase) {
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
        (syncFailed || phase == ZolnitConnectionPhase.unavailable
            ? text.zolnitFailure
            : session.failure == null
            ? null
            : zolnitFailureText(context, session.failure, null));
    final android = skin == ZolnitSkin.android;
    final center = !skin.desktop;
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
          actionLabel,
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
          safe && nodes.isNotEmpty
              ? text.zolnitSafeModeConnect
              : failureMessage ??
                    (nodes.isEmpty
                        ? text.zolnitNoNodes
                        : text.zolnitConnectSub),
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: zolnitText(context, sub, leading: 18, color: colors.muted),
        ),
      ],
    );
    final power = ZolnitPowerButton(
      status: phase == ZolnitConnectionPhase.connected
          ? CoreStatus.connected
          : phase == ZolnitConnectionPhase.connecting
          ? CoreStatus.connecting
          : CoreStatus.disconnected,
      label: actionLabel,
      onPressed: blocked ? null : connect,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: phase == ZolnitConnectionPhase.connected
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
                      if (phase == ZolnitConnectionPhase.connected &&
                          elapsed != null) ...[
                        const Spacer(),
                        const SizedBox(width: 8),
                        Text(
                          elapsedText,
                          style: zolnitText(context, 12, color: colors.muted),
                        ),
                      ],
                    ],
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (minimumHeight - (skin.desktop ? 76 : 72))
                          .clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      heightFactor: 1,
                      child: Padding(
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
                    ),
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
      selection: _selectionOf(ref, nodes),
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
        phase != ZolnitConnectionPhase.unavailable &&
        phase != ZolnitConnectionPhase.connecting &&
        !widget.syncing &&
        session.authenticated &&
        core == CoreStatus.connected &&
        profile != null &&
        groups.isNotEmpty &&
        (transport
            ? bundleStatus == ZolnitBundleStatus.ready &&
                  session.clientBundleFailure == null &&
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
      if (sameAccount()) setState(() => _failed = !applied);
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
            onPressed: widget.openNodes,
            child: Text(text.zolnitBundleFetchHint),
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
    final latency = node == null
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
                                  ? zolnitDisplayTitle(node.title)
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
