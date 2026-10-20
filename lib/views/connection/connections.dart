import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final TrackerInfoFilter initialFilter;
  final List<String> initialKeywords;
  final Future<List<TrackerInfo>> Function()? connectionsReader;

  const ConnectionsView({
    super.key,
    this.scrollController,
    this.initialKeywords = const [],
    this.initialFilter = const TrackerInfoFilter(),
    @visibleForTesting this.connectionsReader,
  });

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<ConnectionsView>,
        RouteMotionHoldMixin<ConnectionsView> {
  CoreController get _core => ref.read(coreHandlerProvider);

  final _listController = TrackerInfoListController();
  late TrackerInfoFilter _filter = widget.initialFilter;
  bool _showFilters = false;
  final _scaffoldKey = GlobalKey<CommonScaffoldState>();
  final _speedRanker = TrackerSpeedRanker();
  late final ScrollController _scrollController;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final keyword in widget.initialKeywords) {
        _scaffoldKey.currentState?.addKeyword(keyword);
      }
    });
    _scrollController =
        widget.scrollController ?? sheetScrollController(context);
  }

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  List<IconButtonData> _buildActions() {
    return [
      IconButtonData(
        glyph: AppGlyphs.filter,
        tooltip: context.appLocalizations.filter,
        isSelected: _showFilters || _filter.isNotEmpty,
        onPressed: () => setState(() => _showFilters = !_showFilters),
      ),
      IconButtonData(
        glyph: AppGlyphs.clearAll,
        tooltip: context.appLocalizations.closeConnections,
        onPressed: () async {
          unawaited(_core.closeConnections());
          await _refreshConnections();
        },
      ),
    ];
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final trackerInfos = await _readConnections();
    if (!isCurrent()) {
      return;
    }
    _showConnections(trackerInfos);
  }

  Future<void> _refreshConnections() async {
    final trackerInfos = await _readConnections();
    if (!mounted) {
      return;
    }
    _showConnections(trackerInfos);
  }

  Future<List<TrackerInfo>?> _readConnections() async {
    try {
      final connectionsReader = widget.connectionsReader;
      return connectionsReader != null
          ? await connectionsReader()
          : await _core.getConnections();
    } catch (error) {
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  void _showConnections(List<TrackerInfo>? trackerInfos) {
    final readAt = DateTime.now();
    if (!_loaded) {
      setState(() => _loaded = true);
      _applyConnections(trackerInfos, readAt);
      return;
    }
    updateWhenRouteSettled(() => _applyConnections(trackerInfos, readAt));
  }

  void _applyConnections(List<TrackerInfo>? trackerInfos, DateTime readAt) {
    if (trackerInfos == null) {
      return;
    }
    _listController.setTrackerInfos(_speedRanker.rank(trackerInfos, readAt));
  }

  Future<void> _handleBlockConnection(String id) async {
    await _core.closeConnection(id);
    await _refreshConnections();
  }

  @override
  void dispose() {
    _listController.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      key: _scaffoldKey,
      title: PageLabel.connections.label,
      onKeywordsUpdate: _listController.updateKeywords,
      searchState: AppBarSearchState(onSearch: _listController.search),
      iconActions: _buildActions(),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final connections = state.list.withTrackerFilter(_filter);
          final showFilters = _showFilters || _filter.isNotEmpty;
          Widget buildAction(TrackerInfo trackerInfo) {
            return _BlockConnectionButton(
              onPressed: () {
                _handleBlockConnection(trackerInfo.id);
              },
            );
          }

          final records = NullStatusSwitcher(
            isLoading: !_loaded,
            isEmpty: connections.isEmpty,
            isSearching: state.isSearching || _filter.isNotEmpty,
            nullStatus: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
              illustration: NullStatusIllustration.connections,
            ),
            child: RecordTableFrame<TrackerInfo>(
              tableId: 'connections',
              items: connections,
              columnsOf: (width) => trackerInfoColumns(
                context,
                width: width,
                isLive: true,
                actionBuilder: buildAction,
              ),
              builder: (context, table, connections) => TrackerInfoAnimatedList(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: showFilters ? 0 : context.contentTopPadding,
                  bottom: 16 + BottomInsetScope.of(context),
                ),
                trackerInfos: connections,
                table: table,
                detailTitle: appLocalizations.details(
                  appLocalizations.connection,
                ),
                actionBuilder: buildAction,
              ),
            ),
          );
          return Column(
            children: [
              if (showFilters)
                Padding(
                  padding: EdgeInsets.only(top: context.contentTopPadding),
                  child: TrackerInfoFilterBar(
                    visible: _showFilters,
                    trackerInfos: state.trackerInfos,
                    filter: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
              Expanded(child: records),
            ],
          );
        },
      ),
    );
  }
}

// One per live row: an IconButton would add a theme animation to each.
class _BlockConnectionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BlockConnectionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.appLocalizations.blockConnection,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onPressed,
          customBorder: AppShape.circle,
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: GlyphIcon(
                AppGlyphs.block,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
