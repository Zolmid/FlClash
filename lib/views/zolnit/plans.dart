import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';
import 'kit.dart';
import 'skin.dart';

const _periodKeys = <String>[
  'month_price',
  'quarter_price',
  'half_year_price',
  'year_price',
  'two_year_price',
  'three_year_price',
  'onetime_price',
  'reset_price',
];

const _periodMonths = <String, int>{
  'month_price': 1,
  'quarter_price': 3,
  'half_year_price': 6,
  'year_price': 12,
  'two_year_price': 24,
  'three_year_price': 36,
};

String _periodLabel(BuildContext context, String key) {
  final text = context.appLocalizations;
  return switch (key) {
    'month_price' => text.zolnitMonthly,
    'quarter_price' => text.zolnitQuarterly,
    'half_year_price' => text.zolnitHalfYearly,
    'year_price' => text.zolnitYearly,
    'two_year_price' => text.zolnitTwoYearly,
    'three_year_price' => text.zolnitThreeYearly,
    'onetime_price' => text.zolnitOneTime,
    _ => text.zolnitResetTraffic,
  };
}

String _cycleNoun(BuildContext context, String key) {
  final text = context.appLocalizations;
  return switch (key) {
    'quarter_price' => text.zolnitCycleQuarter,
    'half_year_price' => text.zolnitCycleHalfYear,
    'year_price' => text.zolnitCycleYear,
    'two_year_price' => text.zolnitCycleTwoYears,
    _ => text.zolnitCycleThreeYears,
  };
}

String _trimmed(num value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

class ZolnitPlansPage extends StatefulWidget {
  const ZolnitPlansPage({
    super.key,
    required this.session,
    required this.onOrderCreated,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final VoidCallback onOrderCreated;
  final bool compact;

  @override
  State<ZolnitPlansPage> createState() => _ZolnitPlansPageState();
}

class _ZolnitPlansPageState extends State<ZolnitPlansPage> {
  String? _chosen;
  Object? _quoteContext;
  int _quoteRequest = 0;
  bool _quoteLoading = false;
  String? _quoteFailure;
  Map<int, String> _quoteErrors = const {};
  Map<int, Map<int, RecurringPlanQuote>> _quotes = const {};
  Timer? _quoteExpiry;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _syncQuotes();
  }

  @override
  void didUpdateWidget(ZolnitPlansPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(_sessionChanged);
      widget.session.addListener(_sessionChanged);
      _quoteContext = null;
      _syncQuotes();
    }
  }

  String? _selectedPeriod(List<ZolnitPlan> plans) {
    final periods = [
      for (final key in _periodKeys)
        if (plans.any((plan) => plan.prices.containsKey(key))) key,
    ];
    return periods.contains(_chosen) ? _chosen : periods.firstOrNull;
  }

  Object _context() {
    final session = widget.session;
    final plans = session.planList;
    return (
      session,
      session.accountGeneration,
      session.api.generation,
      session.quoteRevision,
      session.authenticated,
      _selectedPeriod(plans),
      plans,
      session.recurringMethods.map((method) => method['id']).join(','),
    );
  }

  bool _currentQuote(int request, Object context) =>
      mounted &&
      _quoteRequest == request &&
      _quoteContext == context &&
      _context() == context;

  void _sessionChanged() {
    if (mounted) setState(_syncQuotes);
  }

  void _syncQuotes({bool refresh = false}) {
    final context = _context();
    if (!refresh && context == _quoteContext) return;
    _quoteContext = context;
    final request = ++_quoteRequest;
    _quoteExpiry?.cancel();
    _quoteExpiry = null;
    _quotes = const {};
    _quoteErrors = const {};
    _quoteFailure = null;
    final period =
        recurringPeriodsByPrice[_selectedPeriod(widget.session.planList)];
    _quoteLoading =
        widget.session.authenticated &&
        widget.session.checkout.allowStripe &&
        period != null;
    if (_quoteLoading) {
      scheduleMicrotask(() => _loadQuotes(request, context, period!, refresh));
    }
  }

  Future<void> _loadQuotes(
    int request,
    Object context,
    String period,
    bool refresh,
  ) async {
    final session = widget.session;
    try {
      await session.ensureRecurringOptions();
      if (!_currentQuote(request, context)) return;
      final methods = session.recurringMethods;
      if (methods.isEmpty) {
        setState(() {
          _quoteLoading = false;
          _quoteFailure = session.billingFailure;
        });
        return;
      }
      Future<({int id, Map<int, RecurringPlanQuote> quotes, String? error})>
      load(Json method) async {
        final id = method['id'] as int;
        try {
          final quotes = await session.quotePlans(
            paymentId: id,
            period: period,
            refresh: refresh,
          );
          return (id: id, quotes: quotes, error: null);
        } catch (error) {
          return (
            id: id,
            quotes: <int, RecurringPlanQuote>{},
            error: error is ClientFailure ? error.code : 'quote_unavailable',
          );
        }
      }

      final results = await Future.wait(methods.map(load));
      if (!_currentQuote(request, context)) return;
      setState(() {
        _quoteLoading = false;
        _quotes = {for (final result in results) result.id: result.quotes};
        _quoteErrors = {for (final result in results) result.id: ?result.error};
      });
      final expirations = [
        for (final result in results)
          for (final option in result.quotes.values)
            if (option.quote case final quote?)
              quote.terms['quote_expires_at'] as int,
      ];
      if (expirations.isNotEmpty) {
        final earliest = expirations.reduce((a, b) => a < b ? a : b);
        final remaining =
            earliest * 1000 - DateTime.now().millisecondsSinceEpoch;
        _quoteExpiry = Timer(
          Duration(milliseconds: remaining > 0 ? remaining : 0),
          () {
            if (_currentQuote(request, context)) {
              setState(() {
                _quotes = const {};
                _quoteFailure = 'recurring_quote_expired';
              });
            }
          },
        );
      }
    } catch (error) {
      if (_currentQuote(request, context)) {
        setState(() {
          _quoteLoading = false;
          _quoteFailure = error is ClientFailure
              ? error.code
              : 'quote_unavailable';
        });
      }
    }
  }

  void _retryQuotes() => setState(() => _syncQuotes(refresh: true));

  @override
  void dispose() {
    _quoteRequest++;
    _quoteExpiry?.cancel();
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _monthly(int planId, int paymentId) async {
    final session = widget.session;
    final generation = session.api.generation;
    final trade = await session.createMonthlyOrder(
      planId: planId,
      paymentId: paymentId,
    );
    if (trade == null || !mounted || session.api.generation != generation) {
      return;
    }
    widget.onOrderCreated();
    await session.payOrder(trade, paymentId);
  }

  Future<void> _create(ZolnitPlan plan, String period) async {
    final text = context.appLocalizations;
    final session = widget.session;
    final generation = session.api.generation;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.zolnitBuy),
        content: Text('${plan.name} · ${zolnitMoney(plan.prices[period])}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.confirm),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || session.api.generation != generation) {
      return;
    }
    final tradeNo = await session.createOrder(planId: plan.id!, period: period);
    if (tradeNo != null && mounted && session.api.generation == generation) {
      widget.onOrderCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final session = widget.session;
    final plans = session.planList;
    final usage = session.usage;
    final periods = [
      for (final key in _periodKeys)
        if (plans.any((plan) => plan.prices.containsKey(key))) key,
    ];
    final period = _selectedPeriod(plans);
    final visiblePlans = plans
        .where((plan) => period != null && plan.prices.containsKey(period))
        .toList();
    final quoteRequest = _quoteRequest;
    final quoteContext = _quoteContext;

    final saving = <String, int>{
      for (final key in periods)
        if (plans
                .map((plan) => plan.savingPercent(key) ?? 0)
                .fold(0, (best, value) => value > best ? value : best)
            case final percent when percent > 0)
          key: percent,
    };
    final currentName = usage != null && usage.hasPlan
        ? usage.planName ??
              plans.where((plan) => plan.id == usage.planId).firstOrNull?.name
        : null;
    final expires = usage?.expiresAt;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = zolnitPagePadding(skin, compact: widget.compact);
        final columns =
            skin.desktop &&
                !widget.compact &&
                constraints.maxWidth - padding.horizontal >= 900
            ? 3
            : 1;
        final cards = [
          for (final (index, plan) in visiblePlans.indexed)
            _PlanCard(
              key: ValueKey((
                session.accountGeneration,
                session.api.generation,
                period,
                plan.id,
              )),
              plan: plan,
              index: index,
              period: period,
              current:
                  usage != null && plan.id != null && plan.id == usage.planId,
              equalHeight: columns > 1,
              session: session,
              onBuy: period == null ? null : () => _create(plan, period),
              onMonthly: _monthly,
              onOrders: widget.onOrderCreated,
              quoteLoading: _quoteLoading,
              quoteFailure: _quoteFailure,
              quoteErrors: _quoteErrors,
              quotes: {
                for (final entry in _quotes.entries)
                  entry.key: ?entry.value[plan.id],
              },
              quoteCurrent: () =>
                  quoteContext != null &&
                  _currentQuote(quoteRequest, quoteContext),
              onQuoteRetry: _retryQuotes,
            ),
        ];
        final Widget grid;
        if (columns == 1) {
          grid = Column(
            children: [
              for (final (index, card) in cards.indexed) ...[
                if (index > 0) const SizedBox(height: 25),
                card,
              ],
            ],
          );
        } else {
          grid = Column(
            children: [
              for (var start = 0; start < cards.length; start += columns) ...[
                if (start > 0) const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: 20),
                        Expanded(
                          child: start + i < cards.length
                              ? cards[start + i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        return ListView(
          padding: padding,
          children: [
            ZolnitPageHeading(
              title: text.zolnitPlansHeadline,
              subtitle: text.zolnitPlansSub,
            ),
            SizedBox(height: skin.desktop ? 24 : 22),
            _CurrentBanner(
              line: currentName == null
                  ? null
                  : text.zolnitCurrentPlanLine(currentName),
              hint: currentName == null
                  ? text.zolnitNoCurrentPlanHint
                  : expires == null
                  ? null
                  : text.zolnitCurrentPlanHint(zolnitDotDate(expires)),
              onOrders: widget.onOrderCreated,
            ),
            const SizedBox(height: 24),
            if (periods.length > 1)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _BillingTabs(
                    periods: periods,
                    selected: period,
                    saving: saving,
                    onSelected: (key) => setState(() {
                      _chosen = key;
                      _syncQuotes();
                    }),
                  ),
                ),
              ),
            SizedBox(height: periods.length > 1 ? 30 : 12),
            if (visiblePlans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    text.zolnitNoPlan,
                    style: zolnitText(context, 13, color: colors.muted),
                  ),
                ),
              )
            else
              grid,
            const SizedBox(height: 18),
            if (!session.checkout.allowStripe)
              Text(
                text.zolnitPaymentUnavailable,
                style: zolnitText(context, 12, color: colors.muted),
              ),
            ZolnitFailureMessage(
              code: session.failure,
              serverMessage: session.failureMessage,
            ),
            if (session.billingFailure != null)
              Text(
                zolnitFailureText(
                  context,
                  session.billingFailure,
                  session.billingFailureMessage,
                  fallback: text.zolnitBillingUnavailable,
                ),
                style: zolnitText(
                  context,
                  12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurrentBanner extends StatelessWidget {
  const _CurrentBanner({
    required this.line,
    required this.hint,
    required this.onOrders,
  });

  final String? line;
  final String? hint;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final (fill, side, corner) = switch (skin) {
      ZolnitSkin.macos => (colors.sage, _sageEdge(colors), 15.0),
      ZolnitSkin.windows => (colors.sage, _sageEdge(colors), 8.0),
      ZolnitSkin.linux => (colors.sage, _sageEdge(colors), 7.0),
      ZolnitSkin.ios => (colors.solid, zolnitHairline(skin, colors), 20.0),
      ZolnitSkin.android => (colors.sage, BorderSide.none, 28.0),
    };
    final phone = !skin.desktop;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: skin == ZolnitSkin.android
            ? 22
            : phone
            ? 20
            : 23,
        vertical: 20,
      ),
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppRadius.all(corner),
          side: side,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line != null)
                  Text(
                    line!,
                    style: zolnitText(context, 14, weight: FontWeight.w700),
                  ),
                if (line != null && hint != null) const SizedBox(height: 6),
                if (hint != null)
                  Text(
                    hint!,
                    style: zolnitText(
                      context,
                      12,
                      leading: 17,
                      color: colors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            customBorder: AppShape.sm,
            onTap: onOrders,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text.zolnitOrders,
                    style: zolnitText(
                      context,
                      12,
                      weight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GlyphIcon(
                    AppGlyphs.chevronForward,
                    size: 16,
                    color: colors.ink,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BorderSide _sageEdge(ZolnitColors colors) => BorderSide(
  color: Color.alphaBlend(colors.ink.withValues(alpha: 0.06), colors.sage),
);

class _BillingTabs extends StatelessWidget {
  const _BillingTabs({
    required this.periods,
    required this.selected,
    required this.saving,
    required this.onSelected,
  });

  final List<String> periods;
  final String? selected;
  final Map<String, int> saving;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final (
      track,
      side,
      corner,
      inset,
      height,
      fill,
      tabCorner,
      pad,
    ) = switch (skin) {
      ZolnitSkin.macos => (
        colors.blue.withValues(alpha: 0.6),
        BorderSide(color: colors.line(0.063)),
        10.0,
        3.0,
        32.0,
        colors.solid,
        7.0,
        18.0,
      ),
      ZolnitSkin.windows => (
        Colors.transparent,
        BorderSide.none,
        0.0,
        3.0,
        37.0,
        Colors.transparent,
        0.0,
        12.0,
      ),
      ZolnitSkin.linux => (
        colors.solid,
        BorderSide(color: colors.line()),
        5.0,
        0.0,
        36.0,
        colors.accent,
        0.0,
        20.0,
      ),
      ZolnitSkin.ios => (
        colors.isDark ? colors.soft : const Color(0xffe4e8e7),
        BorderSide.none,
        13.0,
        3.0,
        44.0,
        colors.solid,
        10.0,
        16.0,
      ),
      ZolnitSkin.android => (
        Colors.transparent,
        BorderSide(color: colors.ink.withValues(alpha: 0.4)),
        28.0,
        0.0,
        48.0,
        colors.blue,
        0.0,
        18.0,
      ),
    };
    final onAccent = skin == ZolnitSkin.linux;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(inset),
      decoration: ShapeDecoration(
        color: track,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppRadius.all(corner),
          side: side,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final key in periods)
            Semantics(
              button: true,
              selected: key == selected,
              child: Material(
                color: key == selected ? fill : Colors.transparent,
                shape: AppShape.all(tabCorner),
                child: InkWell(
                  customBorder: AppShape.all(tabCorner),
                  onTap: () => onSelected(key),
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: pad),
                          child: Center(
                            widthFactor: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _periodLabel(context, key),
                                    maxLines: 1,
                                    style: zolnitText(
                                      context,
                                      12,
                                      weight: FontWeight.w600,
                                      color: key == selected
                                          ? (onAccent
                                                ? Colors.white
                                                : colors.ink)
                                          : colors.muted,
                                    ),
                                  ),
                                ),
                                if (saving[key] != null) ...[
                                  const SizedBox(width: 6),
                                  DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: skin == ZolnitSkin.android
                                          ? colors.solid
                                          : colors.soft,
                                      shape: AppShape.all(4),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      child: Text(
                                        text.zolnitSavePercent(saving[key]!),
                                        maxLines: 1,
                                        style: zolnitText(
                                          context,
                                          11,
                                          leading: 13,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (skin == ZolnitSkin.windows && key == selected)
                          PositionedDirectional(
                            start: pad,
                            end: pad,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: colors.accent,
                                shape: AppShape.full,
                              ),
                              child: const SizedBox(height: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.index,
    required this.period,
    required this.current,
    required this.equalHeight,
    required this.session,
    required this.onBuy,
    required this.onMonthly,
    required this.onOrders,
    required this.quoteLoading,
    required this.quoteFailure,
    required this.quoteErrors,
    required this.quotes,
    required this.quoteCurrent,
    required this.onQuoteRetry,
  });

  final ZolnitPlan plan;
  final int index;
  final String? period;
  final bool current;
  final bool equalHeight;
  final ZolnitSessionController session;
  final VoidCallback? onBuy;
  final Future<void> Function(int planId, int paymentId) onMonthly;
  final VoidCallback onOrders;
  final bool quoteLoading;
  final String? quoteFailure;
  final Map<int, String> quoteErrors;
  final Map<int, RecurringPlanQuote> quotes;
  final bool Function() quoteCurrent;
  final VoidCallback onQuoteRetry;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final dark = colors.isDark;
    final phone = !skin.desktop;
    final price = period == null ? null : plan.prices[period];
    final recurring = period != null && _periodMonths.containsKey(period);
    final months = _periodMonths[period] ?? 1;
    final bigPrice = price == null
        ? '—'
        : _trimmed(recurring ? price / months / 100 : price / 100);
    final note = switch (period) {
      null || 'onetime_price' || 'reset_price' => null,
      'month_price' => text.zolnitBilledMonthly,
      final key =>
        price == null
            ? null
            : text.zolnitBilledOnce(
                zolnitMoney(price),
                _cycleNoun(context, key),
              ),
    };
    final lines = plan.contentLines;
    final subtitle = plan.tagline ?? plan.badge ?? lines.firstOrNull;
    final gb = plan.transferGb;
    final features = plan.features.isNotEmpty
        ? [?plan.allowance, ...plan.features]
        : [
            if (gb != null)
              text.zolnitFeatureTraffic(_trimmed(gb, decimals: 1)),
            if (plan.deviceLimit != null)
              text.zolnitFeatureDevices(plan.deviceLimit!),
            if (plan.speedLimitMbps != null)
              text.zolnitFeatureSpeed(plan.speedLimitMbps!),
            ...lines.skip(1),
          ];
    final (name, nameWeight, priceSize, priceWeight) = switch (skin) {
      ZolnitSkin.macos ||
      ZolnitSkin.windows => (17.0, FontWeight.w600, 36.0, FontWeight.w500),
      ZolnitSkin.linux => (17.0, FontWeight.w700, 36.0, FontWeight.w700),
      ZolnitSkin.ios => (21.0, FontWeight.w600, 41.0, FontWeight.w600),
      ZolnitSkin.android => (21.0, FontWeight.w500, 42.0, FontWeight.w500),
    };
    final iconSize = switch (skin) {
      ZolnitSkin.macos => 37.0,
      ZolnitSkin.windows => 34.0,
      ZolnitSkin.linux => 30.0,
      ZolnitSkin.ios => 44.0,
      ZolnitSkin.android => 48.0,
    };
    final tints = [colors.sage, colors.blue, colors.lavender];
    final glyphs = [AppGlyphs.proxies, AppGlyphs.bolt, AppGlyphs.star];
    final canBuy =
        onBuy != null &&
        price != null &&
        plan.id != null &&
        !session.busy &&
        session.checkout.allowStripe;
    final methods = session.recurringMethods;
    final showQuotes =
        recurringPeriodsByPrice.containsKey(period) &&
        plan.id != null &&
        session.checkout.allowStripe &&
        (quoteLoading || quoteFailure != null || methods.isNotEmpty);
    final cardColor = !current
        ? colors.solid
        : skin == ZolnitSkin.android
        ? colors.blue
        : skin == ZolnitSkin.macos || skin == ZolnitSkin.windows
        ? Color.alphaBlend(colors.accent.withValues(alpha: 0.06), colors.solid)
        : colors.solid;
    final card = ZolnitCard(
      color: cardColor,
      side: current
          ? (skin == ZolnitSkin.android
                ? BorderSide.none
                : BorderSide(color: colors.accent))
          : null,
      padding: switch (skin) {
        ZolnitSkin.ios => const EdgeInsets.fromLTRB(25, 29, 25, 29),
        ZolnitSkin.android => const EdgeInsets.fromLTRB(26, 30, 26, 30),
        _ => const EdgeInsets.fromLTRB(22, 25, 22, 25),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: equalHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          ZolnitIconTile(
            glyph: glyphs[index % glyphs.length],
            tint: skin == ZolnitSkin.linux
                ? Colors.transparent
                : tints[index % tints.length],
            size: iconSize,
            iconSize: phone ? 22 : 18,
            color: colors.accent,
            corner: switch (skin) {
              ZolnitSkin.macos => 10,
              ZolnitSkin.windows => 6,
              ZolnitSkin.linux => 0,
              ZolnitSkin.ios => 13,
              ZolnitSkin.android => 18,
            },
          ),
          SizedBox(height: phone ? 22 : 17),
          Text(
            plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: zolnitText(
              context,
              name,
              leading: name * 1.4,
              weight: nameWeight,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: zolnitText(context, 11, leading: 20, color: colors.muted),
            ),
          ],
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (price != null) ...[
                Text(
                  '¥',
                  style: zolnitText(context, 16, weight: FontWeight.w500),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  bigPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zolnitText(
                    context,
                    priceSize,
                    leading: priceSize * 1.2,
                    weight: priceWeight,
                  ),
                ),
              ),
              if (price != null && recurring) ...[
                const SizedBox(width: 5),
                Text(
                  text.zolnitPerMonth,
                  style: zolnitText(context, 11, color: colors.muted),
                ),
              ],
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 9),
            Text(note, style: zolnitText(context, 11, color: colors.muted)),
          ],
          const SizedBox(height: 23),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.line(phone ? 0.08 : 0.13)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 23),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, feature) in features.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: GlyphIcon(
                              AppGlyphs.check,
                              size: 14,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: zolnitText(
                                context,
                                phone ? 13 : 12,
                                leading: 20,
                                color: dark ? colors.ink : colors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (plan.note case final note?) ...[
            const SizedBox(height: 16),
            Text(
              note,
              style: zolnitText(context, 11, leading: 18, color: colors.muted),
            ),
          ],
          if (equalHeight) const Spacer() else const SizedBox(height: 28),
          const SizedBox(height: 14),
          ZolnitButton(
            expand: true,
            primary: current,
            label: current ? text.zolnitRenewCurrent : text.zolnitChoosePlan,
            glyph: AppGlyphs.arrowForward,
            onPressed: canBuy ? onBuy : null,
          ),
          if (showQuotes) ...[
            const SizedBox(height: 14),
            Text(
              period == 'month_price'
                  ? text.zolnitMonthlyEnrollment
                  : text.zolnitQuoteLabel,
              style: zolnitText(context, 11, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (methods.isEmpty)
              _QuoteDetails(
                session: session,
                name: '',
                option: null,
                loading: quoteLoading,
                error: quoteFailure,
                monthly: false,
                onAuthorize: null,
                onRetry: onQuoteRetry,
                onOrders: onOrders,
              ),
            for (final method in methods)
              _QuoteDetails(
                key: ValueKey(
                  period == 'month_price'
                      ? 'zolnit-monthly-${plan.id}-${method['id']}'
                      : 'zolnit-quote-$period-${plan.id}-${method['id']}',
                ),
                session: session,
                name: method['name'] is String
                    ? method['name'] as String
                    : text.unknown,
                option: quotes[method['id']],
                loading: quoteLoading,
                error: quoteFailure ?? quoteErrors[method['id']],
                monthly: period == 'month_price',
                onAuthorize: quoteCurrent()
                    ? () => onMonthly(plan.id!, method['id'] as int)
                    : null,
                onRetry: onQuoteRetry,
                onOrders: onOrders,
              ),
          ],
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        if (current)
          PositionedDirectional(
            top: -12,
            end: 22,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.accent,
                shape: AppShape.all(phone ? 14 : 7),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: phone ? 14 : 10,
                  vertical: phone ? 7 : 5,
                ),
                child: Text(
                  text.zolnitCurrentBadge,
                  style: zolnitText(
                    context,
                    phone ? 11 : 10,
                    leading: 14,
                    weight: FontWeight.w600,
                    color: dark ? colors.paper : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuoteDetails extends StatelessWidget {
  const _QuoteDetails({
    super.key,
    required this.session,
    required this.name,
    required this.option,
    required this.loading,
    required this.error,
    required this.monthly,
    required this.onAuthorize,
    required this.onRetry,
    required this.onOrders,
  });

  final ZolnitSessionController session;
  final String name;
  final RecurringPlanQuote? option;
  final bool loading;
  final String? error;
  final bool monthly;
  final VoidCallback? onAuthorize;
  final VoidCallback onRetry;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final quote = option?.quote;
    final reason = option?.unavailableReason;
    final code =
        error ??
        switch (reason) {
          'pending_order' ||
          'unpaid_order' ||
          'has_unpaid_orders' => 'pending_order',
          'active_subscription' ||
          'existing_subscription' ||
          'checkout_exists' => 'checkout_exists',
          _ => quote == null ? 'recurring_unavailable' : null,
        };
    final unavailable =
        error == 'recurring_quote_expired' || error == 'quote_expired'
        ? text.zolnitQuoteExpired
        : code == 'pending_order' || code == 'checkout_exists'
        ? zolnitFailureText(context, code, null)
        : text.zolnitQuoteUnavailable;
    String amount(String key, String currency) => NumberFormat.currency(
      name: currency,
      symbol: currency == 'CNY' ? '¥' : currency,
    ).format((quote!.terms[key] as int) / 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          if (name.isNotEmpty)
            Text(name, style: zolnitText(context, 11, weight: FontWeight.w600)),
          if (loading)
            Text(
              text.loading,
              style: zolnitText(context, 11, color: colors.muted),
            )
          else if (code != null) ...[
            Text(
              unavailable,
              style: zolnitText(context, 11, color: colors.muted),
            ),
            Wrap(
              children: [
                TextButton(onPressed: onRetry, child: Text(text.retry)),
                if (code == 'pending_order' || code == 'checkout_exists')
                  TextButton(
                    onPressed: onOrders,
                    child: Text(text.zolnitOrders),
                  ),
              ],
            ),
          ] else if (quote != null) ...[
            Text(
              '${text.zolnitFirstCharge}: ${amount('first_total_cents', 'CNY')} / ${amount('first_charge_amount_cents', 'SGD')}',
              style: zolnitText(context, 11, color: colors.muted),
            ),
            Text(
              '${text.zolnitFollowingCharge}: ${amount('total_cents', 'CNY')} / ${amount('charge_amount_cents', 'SGD')}',
              style: zolnitText(context, 11, color: colors.muted),
            ),
            if (monthly)
              TextButton(
                onPressed: !session.busy && quote.validAt(DateTime.now())
                    ? onAuthorize
                    : null,
                child: Text(text.zolnitAuthorizeMonthly),
              ),
          ],
        ],
      ),
    );
  }
}
