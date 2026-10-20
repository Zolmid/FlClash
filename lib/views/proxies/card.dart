import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/features/connection/tracker_info_filter.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/connection/connections.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void selectGroupProxy(
  WidgetRef ref, {
  required String groupName,
  required GroupType groupType,
  required String proxyName,
}) {
  final isComputedSelected = groupType.isComputedSelected;
  if (isComputedSelected || groupType == GroupType.Selector) {
    final currentProxyName = ref.read(proxyNameProvider(groupName));
    final nextProxyName = switch (isComputedSelected) {
      true => currentProxyName == proxyName ? '' : proxyName,
      false => proxyName,
    };
    ref
        .read(proxiesActionProvider.notifier)
        .changeProxyDebounce(groupName, nextProxyName);
    return;
  }
  dialogs.showNotifier(
    currentAppLocalizations.notSelectedTip,
    level: MessageLevel.warning,
  );
}

class ProxyCard extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  Measure get measure => globalState.measure;

  Widget _buildProxyNameText(BuildContext context) {
    final lines = type == ProxyCardType.compact ? 1 : 2;
    final style = AppTextStyle.subheadline.of(context);
    return SizedBox(
      height: measure.textHeight(AppTextStyle.subheadline) * lines,
      child: LayoutBuilder(
        builder: (context, constraints) => OverflowHoverTooltip(
          message: proxy.name,
          maxWidth: constraints.maxWidth,
          maxLines: lines,
          style: style,
          child: EmojiText(
            proxy.name,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );
  }

  List<CommonPopupMenuItem> _menuItems(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    return [
      CommonPopupMenuItem(
        glyph: AppGlyphs.bolt,
        label: l10n.delayTest,
        onPressed: () => ref
            .read(proxiesActionProvider.notifier)
            .proxyDelayTest(proxy, testUrl),
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.requests,
        label: l10n.recentRequests,
        onPressed: () => BaseNavigator.push<void>(
          context,
          RequestsView(initialFilter: TrackerInfoFilter(chains: {proxy.name})),
        ),
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.connections,
        label: l10n.connections,
        onPressed: () => BaseNavigator.push<void>(
          context,
          ConnectionsView(
            initialFilter: TrackerInfoFilter(chains: {proxy.name}),
          ),
        ),
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.info,
        label: l10n.details(l10n.proxy),
        onPressed: () => dialogs.showCommonDialog<void>(
          child: _ProxyDetailsDialog(proxy: proxy, testUrl: testUrl),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measure = globalState.measure;
    final isLoose = type == ProxyCardType.loose;
    final delayText = _DelayText(
      proxy: proxy,
      testUrl: testUrl,
      alignment: isLoose ? Alignment.centerLeft : Alignment.centerRight,
    );
    final proxyNameText = _buildProxyNameText(context);
    final typeStyle = AppTextStyle.footnote
        .of(context)
        .copyWith(
          overflow: TextOverflow.ellipsis,
          color: context.colorScheme.onSurface.opacity80,
        );
    final details = isLoose
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: measure.textHeight(AppTextStyle.footnote),
                child: _ProxyDesc(proxy: proxy, style: typeStyle),
              ),
              const SizedBox(height: 6),
              delayText,
            ],
          )
        : SizedBox(
            height: measure.textHeight(AppTextStyle.footnote),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 1,
                  child: TooltipText(
                    text: Text(proxy.type, maxLines: 1, style: typeStyle),
                  ),
                ),
                delayText,
              ],
            ),
          );
    return ContextMenuRegion(
      menuItems: _menuItems(context, ref),
      child: Consumer(
        builder: (context, ref, _) {
          final inUse = ref.watch(
            selectedProxyNameProvider(
              groupName,
            ).select((name) => name == proxy.name),
          );
          final pinned =
              groupType.isComputedSelected &&
              ref.watch(
                proxyNameProvider(
                  groupName,
                ).select((name) => name == proxy.name),
              );
          return CommonCard(
            radius: AppCorner.lg,
            enterActionsOnRight: true,
            key: key,
            onPressed: () {
              selectGroupProxy(
                ref,
                groupName: groupName,
                groupType: groupType,
                proxyName: proxy.name,
              );
            },
            isSelected: inUse,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Expanded(child: proxyNameText),
                      if (pinned)
                        SelectionBadge.preferred(inUse: inUse)
                      else if (inUse)
                        const SelectionBadge(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  details,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  const _ProxyDesc({required this.proxy, required this.style});

  final Proxy proxy;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = GroupType.values.any((type) => type.name == proxy.type);
    final nodeName = isGroup
        ? ref.watch(
            realSelectedProxyStateProvider(
              proxy.name,
            ).select((state) => state.proxyName),
          )
        : proxy.name;
    return EmojiText(
      nodeName == proxy.name ? proxy.type : '${proxy.type}($nodeName)',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _DelayText extends ConsumerStatefulWidget {
  const _DelayText({
    required this.proxy,
    required this.testUrl,
    required this.alignment,
  });

  final Proxy proxy;
  final String? testUrl;
  final Alignment alignment;

  @override
  ConsumerState<_DelayText> createState() => _DelayTextState();
}

class _DelayTextState extends ConsumerState<_DelayText> {
  final FocusNode _focusNode = SkipTraversalFocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final isFocused = _focusNode.hasPrimaryFocus;
    if (isFocused == _isFocused) {
      return;
    }
    setState(() {
      _isFocused = isFocused;
    });
  }

  void _handleTestCurrentDelay() {
    ref
        .read(proxiesActionProvider.notifier)
        .proxyDelayTest(widget.proxy, widget.testUrl);
  }

  Widget _withFocusRing(BuildContext context, Widget child) {
    if (!_isFocused) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -3,
          bottom: -2,
          left: -3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShape.xs.copyWith(
                  side: focusRingSide(context.colorScheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final measure = globalState.measure;
    final delay = ref.watch(
      delayProvider(proxyName: widget.proxy.name, testUrl: widget.testUrl),
    );
    final phase = ref.watch(
      delayTestPhaseProvider(
        proxyName: widget.proxy.name,
        testUrl: widget.testUrl,
      ),
    );
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTestCurrentDelay();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _focusNode,
        child: SizedBox(
          height: measure.textHeight(AppTextStyle.caption2),
          child: FadeBox(
            alignment: widget.alignment,
            child: phase != null || delay == null
                ? SizedBox(
                    height: measure.textHeight(AppTextStyle.caption2),
                    width: measure.textHeight(AppTextStyle.caption2),
                    child: _withFocusRing(context, switch (phase) {
                      DelayTestPhase.running => CommonCircleLoading(
                        size: measure.textHeight(AppTextStyle.caption2),
                      ),
                      DelayTestPhase.queued => GlyphIcon(
                        AppGlyphs.clock,
                        size: measure.textHeight(AppTextStyle.caption2),
                        color: context.colorScheme.onSurfaceVariant.opacity38,
                      ),
                      null => Tooltip(
                        message: context.appLocalizations.delayTest,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleTestCurrentDelay,
                          child: GlyphIcon(
                            AppGlyphs.bolt,
                            size: measure.textHeight(AppTextStyle.caption2),
                          ),
                        ),
                      ),
                    }),
                  )
                : GestureDetector(
                    onTap: _handleTestCurrentDelay,
                    child: _withFocusRing(
                      context,
                      Text(
                        delay > 0
                            ? '$delay ms'
                            : delayFailureText(delay, context.appLocalizations),
                        maxLines: 1,
                        style: AppTextStyle.caption2
                            .of(context, emphasized: true)
                            .copyWith(
                              overflow: TextOverflow.ellipsis,
                              color: context.colorScheme.delayColor(delay),
                            ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProxyDetailsDialog extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;

  const _ProxyDetailsDialog({required this.proxy, required this.testUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isGroup = GroupType.values.any((type) => type.name == proxy.type);
    final selectedName = isGroup
        ? ref.watch(realSelectedProxyStateProvider(proxy.name)).proxyName
        : proxy.name;
    final desc = selectedName == proxy.name
        ? proxy.type
        : '${proxy.type}($selectedName)';
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final pending = ref.watch(
      delayTestPhaseProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final features = [
      if (proxy.udp) 'UDP',
      if (proxy.uot) 'UoT',
      if (proxy.xudp) 'XUDP',
      if (proxy.tfo) 'TFO',
      if (proxy.mptcp) 'MPTCP',
      if (proxy.smux) 'SMUX',
    ];
    final items = <({String name, String value, bool copyable})>[
      (name: appLocalizations.name, value: proxy.name, copyable: true),
      (name: appLocalizations.proxyType, value: desc, copyable: false),
      if (pending == null && delay != null)
        (
          name: appLocalizations.delay,
          value: delay > 0 ? '$delay ms' : appLocalizations.timeout,
          copyable: false,
        ),
      if (proxy.providerName.isNotEmpty)
        (
          name: appLocalizations.proxyProvider,
          value: proxy.providerName,
          copyable: false,
        ),
      if (proxy.dialerProxy.isNotEmpty)
        (
          name: appLocalizations.dialerProxy,
          value: proxy.dialerProxy,
          copyable: false,
        ),
      if (proxy.interface.isNotEmpty)
        (
          name: appLocalizations.interfaceName,
          value: proxy.interface,
          copyable: false,
        ),
      if (proxy.routingMark != 0)
        (
          name: appLocalizations.routingMark,
          value: '${proxy.routingMark}',
          copyable: false,
        ),
      for (var index = 0; index < features.length; index++)
        (
          name: index == 0 ? appLocalizations.features : '',
          value: features[index],
          copyable: false,
        ),
    ];
    return CommonDialog(
      title: appLocalizations.details(appLocalizations.proxy),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.close),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            DetailRow.text(title: item.name, value: item.value),
        ],
      ),
    );
  }
}
