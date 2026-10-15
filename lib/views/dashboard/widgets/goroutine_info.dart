import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_card.dart';

class GoroutineInfo extends ConsumerStatefulWidget {
  const GoroutineInfo({super.key, @visibleForTesting this.countReader});

  final Future<int> Function()? countReader;

  @override
  ConsumerState<GoroutineInfo> createState() => _GoroutineInfoState();
}

class _GoroutineInfoState extends ConsumerState<GoroutineInfo>
    with WidgetsBindingObserver, ActivePollingMixin<GoroutineInfo> {
  int _count = 0;

  @override
  Duration get pollInterval => const Duration(seconds: 2);

  @override
  bool get canPoll =>
      super.canPoll &&
      (widget.countReader != null ||
          (ref.read(coreStatusProvider) == CoreStatus.connected &&
              (!system.isIOS ||
                  ref.read(tunnelStateProvider) != TunnelState.pending)));

  @override
  void initState() {
    super.initState();
    ref.listenManual(coreStatusProvider, (_, _) => _resetCount());
    if (system.isIOS) {
      ref.listenManual(tunnelStateProvider, (_, _) => _resetCount());
    }
  }

  void _resetCount() {
    setState(() => _count = 0);
    restartPolling();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    try {
      final read =
          widget.countReader ?? ref.read(coreHandlerProvider).getGoroutineCount;
      final count = await read();
      if (!isCurrent()) return;
      setState(() => _count = count);
    } catch (error) {
      commonPrint.log(
        'updateGoroutineCount error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 1),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        infoPadding: DashboardWidgetMetrics.paddingOf(
          context,
        ).copyWith(bottom: 0),
        info: Info(
          label: context.appLocalizations.goroutineInfo,
          glyph: AppGlyphs.cpu,
        ),
        child: Padding(
          padding: DashboardWidgetMetrics.paddingOf(context).copyWith(top: 0),
          child: FeedCount(count: _count),
        ),
      ),
    );
  }
}
