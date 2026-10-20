import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';

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
    final density = DashboardDensityScope.of(context);
    return DashboardCard(
      semanticLabel: context.appLocalizations.goroutineInfo,
      child: Column(
        mainAxisSize: density.isDesktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.cpu,
            title: context.appLocalizations.goroutineInfo,
          ),
          const SizedBox(height: 16),
          Text(
            '$_count',
            style: DashboardText.figure(context, AppTextStyle.title1),
          ),
        ],
      ),
    );
  }
}
