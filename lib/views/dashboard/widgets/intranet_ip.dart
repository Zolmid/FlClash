import 'dart:io' show NetworkInterface, InternetAddress;
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }
}

typedef _LanRowMetrics = ({
  EdgeInsets padding,
  double titleStart,
  double radius,
  double icon,
});

class IntranetIpCard extends ConsumerWidget {
  const IntranetIpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final mobile = !density.isDesktop;
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final localIp = ref.watch(localIpProvider);
    final allowLan = ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    );
    final port = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    final figure = mobile
        ? (style: AppTextStyle.title1, top: 12.0)
        : density.isCompact
        ? (style: AppTextStyle.title2, top: 8.0)
        : (style: AppTextStyle.title2, top: 10.0);
    final _LanRowMetrics row = density.isCompact
        ? (
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            titleStart: 12,
            radius: 16,
            icon: 32,
          )
        : (
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            titleStart: 14,
            radius: 20,
            icon: 38,
          );
    final style = DashboardText.figure(
      context,
      figure.style,
    ).copyWith(letterSpacing: 0);
    final address = localIp == null || localIp.isEmpty
        ? null
        : allowLan
        ? '$localIp:$port'
        : localIp;
    void change(bool value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(allowLan: value));
    return DashboardCard(
      semanticLabel: appLocalizations.intranetIP,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.devices,
            title: appLocalizations.intranetIP,
            trailing: [
              DashboardIconButton(
                glyph: AppGlyphs.chevronForward,
                tooltip: appLocalizations.details(appLocalizations.intranetIP),
                onPressed: () => dialogs.showCommonDialog<void>(
                  child: const _IntranetIpDialog(),
                ),
              ),
              Transform.translate(
                offset: const Offset(8, 0),
                child: DashboardIconButton(
                  glyph: AppGlyphs.copy,
                  tooltip: appLocalizations.copy,
                  onPressed: address == null
                      ? null
                      : () => copyToClipboard(context, address),
                ),
              ),
            ],
          ),
          SizedBox(height: figure.top),
          SizedBox(
            height: figure.style.leading * scale,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: switch (localIp) {
                null => SkeletonText(width: 120, style: style),
                '' => Text(
                  appLocalizations.noNetwork,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                final ip => DashboardFitText(ip, style: style),
              },
            ),
          ),
          if (mobile) const SizedBox(height: 14) else const Spacer(),
          LayoutBuilder(
            builder: (context, constraints) {
              final title = appLocalizations.allowLan;
              final showIcon = DashboardSwitchRow.iconFits(
                context,
                width: constraints.maxWidth,
                iconSize: row.icon,
                padding: row.padding,
                titles: [title],
              );
              return DashboardSwitchRow(
                glyph: AppGlyphs.wifi,
                title: title,
                subtitle: allowLan
                    ? appLocalizations.portValue(port)
                    : appLocalizations.disabled,
                value: allowLan,
                iconSize: row.icon,
                padding: showIcon
                    ? row.padding
                    : row.padding.copyWith(left: row.titleStart),
                radius: row.radius,
                showIcon: showIcon,
                onTap: () => change(!allowLan),
                onChanged: change,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IntranetIpDialog extends StatefulWidget {
  const _IntranetIpDialog();

  @override
  State<_IntranetIpDialog> createState() => _IntranetIpDialogState();
}

class _IntranetIpDialogState extends State<_IntranetIpDialog> {
  late final Future<List<NetworkInterface>> _future =
      getLocalNetworkInterfaces();

  Widget _buildItem(
    BuildContext context,
    String name,
    InternetAddress address,
    double nameWidth,
    TextStyle? nameStyle,
  ) {
    final ip = address.address;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: TooltipText(
              text: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TooltipText(
              text: Text(
                ip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTextStyle.body.of(context),
              ),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: context.appLocalizations.copy,
        icon: const GlyphIcon(AppGlyphs.copy, size: 14),
        onPressed: ip.isNotEmpty ? () => copyText(context, ip) : null,
      ),
    );
  }

  double _getMaxNameWidth(
    List<NetworkInterface> items,
    TextStyle? nameStyle,
    BoxConstraints constraints,
  ) {
    double maxWidth = 0;
    for (final interface in items) {
      final width = globalState.measure
          .computeTextSize(Text(interface.name, style: nameStyle))
          .width;
      if (width > maxWidth) {
        maxWidth = width;
      }
    }
    return min(maxWidth + 18, constraints.maxWidth * 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final nameStyle = AppTextStyle.body.of(context);
    return CommonDialog(
      title: appLocalizations.intranetIP,
      maxWidth: 480,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: FutureBuilder<List<NetworkInterface>>(
        future: _future,
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final items = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CommonCircleLoading()),
                );
              }
              if (items.isEmpty) {
                return Text(appLocalizations.noNetwork);
              }
              final nameWidth = _getMaxNameWidth(items, nameStyle, constraints);
              final children = <Widget>[];
              for (final interface in items) {
                if (children.isNotEmpty) {
                  children.add(const Divider(height: 0));
                }
                bool isFirst = true;
                for (final address in interface.sortedAddresses) {
                  children.add(
                    _buildItem(
                      context,
                      isFirst ? interface.name : '',
                      address,
                      nameWidth,
                      nameStyle,
                    ),
                  );
                  isFirst = false;
                }
              }
              return Column(mainAxisSize: MainAxisSize.min, children: children);
            },
          );
        },
      ),
    );
  }
}
