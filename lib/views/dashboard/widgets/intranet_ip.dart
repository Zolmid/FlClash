import 'dart:io' show NetworkInterface, InternetAddress;
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntranetIP extends StatelessWidget {
  const IntranetIP({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 1),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        infoPadding: DashboardWidgetMetrics.paddingOf(
          context,
        ).copyWith(bottom: 0),
        info: Info(
          label: appLocalizations.intranetIP,
          glyph: AppGlyphs.devices,
        ),
        onPressed: () =>
            dialogs.showCommonDialog<void>(child: const _IntranetIpDialog()),
        child: Container(
          padding: DashboardWidgetMetrics.paddingOf(context).copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height:
                    globalState.measure.bodyMediumHeight *
                        DashboardWidgetMetrics.textScaleOf(context) +
                    2,
                child: Consumer(
                  builder: (_, ref, _) {
                    final localIp = ref.watch(localIpProvider);
                    return FadeThroughBox(
                      child: localIp != null
                          ? TooltipText(
                              text: Text(
                                localIp.isNotEmpty
                                    ? localIp
                                    : appLocalizations.noNetwork,
                                style: context.textTheme.bodyMedium?.toLight
                                    .adjustSize(1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(2),
                              child: const AspectRatio(
                                aspectRatio: 1,
                                child: CommonCircleLoading(),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
                style: context.textTheme.bodyMedium?.toLight,
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
    final nameStyle = context.textTheme.bodyMedium;
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
