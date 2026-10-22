import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';
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
  String _query = '';
  bool _syncing = false;
  bool _syncFailed = false;
  late int _generation = widget.session.api.generation;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void didUpdateWidget(covariant ZolnitNodesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_generation != widget.session.api.generation ||
        oldWidget.session != widget.session) {
      _generation = widget.session.api.generation;
      _region = '';
      _query = '';
      _searchController.clear();
      _syncing = false;
      _syncFailed = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    if (_syncing) return;
    final generation = _generation;
    bool current() => mounted && generation == widget.session.api.generation;
    setState(() {
      _syncing = true;
      _syncFailed = false;
    });
    try {
      final profile = await widget.sync();
      if (profile == null && current()) setState(() => _syncFailed = true);
    } catch (_) {
      if (current()) setState(() => _syncFailed = true);
    } finally {
      if (current()) setState(() => _syncing = false);
    }
  }

  List<String> _regions(List<ZolnitNode> nodes) {
    final seen = <String>{};
    final result = <String>[];
    for (final node in nodes) {
      if (seen.add(node.region)) result.add(node.region);
    }
    return result;
  }

  List<ZolnitNode> _filtered(List<ZolnitNode> nodes) {
    final lower = _query.trim().toLowerCase();
    return nodes.where((node) {
      if (_region.isNotEmpty && node.region != _region) return false;
      if (lower.isEmpty) return true;
      return node.name.toLowerCase().contains(lower) ||
          node.title.toLowerCase().contains(lower) ||
          node.region.toLowerCase().contains(lower) ||
          node.tags.any((tag) => tag.toLowerCase().contains(lower));
    }).toList();
  }

  _SelectorMatch _findSelector(WidgetRef ref, {bool watch = true}) {
    final profile = watch
        ? ref.watch(currentProfileProvider)
        : ref.read(currentProfileProvider);
    final label = zolnitProfileLabel(widget.session);
    if (label == null || profile?.label != label) {
      return const _SelectorMatch(null, null);
    }
    final groups =
        (watch
                ? ref.watch(currentGroupsStateProvider)
                : ref.read(currentGroupsStateProvider))
            .value;
    final names = widget.session.nodeList.map((node) => node.name).toSet();
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
    if (match.groupName != groupName || !match.members.contains(proxyName)) {
      return;
    }
    selectGroupProxy(
      ref,
      groupName: groupName,
      groupType: GroupType.Selector,
      proxyName: proxyName,
    );
  }

  void _handleDelayTest(String groupName) {
    final safe = ref.read(safeModeProvider);
    final core = ref.read(coreStatusProvider);
    if (safe ||
        core != CoreStatus.connected ||
        _findSelector(ref, watch: false).groupName != groupName) {
      return;
    }
    ref.read(proxiesActionProvider.notifier).delayTestPageGroup(groupName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final nodes = widget.session.nodeList;
    final regions = _regions(nodes);
    final filtered = _filtered(nodes);
    final selector = _findSelector(ref);
    final selectorReady = selector.groupName != null;
    final safe = ref.watch(safeModeProvider);
    final core = ref.watch(coreStatusProvider);
    final canTest = selectorReady && !safe && core == CoreStatus.connected;

    return ListView(
      padding: zolnitPagePadding(skin, compact: widget.compact),
      children: [
        ZolnitPageHeading(
          title: l10n.zolnitNodesHeadline,
          subtitle: l10n.zolnitNodesSubtitle,
          trailing: canTest
              ? _DelayTestButton(
                  groupName: selector.groupName!,
                  onPressed: () => _handleDelayTest(selector.groupName!),
                )
              : null,
        ),
        SizedBox(height: skin.desktop ? 20 : 18),
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
            Text(
              l10n.zolnitNodesCount(filtered.length),
              style: zolnitText(context, 11, color: colors.muted),
            ),
            if (!selectorReady && nodes.isNotEmpty)
              _SyncHint(
                label: l10n.zolnitNodeSyncHint,
                syncing: _syncing,
                onSync: _handleSync,
                colors: colors,
              ),
          ],
        ),
        if (_syncFailed) ...[
          const SizedBox(height: 8),
          Text(
            l10n.zolnitFailure,
            style: zolnitText(context, 12, color: colors.muted),
          ),
        ],
        SizedBox(height: skin.desktop ? 12 : 14),
        if (filtered.isEmpty)
          _EmptyState(
            message: nodes.isEmpty
                ? l10n.zolnitNoNodes
                : l10n.zolnitNoMatchingNodes,
            colors: colors,
          )
        else
          _NodeGrid(
            nodes: filtered,
            skin: skin,
            compact: widget.compact,
            selectorGroup: selector.groupName,
            testUrl: selector.testUrl,
            members: selector.members,
            onSelect: selectorReady && !safe && core == CoreStatus.connected
                ? (name) => _selectNode(selector.groupName!, name)
                : null,
          ),
        const SizedBox(height: 12),
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
  const _SelectorMatch(this.groupName, this.testUrl, [this.members = const {}]);

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

class _SyncHint extends StatelessWidget {
  const _SyncHint({
    required this.label,
    required this.syncing,
    required this.onSync,
    required this.colors,
  });

  final String label;
  final bool syncing;
  final VoidCallback onSync;
  final ZolnitColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: AppShape.sm,
      onTap: syncing ? null : onSync,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncing)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: CommonCircleLoading(size: 12),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GlyphIcon(
                  AppGlyphs.arrowDown,
                  size: 12,
                  color: colors.accent,
                ),
              ),
            Flexible(
              child: Text(
                label,
                style: zolnitText(context, 11, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeGrid extends StatelessWidget {
  const _NodeGrid({
    required this.nodes,
    required this.skin,
    required this.compact,
    required this.selectorGroup,
    required this.testUrl,
    required this.members,
    required this.onSelect,
  });

  final List<ZolnitNode> nodes;
  final ZolnitSkin skin;
  final bool compact;
  final String? selectorGroup;
  final String? testUrl;
  final Set<String> members;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = skin.desktop && !compact
            ? ((constraints.maxWidth + 14) / 340).floor().clamp(1, 2)
            : 1;
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final node in nodes)
              SizedBox(
                width: width,
                child: _NodeCard(
                  node: node,
                  skin: skin,
                  selectorGroup: members.contains(node.name)
                      ? selectorGroup
                      : null,
                  testUrl: testUrl,
                  onSelect: onSelect != null && members.contains(node.name)
                      ? () => onSelect!(node.name)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard({
    required this.node,
    required this.skin,
    required this.selectorGroup,
    required this.testUrl,
    this.onSelect,
  });

  final ZolnitNode node;
  final ZolnitSkin skin;
  final String? selectorGroup;
  final String? testUrl;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final selected =
        selectorGroup != null &&
        ref.watch(
          selectedProxyNameProvider(
            selectorGroup!,
          ).select((name) => name == node.name),
        );

    final delay = selectorGroup != null
        ? ref.watch(delayProvider(proxyName: node.name, testUrl: testUrl))
        : null;

    final delayLabel = delay == null || delay == 0
        ? '\u2014'
        : delay > 0
        ? '$delay ms'
        : delayFailureText(delay, l10n);

    final delayColor = delay == null || delay == 0
        ? colors.muted
        : context.colorScheme.delayColor(delay) ?? colors.muted;

    final cardColor = selected
        ? colors.accent.withValues(alpha: dark ? 0.18 : 0.08)
        : colors.solid;

    return ZolnitCard(
      color: cardColor,
      corner: skin.tileCorner,
      side: selected
          ? BorderSide(color: colors.accent.withValues(alpha: 0.4))
          : null,
      padding: EdgeInsets.zero,
      child: InkWell(
        customBorder: AppShape.all(skin.tileCorner),
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: skin.desktop ? 20 : 18,
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ZolnitFlagBadge(
                    flag: node.flag,
                    label: node.region,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node.region,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(context, 11, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in node.tags) ZolnitPill(label: tag),
                  ZolnitPill(label: l10n.zolnitNodeMultiplier(node.rateText)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  GlyphIcon(AppGlyphs.bolt, size: 14, color: delayColor),
                  const SizedBox(width: 5),
                  Text(
                    delayLabel,
                    style: zolnitText(
                      context,
                      11,
                      weight: FontWeight.w500,
                      color: delayColor,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.accent,
                        shape: AppShape.full,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlyphIcon(
                              AppGlyphs.check,
                              size: 12,
                              color: dark ? colors.paper : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.selected,
                              style: zolnitText(
                                context,
                                11,
                                weight: FontWeight.w600,
                                color: dark ? colors.paper : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
