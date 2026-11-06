import 'dart:async';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';
import 'data.dart';
import 'node_groups.dart';
import 'bundle_routing.dart';
import 'skin.dart';

class ZolnitNodesPage extends ConsumerStatefulWidget {
  const ZolnitNodesPage({
    super.key,
    required this.session,
    required this.sync,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final Future<int?> Function() sync;
  final bool compact;

  @override
  ConsumerState<ZolnitNodesPage> createState() => _ZolnitNodesPageState();
}

class _ZolnitNodesPageState extends ConsumerState<ZolnitNodesPage> {
  String _region = '';
  String _routingService = 'ai';
  String _query = '';
  Object? _measurementKey;
  late int _generation = widget.session.api.generation;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String? _hostsKey;
  ZolnitRouteMetadata? _hosts;
  (List<ZolnitNode>, ZolnitRouteMetadata, Map<String, String>)? _entriesSource;
  List<ZolnitRouteEntry> _entries = const [];

  @override
  void didUpdateWidget(covariant ZolnitNodesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_generation != widget.session.api.generation ||
        oldWidget.session != widget.session) {
      _generation = widget.session.api.generation;
      _region = '';
      _routingService = 'ai';
      _query = '';
      _searchController.clear();
      _measurementKey = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(groupsProvider, (_, _) => _autoMeasure());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(initProvider) && ref.read(currentProfileProvider) == null) {
        unawaited(
          widget.sync().then((_) => _autoMeasure(), onError: (Object _) {}),
        );
      } else {
        _autoMeasure();
      }
    });
  }

  void _autoMeasure() {
    if (!mounted ||
        ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    if (!_isCurrentAccount(ref, watch: false)) return;
    final key = (
      widget.session.api.generation,
      widget.session.clientBundle?.bundleId,
      ref.read(currentProfileProvider)?.id,
      widget.session.nodeList.map((node) => node.proxyName).join('\u0000'),
      ref.read(realTestUrlProvider()),
    );
    if (_measurementKey == key) return;
    _measurementKey = key;
    _measureNodes();
  }

  bool _isCurrentAccount(WidgetRef ref, {required bool watch}) =>
      zolnitProfileIsCurrent(ref, widget.session, watch: watch);

  ZolnitRouteMetadata? _serverHosts(ZolnitClientBundle bundle) {
    final key = bundle.connectionSha256;
    if (_hostsKey == key) return _hosts;
    _hostsKey = key;
    _hosts = cachedZolnitRouteMetadata(bundle);
    if (_hosts == null) {
      unawaited(
        loadZolnitRouteMetadata(bundle).then((hosts) {
          if (mounted && _hostsKey == key) {
            setState(() => _hosts = hosts);
            _autoMeasure();
          }
        }, onError: (Object _) {}),
      );
    }
    return _hosts;
  }

  List<ZolnitRouteEntry> _routeEntries(
    List<ZolnitNode> nodes,
    ZolnitRouteMetadata metadata,
    Map<String, String> exitIds,
  ) {
    final source = _entriesSource;
    if (source == null ||
        !identical(source.$1, nodes) ||
        !identical(source.$2, metadata) ||
        !identical(source.$3, exitIds)) {
      _entriesSource = (nodes, metadata, exitIds);
      _entries = groupZolnitRoutes(
        nodes,
        hosts: metadata.hosts,
        exitIds: exitIds,
        paths: metadata.paths,
      );
    }
    return _entries;
  }

  List<String> _regions(List<ZolnitRouteEntry> entries) {
    final seen = <String>{};
    return [
      for (final entry in entries)
        if (entry.region.isNotEmpty && seen.add(entry.region)) entry.region,
    ];
  }

  List<ZolnitRouteEntry> _filtered(List<ZolnitRouteEntry> entries) {
    final lower = _query.trim().toLowerCase();
    return entries.where((entry) {
      if (_region.isNotEmpty && entry.region != _region) return false;
      if (lower.isEmpty) return true;
      return entry.title.toLowerCase().contains(lower) ||
          entry.region.toLowerCase().contains(lower) ||
          entry.members.any(
            (node) =>
                node.name.toLowerCase().contains(lower) ||
                node.tags.any((tag) => tag.toLowerCase().contains(lower)),
          );
    }).toList();
  }

  String? _activeProxy(_SelectorMatch match, {bool watch = true}) {
    final group = match.groupName;
    if (group == null) return null;
    final live = watch
        ? ref.watch(coreStatusProvider)
        : ref.read(coreStatusProvider);
    final safe = watch
        ? ref.watch(safeModeProvider)
        : ref.read(safeModeProvider);
    if (live == CoreStatus.connected && !safe) {
      final provider = groupsProvider.select(
        (groups) => groups.getGroup(group)?.realNow,
      );
      return watch ? ref.watch(provider) : ref.read(provider);
    }
    final provider = selectedMapProvider.select((map) => map[group]);
    final saved = watch ? ref.watch(provider) : ref.read(provider);
    return match.members.contains(saved) ? saved : null;
  }

  _SelectorMatch _findSelector(WidgetRef ref, {bool watch = true}) {
    final profile = watch
        ? ref.watch(currentProfileProvider)
        : ref.read(currentProfileProvider);
    final privateProfile = profile != null && isZolnitBundleProfile(profile);
    final label = zolnitProfileLabel(widget.session);
    if (!_isCurrentAccount(ref, watch: watch) ||
        (!privateProfile && label == null)) {
      return const _SelectorMatch(null, null);
    }
    final groups =
        (watch
                ? ref.watch(currentGroupsStateProvider)
                : ref.read(currentGroupsStateProvider))
            .value;
    if (privateProfile) {
      final bundle = widget.session.clientBundle;
      if (bundle == null ||
          bundle.bundleId != profile.zolnitBundleId ||
          !bundle.isFresh(ref.read(zolnitBundleClockProvider)())) {
        return const _SelectorMatch(null, null);
      }
      final metadata = _serverHosts(bundle);
      if (metadata == null) return const _SelectorMatch(null, null);
      final group = zolnitNodesGroup(
        metadata,
        watch ? ref.watch(groupsProvider) : ref.read(groupsProvider),
        (watch
                ? ref.watch(patchClashConfigProvider)
                : ref.read(patchClashConfigProvider))
            .mode,
      );
      if (group == null) return const _SelectorMatch(null, null);
      return _SelectorMatch(
        group.name,
        group.testUrl,
        group.all.map((proxy) => proxy.name).toSet(),
        group.type == GroupType.Selector,
      );
    }
    final names = widget.session.nodeList.map((node) => node.proxyName).toSet();
    for (final group in groups) {
      if (group.type == GroupType.Selector) {
        final members = group.all.map((proxy) => proxy.name).toSet();
        if (members.any(names.contains)) {
          return _SelectorMatch(group.name, group.testUrl, members);
        }
      }
    }
    return const _SelectorMatch(null, null);
  }

  void _selectNode(String groupName, String proxyName) {
    if (ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    final match = _findSelector(ref, watch: false);
    if (!match.manual ||
        match.groupName != groupName ||
        !match.members.contains(proxyName)) {
      return;
    }
    selectGroupProxy(
      ref,
      groupName: groupName,
      groupType: GroupType.Selector,
      proxyName: proxyName,
    );
  }

  void _selectEntry(String groupName, ZolnitRouteEntry entry) {
    final match = _findSelector(ref, watch: false);
    if (!match.manual || match.groupName != groupName) return;
    if (entry.contains(_activeProxy(match, watch: false))) return;
    final target = zolnitPreferredMember(
      entry,
      (node) => ref.read(
        delayProvider(proxyName: node.proxyName, testUrl: match.testUrl),
      ),
      eligible: (node) => match.members.contains(node.proxyName),
    );
    if (target != null) _selectNode(groupName, target.proxyName);
  }

  void _measureNodes() {
    if (!mounted ||
        ref.read(safeModeProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected ||
        !_isCurrentAccount(ref, watch: false)) {
      return;
    }
    final url = ref.read(realTestUrlProvider());
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    final proxies = [
      for (final node in widget.session.nodeList)
        if (node.proxyName.trim().isNotEmpty)
          Proxy(name: node.proxyName, type: 'ss'),
    ];
    if (proxies.isEmpty) return;
    final group = 'zolnit-nodes-${widget.session.api.generation}';
    final testing = ref.read(delayTestingGroupsProvider.notifier);
    if (!testing.start(group)) return;
    unawaited(
      ref
          .read(proxiesActionProvider.notifier)
          .delayTestNodes(proxies, url)
          .whenComplete(() => testing.stop(group)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final privateTransport = ref.watch(zolnitClientBundleTransportProvider);
    final bundleStatus = ref.watch(zolnitBundleStatusProvider);
    final bundle = widget.session.clientBundle;
    final nodes = privateTransport && bundle == null
        ? const <ZolnitNode>[]
        : widget.session.nodeList;
    final metadata = bundle == null
        ? const ZolnitRouteMetadata({}, null)
        : _serverHosts(bundle);
    final hosts = metadata?.hosts;
    final entries = hosts == null
        ? const <ZolnitRouteEntry>[]
        : _routeEntries(
            nodes,
            metadata!,
            bundle?.exitIds ?? const <String, String>{},
          );
    final regions = _regions(entries);
    final selector = _findSelector(ref);
    final selectorReady = selector.groupName != null;
    final active = _activeProxy(selector);
    final testUrl = ref.watch(realTestUrlProvider());
    final delays = ref.watch(delayDataSourceProvider);
    final currentAccount = _isCurrentAccount(ref, watch: true);
    int? delayOf(ZolnitNode node) =>
        currentAccount ? (delays[testUrl]?[node.proxyName]) : null;
    final shown = {
      for (final entry in entries)
        entry.key:
            zolnitPreferredMember(
              entry,
              delayOf,
              active: active,
              eligible: (node) => selector.members.contains(node.proxyName),
            ) ??
            entry.primary,
    };
    final filtered = sortZolnitRoutesByLatency(
      _filtered(entries),
      (entry) => shown[entry.key]!,
      delayOf,
    );
    final mode = ref.watch(patchClashConfigProvider).mode;
    final safe = ref.watch(safeModeProvider);
    final core = ref.watch(coreStatusProvider);
    final liveChoice = !safe && core == CoreStatus.connected;
    final automatic =
        !selector.manual ||
        (active != null &&
            ref
                    .watch(groupsProvider)
                    .getGroup(active)
                    ?.type
                    .isComputedSelected ==
                true);
    final canTest = currentAccount && !safe && core == CoreStatus.connected;
    if (canTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoMeasure());
    }
    final bundleMessage = zolnitConfigurationMessage(
      context,
      widget.session,
      bundleStatus,
      privateTransport: privateTransport,
    );

    return ListView(
      padding: zolnitPagePadding(skin, compact: widget.compact),
      children: [
        if (bundleMessage != null && nodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(bundleMessage),
          ),
        _Toolbar(
          skin: skin,
          colors: colors,
          regions: regions,
          selectedRegion: _region,
          onRegionChanged: (region) => setState(() => _region = region),
          searchController: _searchController,
          searchFocus: _searchFocus,
          onQueryChanged: (value) => setState(() => _query = value),
          allLabel: l10n.zolnitAllRegions,
          searchHint: l10n.zolnitSearchNodes,
        ),
        SizedBox(height: skin.desktop ? 8 : 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!privateTransport || bundle != null) ...[
              Text(
                l10n.zolnitNodesCount(filtered.length),
                style: zolnitText(context, 11, color: colors.muted),
              ),
              if (filtered.length > 1)
                Text(
                  l10n.zolnitNodesSortedByLatency,
                  style: zolnitText(context, 11, color: colors.muted),
                ),
            ],
            if (canTest)
              _DelayTestButton(
                groupName: 'zolnit-nodes-${widget.session.api.generation}',
                onPressed: _measureNodes,
              ),
          ],
        ),
        if (selectorReady) ...[
          SizedBox(height: skin.desktop ? 6 : 8),
          Text(switch (mode) {
            Mode.global => l10n.zolnitNodesScopeGlobal,
            Mode.direct => l10n.zolnitNodesScopeDirect,
            Mode.rule => l10n.zolnitNodesScopeRule,
          }, style: zolnitText(context, 11, color: colors.muted)),
        ],
        if (selectorReady) ...[
          const SizedBox(height: 6),
          Text(
            automatic
                ? l10n.zolnitNodesAutomaticPolicy
                : liveChoice
                ? l10n.zolnitNodesCurrentChoice
                : l10n.zolnitNodesSavedChoice,
            style: zolnitText(context, 11, color: colors.muted),
          ),
        ],
        SizedBox(height: skin.desktop ? 12 : 14),
        if (hosts == null)
          _EmptyState(message: l10n.loading, colors: colors)
        else if (filtered.isEmpty)
          _EmptyState(
            message: nodes.isEmpty
                ? bundleMessage ?? l10n.zolnitNoNodes
                : l10n.zolnitNoMatchingNodes,
            colors: colors,
          )
        else
          Column(
            children: [
              for (final entry in filtered)
                _RouteTile(
                  key: ValueKey('zolnit-route-${entry.key}'),
                  entry: entry,
                  shown: shown[entry.key]!,
                  delay: delayOf(shown[entry.key]!),
                  selected: entry.contains(active),
                  skin: skin,
                  onSelect:
                      canTest &&
                          entry.members.any(
                            (node) => selector.members.contains(node.proxyName),
                          )
                      ? () => _selectEntry(selector.groupName!, entry)
                      : null,
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (privateTransport &&
            mode == Mode.rule &&
            widget.session.clientBundle?.routingManifest.services.isNotEmpty ==
                true)
          ExpansionTile(
            trailing: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
            title: Text(
              l10n.zolnitRoutingOptions,
              style: zolnitText(context, 13),
            ),
            children: [
              ZolnitBundleRoutingPanel(
                session: widget.session,
                selectedServiceId: _routingService,
                onServiceChanged: (value) =>
                    setState(() => _routingService = value),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.zolnitNodeMeasurementHint,
            style: zolnitText(context, 10, color: colors.muted),
          ),
        ),
      ],
    );
  }
}

class _SelectorMatch {
  const _SelectorMatch(
    this.groupName,
    this.testUrl, [
    this.members = const {},
    this.manual = true,
  ]);
  final bool manual;

  final String? groupName;
  final String? testUrl;
  final Set<String> members;
}

class _DelayTestButton extends ConsumerWidget {
  const _DelayTestButton({required this.groupName, required this.onPressed});

  final String groupName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testing = ref.watch(
      delayTestingGroupsProvider.select((set) => set.contains(groupName)),
    );
    final l10n = context.appLocalizations;
    return ZolnitButton(
      label: l10n.delayTest,
      onPressed: testing ? null : onPressed,
      glyph: AppGlyphs.bolt,
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.skin,
    required this.colors,
    required this.regions,
    required this.selectedRegion,
    required this.onRegionChanged,
    required this.searchController,
    required this.searchFocus,
    required this.onQueryChanged,
    required this.allLabel,
    required this.searchHint,
  });

  final ZolnitSkin skin;
  final ZolnitColors colors;
  final List<String> regions;
  final String selectedRegion;
  final ValueChanged<String> onRegionChanged;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onQueryChanged;
  final String allLabel;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    final chips = <(String, String)>[
      ('', allLabel),
      for (final region in regions) (region, region),
    ];
    final scale = MediaQuery.textScalerOf(context);
    final filters = SizedBox(
      height:
          (scale.scale(skin.desktop ? 12 : 13) * 1.45 +
                  (skin.desktop ? 12 : 20))
              .clamp(skin.desktop ? 34.0 : 42.0, double.infinity),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = chips[index];
          final active = value == selectedRegion;
          return _RegionChip(
            key: ValueKey('zolnit-region-$value'),
            label: label,
            active: active,
            skin: skin,
            colors: colors,
            onTap: () => onRegionChanged(value),
          );
        },
      ),
    );
    final search = _SearchField(
      controller: searchController,
      focusNode: searchFocus,
      hint: searchHint,
      skin: skin,
      colors: colors,
      onChanged: onQueryChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (skin.desktop && constraints.maxWidth >= 750) {
          return Row(
            children: [
              Expanded(child: filters),
              const SizedBox(width: 24),
              SizedBox(width: 240, child: search),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            filters,
            SizedBox(height: skin.desktop ? 14 : 12),
            search,
          ],
        );
      },
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    super.key,
    required this.label,
    required this.active,
    required this.skin,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ZolnitSkin skin;
  final ZolnitColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corner = skin.controlCorner;
    final shape = RoundedSuperellipseBorder(
      borderRadius: AppRadius.all(corner),
      side: active ? BorderSide.none : BorderSide(color: colors.line()),
    );
    return Material(
      color: active ? colors.accent : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: skin.desktop ? 12 : 14,
            vertical: skin.desktop ? 6 : 10,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: zolnitText(
                context,
                skin.desktop ? 12 : 13,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? colors.paper
                          : Colors.white)
                    : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.skin,
    required this.colors,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ZolnitSkin skin;
  final ZolnitColors colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.soft,
        shape: AppShape.all(skin.controlCorner),
      ),
      child: SizedBox(
        height:
            (MediaQuery.textScalerOf(context).scale(skin.desktop ? 12 : 14) *
                        1.45 +
                    20)
                .clamp(skin.desktop ? 38.0 : 44.0, double.infinity),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GlyphIcon(AppGlyphs.search, size: 16, color: colors.muted),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: zolnitText(context, skin.desktop ? 12 : 14),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: zolnitText(
                    context,
                    skin.desktop ? 12 : 14,
                    color: colors.muted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.colors});

  final String message;
  final ZolnitColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(AppGlyphs.search, size: 32, color: colors.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: zolnitText(context, 13, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    super.key,
    required this.entry,
    required this.shown,
    required this.delay,
    required this.selected,
    required this.skin,
    this.onSelect,
  });

  final ZolnitRouteEntry entry;
  final ZolnitNode shown;
  final int? delay;
  final bool selected;
  final ZolnitSkin skin;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final delay = this.delay;

    final delayLabel = delay == null || delay == 0
        ? '—'
        : delay > 0
        ? '$delay ms'
        : delayFailureText(delay, l10n);

    final delayColor = delay == null || delay == 0
        ? colors.muted
        : context.colorScheme.delayColor(delay) ?? colors.muted;

    final regionLabel = entry.region.isEmpty ? l10n.unknown : entry.region;

    return Semantics(
      selected: selected,
      button: onSelect != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line(0.06))),
        ),
        child: Material(
          color: selected
              ? colors.accent.withValues(alpha: dark ? 0.12 : 0.06)
              : Colors.transparent,
          child: InkWell(
            onTap: onSelect,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: skin.desktop ? 4 : 2,
                vertical: skin.desktop ? 10 : 12,
              ),
              child: Row(
                children: [
                  ZolnitFlagBadge(
                    flag: entry.flag,
                    label: regionLabel,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            skin.desktop ? 12 : 13,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          regionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            skin.desktop ? 10 : 11,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (shown.rateKnown && shown.rate != 1) ...[
                    ZolnitPill(
                      label: l10n.zolnitNodeMultiplier(shown.rateText),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 56,
                    child: Text(
                      delayLabel,
                      textAlign: TextAlign.end,
                      style: zolnitText(
                        context,
                        11,
                        weight: FontWeight.w500,
                        color: delayColor,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    GlyphIcon(AppGlyphs.check, size: 16, color: colors.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the running profile's measured delays belong to [session].
bool zolnitProfileIsCurrent(
  WidgetRef ref,
  ZolnitSessionController session, {
  required bool watch,
}) {
  final profile = watch
      ? ref.watch(currentProfileProvider)
      : ref.read(currentProfileProvider);
  if (profile != null && isZolnitBundleProfile(profile)) {
    final bundle = session.clientBundle;
    return isCurrentZolnitBundleProfile(profile, session) &&
        bundle != null &&
        bundle.bundleId == profile.zolnitBundleId &&
        bundle.isFresh(ref.read(zolnitBundleClockProvider)());
  }
  return !ref.read(zolnitClientBundleTransportProvider) &&
      profile?.label == zolnitProfileLabel(session);
}
