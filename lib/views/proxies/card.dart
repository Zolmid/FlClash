import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/tracker_info_filter.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/connection/connections.dart';
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
    final lines = type == ProxyCardType.min ? 1 : 2;
    final style = context.textTheme.bodyMedium;
    return SizedBox(
      height: measure.bodyMediumHeight * lines,
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
    final delayText = _DelayText(proxy: proxy, testUrl: testUrl, type: type);
    final proxyNameText = _buildProxyNameText(context);
    return ContextMenuRegion(
      menuItems: _menuItems(context, ref),
      child: Stack(
        children: [
          Consumer(
            builder: (_, ref, child) {
              final selectedProxyName = ref.watch(
                selectedProxyNameProvider(groupName),
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
                isSelected: selectedProxyName == proxy.name,
                child: child!,
              );
            },
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  proxyNameText,
                  const SizedBox(height: 8),
                  if (type == ProxyCardType.expand) ...[
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: _ProxyDesc(proxy: proxy),
                    ),
                    const SizedBox(height: 6),
                    delayText,
                  ] else
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 1,
                            child: TooltipText(
                              text: Text(
                                proxy.type,
                                maxLines: 1,
                                style: context.textTheme.bodySmall?.copyWith(
                                  overflow: TextOverflow.ellipsis,
                                  color: context
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.opacity80,
                                ),
                              ),
                            ),
                          ),
                          delayText,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (groupType.isComputedSelected)
            Positioned(
              top: 0,
              right: 0,
              child: _ProxyComputedMark(groupName: groupName, proxy: proxy),
            ),
        ],
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
    final desc = ref.watch(proxyDescProvider(proxy));
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

class _DelayText extends ConsumerStatefulWidget {
  const _DelayText({
    required this.proxy,
    required this.testUrl,
    required this.type,
  });

  final Proxy proxy;
  final String? testUrl;
  final ProxyCardType type;

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
                shape: RoundedSuperellipseBorder(
                  borderRadius: AppRadius.xs,
                  side: BorderSide(
                    color: context.colorScheme.primary,
                    width: 2,
                  ),
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
          height: measure.labelSmallHeight,
          child: FadeBox(
            alignment: widget.type == ProxyCardType.expand
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: phase != null || delay == null
                ? SizedBox(
                    height: measure.labelSmallHeight,
                    width: measure.labelSmallHeight,
                    child: _withFocusRing(context, switch (phase) {
                      DelayTestPhase.running => const CommonCircleLoading(),
                      DelayTestPhase.queued => GlyphIcon(
                        AppGlyphs.clock,
                        size: measure.labelSmallHeight,
                        color: context.colorScheme.onSurfaceVariant.opacity38,
                      ),
                      null => IconButton(
                        tooltip: context.appLocalizations.delayTest,
                        icon: const GlyphIcon(AppGlyphs.bolt),
                        iconSize: measure.labelSmallHeight,
                        padding: EdgeInsets.zero,
                        onPressed: _handleTestCurrentDelay,
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
                        style: context.textTheme.labelSmall?.copyWith(
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

class _ProxyDesc extends ConsumerWidget {
  final Proxy proxy;

  const _ProxyDesc({required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(proxyDescProvider(proxy));
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textTheme.bodySmall?.color?.opacity80,
      ),
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;

  const _ProxyComputedMark({required this.groupName, required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(proxyNameProvider(groupName));
    if (proxyName != proxy.name) {
      return const SizedBox();
    }
    return Container(
      alignment: Alignment.topRight,
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: const SelectIcon(),
      ),
    );
  }
}
