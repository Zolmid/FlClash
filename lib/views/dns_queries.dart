import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/dns/dns_query_filter.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DnsQueryListController extends ValueNotifier<DnsQueriesState> {
  DnsQueryListController() : super(const DnsQueriesState());

  void search(String query) {
    value = value.copyWith(query: query);
  }

  void updateKeywords(List<String> keywords) {
    value = value.copyWith(keywords: keywords);
  }

  void setDnsQueries(List<DnsQuery> dnsQueries) {
    if (identical(dnsQueries, value.dnsQueries)) {
      return;
    }
    value = value.copyWith(
      dnsQueries: value.autoScrollToEnd
          ? dnsQueries
          : retainTrimmedHead(
              value.dnsQueries,
              dnsQueries,
              pausedMaxDnsQueriesLength,
            ),
    );
  }

  void setAutoScrollToEnd(bool autoScrollToEnd) {
    value = value.copyWith(autoScrollToEnd: autoScrollToEnd);
  }

  void resumeAutoScrollToEnd(List<DnsQuery> dnsQueries) {
    value = value.copyWith(autoScrollToEnd: true, dnsQueries: dnsQueries);
  }
}

class DnsQueriesView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final DnsQueryFilter initialFilter;

  const DnsQueriesView({
    super.key,
    this.scrollController,
    this.initialFilter = const DnsQueryFilter(),
  });

  @override
  ConsumerState<DnsQueriesView> createState() => _DnsQueriesViewState();
}

class _DnsQueriesViewState extends ConsumerState<DnsQueriesView>
    with RouteMotionHoldMixin<DnsQueriesView> {
  final _listController = DnsQueryListController();
  late DnsQueryFilter _filter = widget.initialFilter;
  bool _showFilters = false;
  late final ScrollController _scrollController;
  late final _physics = FollowEndScrollPhysics(
    isFollowing: () => _listController.value.autoScrollToEnd,
  );

  @override
  void initState() {
    super.initState();
    _scrollController =
        widget.scrollController ??
        sheetScrollController(context, initialScrollOffset: double.maxFinite);
    _listController.setDnsQueries(ref.read(dnsQueriesProvider).list);
    ref.listenManual(dnsQueriesProvider.select((state) => state.revision), (
      _,
      _,
    ) {
      _updateDnsQueriesThrottler();
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _updateDnsQueriesThrottler() {
    throttler.call(FunctionTag.dnsQueries, () {
      if (!mounted) {
        return;
      }
      updateWhenRouteSettled(
        () => _listController.setDnsQueries(ref.read(dnsQueriesProvider).list),
      );
    }, duration: renderThrottleDuration);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: PageLabel.dns.label,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.filter,
          tooltip: context.appLocalizations.filter,
          isSelected: _showFilters || _filter.isNotEmpty,
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        IconButtonData(
          glyph: AppGlyphs.send,
          tooltip: appLocalizations.queryDns,
          onPressed: ref.watch(coreStatusProvider) == CoreStatus.connected
              ? () => dialogs.showCommonDialog<void>(
                  child: DnsLookupDialog(
                    onQuery: ref.read(coreHandlerProvider).queryDns,
                  ),
                )
              : null,
        ),
      ],
      searchState: AppBarSearchState(onSearch: _listController.search),
      onKeywordsUpdate: _listController.updateKeywords,
      body: ValueListenableBuilder<DnsQueriesState>(
        valueListenable: _listController,
        builder: (context, state, _) {
          final dnsQueries = state.list.withDnsQueryFilter(_filter);
          final showFilters = _showFilters || _filter.isNotEmpty;
          return Column(
            children: [
              if (showFilters)
                Padding(
                  padding: EdgeInsets.only(top: context.contentTopPadding),
                  child: DnsQueryFilterBar(
                    visible: _showFilters,
                    dnsQueries: state.dnsQueries,
                    filter: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
              Expanded(
                child: NullStatusSwitcher(
                  isEmpty: dnsQueries.isEmpty,
                  isSearching: state.isSearching || _filter.isNotEmpty,
                  nullStatus: NullStatus(
                    label: appLocalizations.nullTip(
                      appLocalizations.dnsQueries,
                    ),
                    illustration: NullStatusIllustration.dns,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FloatingScrollbar(
                      controller: _scrollController,
                      hintBuilder: (fraction) {
                        final index = (fraction * (dnsQueries.length - 1))
                            .round();
                        return dnsQueries[index].time.showFull;
                      },
                      child: ScrollToEndBox(
                        controller: _scrollController,
                        enable: state.autoScrollToEnd,
                        onCancelToEnd: () {
                          _listController.setAutoScrollToEnd(false);
                        },
                        onResumeToEnd: () {
                          _listController.resumeAutoScrollToEnd(
                            ref.read(dnsQueriesProvider).list,
                          );
                        },
                        child: SuperListView.separated(
                          reverse: true,
                          shrinkWrap: true,
                          physics: _physics,
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: showFilters ? 0 : context.contentTopPadding,
                            bottom: 16 + BottomInsetScope.of(context),
                          ),
                          itemCount: dnsQueries.length,
                          extentEstimation: zeroDividerExtentEstimation,
                          separatorBuilder: (_, _) => const Divider(height: 0),
                          itemBuilder: (_, index) {
                            return DnsQueryItem(
                              dnsQuery: dnsQueries[index],
                              onClickKeyword: (value) {
                                context.commonScaffoldState?.addKeyword(value);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const dnsLookupTypes = [
  'A',
  'AAAA',
  'CNAME',
  'HTTPS',
  'MX',
  'TXT',
  'NS',
  'SRV',
];

class DnsLookupDialog extends StatefulWidget {
  final Future<DnsQuery> Function(String domain, String type) onQuery;

  const DnsLookupDialog({super.key, required this.onQuery});

  @override
  State<DnsLookupDialog> createState() => _DnsLookupDialogState();
}

class _DnsLookupDialogState extends State<DnsLookupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  String _type = dnsLookupTypes.first;
  bool _querying = false;
  String? _error;
  DnsQuery? _result;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_querying || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _querying = true;
      _error = null;
      _result = null;
    });
    try {
      final dnsQuery = await widget.onQuery(
        _domainController.text.trim(),
        _type,
      );
      if (mounted) {
        _result = dnsQuery;
      }
    } catch (error) {
      if (mounted) {
        _error = userFacingErrorMessage(error, context.appLocalizations);
      }
    } finally {
      if (mounted) {
        setState(() {
          _querying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final error = _error;
    final result = _result;
    return CommonDialog(
      title: appLocalizations.queryDns,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.close),
        ),
        _querying
            ? TextButton.icon(
                onPressed: null,
                icon: const SizedBox.square(
                  dimension: 18,
                  child: CommonCircleLoading(),
                ),
                label: Text(appLocalizations.query),
              )
            : TextButton(
                onPressed: _submit,
                child: Text(appLocalizations.query),
              ),
      ],
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              TextFormField(
                autofocus: true,
                enabled: !_querying,
                controller: _domainController,
                keyboardType: TextInputType.url,
                inputFormatters: TextInputLimits.limit(TextInputLimits.domain),
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: appLocalizations.domain),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return appLocalizations.emptyTip(appLocalizations.domain);
                  }
                  return null;
                },
              ),
              FilledButton.tonal(
                key: const ValueKey('dns-query-type'),
                onPressed: _querying
                    ? null
                    : () async {
                        final type = await dialogs.showCommonDialog<String>(
                          child: OptionsDialog<String>(
                            title: appLocalizations.recordType,
                            options: dnsLookupTypes,
                            textBuilder: (item) => item,
                            value: _type,
                          ),
                        );
                        if (mounted && type != null) {
                          setState(() => _type = type);
                        }
                      },
                child: Text(_type),
              ),
              if (error != null)
                Text(
                  error,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              if (result != null) ...[
                const Divider(),
                for (final (label, value) in [
                  (appLocalizations.domain, result.domain),
                  (appLocalizations.recordType, result.type),
                  (appLocalizations.answers, result.answers.join('\n')),
                  (appLocalizations.responseCode, result.rcode),
                  (appLocalizations.source, result.upstream),
                  (
                    appLocalizations.cache,
                    result.cached ? appLocalizations.yes : appLocalizations.no,
                  ),
                  (appLocalizations.delay, '${result.delay} ms'),
                  (appLocalizations.error, result.error),
                ])
                  if (value.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: context.textTheme.labelMedium),
                        SelectableText(
                          value,
                          style: label == appLocalizations.error
                              ? TextStyle(color: context.colorScheme.error)
                              : null,
                        ),
                      ],
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DnsQueryItem extends StatelessWidget {
  final DnsQuery dnsQuery;
  final ValueChanged<String>? onClickKeyword;

  const DnsQueryItem({super.key, required this.dnsQuery, this.onClickKeyword});

  void _showDetail(BuildContext context) {
    showInSheet<void>(
      context,
      builder: (_) {
        return CommonScaffold(
          body: DnsQueryDetailView(dnsQuery: dnsQuery),
          title: context.appLocalizations.details('DNS'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = RecordTextStyles.of(context);
    final tone = dnsQuery.isFailed ? RecordTone.error : RecordTone.neutral;
    final summary = dnsQuery.error.isNotEmpty
        ? dnsQuery.error
        : dnsQuery.answers.join(', ');
    return RecordListItem(
      tone: tone,
      onTap: () => _showDetail(context),
      header: RecordHeader(
        trailing: Text('${dnsQuery.delay} ms'),
        children: [
          RecordTimestamp(dnsQuery.time.showFull),
          RecordLabel(
            label: dnsQuery.type,
            onPressed: () => onClickKeyword?.call(dnsQuery.type),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            dnsQuery.domain,
            style: styles.primary?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (summary.isNotEmpty)
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: styles.secondary?.copyWith(
                color: tone.accentColor(context),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in dnsQuery.resultTags)
                RecordLabel(
                  label: tag,
                  tone: dnsQuery.hasFailureRcode && tag == dnsQuery.rcode
                      ? RecordTone.error
                      : RecordTone.neutral,
                  onPressed: () => onClickKeyword?.call(tag),
                ),
              if (dnsQuery.upstream.isNotEmpty)
                Text(dnsQuery.upstream, style: styles.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class DnsQueryDetailView extends StatelessWidget {
  final DnsQuery dnsQuery;

  const DnsQueryDetailView({super.key, required this.dnsQuery});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final entries = [
      (appLocalizations.time, dnsQuery.time.showFull),
      (appLocalizations.domain, dnsQuery.domain),
      (appLocalizations.recordType, dnsQuery.type),
      (appLocalizations.initiator, dnsQuery.initiator?.label ?? ''),
      (appLocalizations.source, dnsQuery.upstream),
      (
        appLocalizations.cache,
        dnsQuery.cached ? appLocalizations.yes : appLocalizations.no,
      ),
      (appLocalizations.responseCode, dnsQuery.rcode),
      (appLocalizations.delay, '${dnsQuery.delay} ms'),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(bottom: 20, top: context.contentTopPadding),
      children: [
        generateSectionV3(
          title: appLocalizations.basicInfo,
          items: [
            for (final (title, value) in entries)
              if (value.isNotEmpty) DetailRow.text(title: title, value: value),
          ],
        ),
        if (dnsQuery.error.isNotEmpty)
          generateSectionV3(
            title: appLocalizations.error,
            items: [_ErrorRow(error: dnsQuery.error)],
          ),
        if (dnsQuery.answers.isNotEmpty)
          generateSectionV3(
            title: appLocalizations.answers,
            items: [
              for (final answer in dnsQuery.answers)
                DetailRow(title: answer, copyText: answer),
            ],
          ),
      ],
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  context.showNotifier(context.appLocalizations.copySuccess);
}

class _ErrorRow extends StatelessWidget {
  final String error;

  const _ErrorRow({required this.error});

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      onPressed: () => _copy(context, error),
      minVerticalPadding: 14,
      title: Text(
        error,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.error,
        ),
      ),
    );
  }
}
