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
import 'apple_plans.dart';

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
    required this.onManageRenewals,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final VoidCallback onOrderCreated;
  final VoidCallback onManageRenewals;
  final bool compact;

  @override
  State<ZolnitPlansPage> createState() => _ZolnitPlansPageState();
}

class _ZolnitPlansPageState extends State<ZolnitPlansPage>
    with WidgetsBindingObserver {
  String? _chosen;
  int? _selectedPlanId;
  Object? _quoteContext;
  int _quoteRequest = 0;
  bool _quoteLoading = false;
  String? _quoteFailure;
  Map<int, String> _quoteErrors = const {};
  Map<int, Map<int, RecurringPlanQuote>> _quotes = const {};
  Timer? _quoteExpiry;
  Timer? _quoteRetry;
  int _quoteRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _foreground &&
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
    _quoteRetry?.cancel();
    if (!refresh) _quoteRetries = 0;
    _quoteExpiry = null;
    _quotes = const {};
    _quoteErrors = const {};
    _quoteFailure = null;
    final period = _selectedPeriod(widget.session.planList) == 'month_price'
        ? 'monthly'
        : null;
    _quoteLoading =
        widget.session.authenticated &&
        widget.session.api.distribution != 'apple-app-store' &&
        widget.session.checkout.allowStripe &&
        period != null;
    if (_quoteLoading && _foreground) {
      scheduleMicrotask(() => _loadQuotes(request, context, period!, refresh));
    }
  }

  Future<void> _loadQuotes(
    int request,
    Object context,
    String period,
    bool refresh,
  ) async {
    if (!_currentQuote(request, context)) return;
    final session = widget.session;
    try {
      if (refresh && session.recurringMethods.isEmpty) {
        await session.refreshRecurringOptions();
      } else {
        await session.ensureRecurringOptions();
      }
      if (!_currentQuote(request, context)) return;
      final methods = session.recurringMethods;
      if (methods.isEmpty) {
        setState(() {
          _quoteLoading = false;
          _quoteFailure = session.billingFailure;
        });
        if (_quoteFailure != null) _scheduleRetry(request, context);
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
      if (_quoteErrors.isNotEmpty) _scheduleRetry(request, context);
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
            if (_currentQuote(request, context) && _foreground) {
              _retryQuotes();
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
        _scheduleRetry(request, context);
      }
    }
  }

  void _retryQuotes() => setState(() => _syncQuotes(refresh: true));

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _scheduleRetry(int request, Object context) {
    if (!_foreground || !widget.session.authenticated) return;
    _quoteRetries = (_quoteRetries + 1).clamp(0, 4);
    _quoteRetry?.cancel();
    _quoteRetry = Timer(Duration(seconds: 15 * (1 << _quoteRetries)), () {
      if (_foreground && _currentQuote(request, context)) _retryQuotes();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _retryQuotes();
    } else {
      _quoteRetry?.cancel();
      _quoteExpiry?.cancel();
    }
  }

  @override
  void dispose() {
    _quoteRequest++;
    _quoteExpiry?.cancel();
    _quoteRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${plan.name} · ${zolnitMoney(plan.prices[period])}'),
              const SizedBox(height: 8),
              Text(
                '${_periodLabel(context, period)} · ${text.zolnitManualPayment}',
              ),
              if (plan.note case final note?) ...[
                const SizedBox(height: 12),
                Text(note),
              ],
            ],
          ),
        ),
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
    if (widget.session.api.distribution == 'apple-app-store') {
      return ZolnitApplePlansPage(
        session: widget.session,
        compact: widget.compact,
      );
    }
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

    final currentName = usage != null && usage.hasPlan
        ? usage.planName ??
              plans.where((plan) => plan.id == usage.planId).firstOrNull?.name
        : null;
    final expires = usage?.expiresAt;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = zolnitPagePadding(skin, compact: widget.compact);
        final selected =
            visiblePlans
                .where((plan) => plan.id == _selectedPlanId)
                .firstOrNull ??
            visiblePlans
                .where((plan) => plan.id == usage?.planId)
                .firstOrNull ??
            visiblePlans.firstOrNull;
        final options = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final plan in visiblePlans)
              Semantics(
                key: ValueKey('zolnit-plan-state-${plan.id}'),
                selected: plan.id == selected?.id,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: colors.solid,
                    shape: AppShape.lg,
                    child: InkWell(
                      key: ValueKey('zolnit-plan-option-${plan.id}'),
                      customBorder: AppShape.lg,
                      onTap: () => setState(() => _selectedPlanId = plan.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            GlyphIcon(
                              plan.id == selected?.id
                                  ? AppGlyphs.check
                                  : AppGlyphs.layers,
                              size: 20,
                              color: plan.id == selected?.id
                                  ? colors.accent
                                  : colors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: zolnitText(
                                      context,
                                      15,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  if (plan.allowance case final allowance?)
                                    Text(
                                      allowance,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: zolnitText(
                                        context,
                                        11,
                                        color: colors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              zolnitMoney(plan.prices[period]),
                              style: zolnitText(
                                context,
                                15,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        Widget details(ZolnitPlan plan) {
          final index = visiblePlans.indexOf(plan);
          return _PlanCard(
            key: ValueKey((
              session.accountGeneration,
              session.api.generation,
              plan.id,
            )),
            plan: plan,
            index: index,
            period: period,
            current:
                usage != null && plan.id != null && plan.id == usage.planId,
            equalHeight: false,
            session: session,
            onBuy: period == null ? null : () => _create(plan, period),
            onMonthly: _monthly,
            onOrders: widget.onOrderCreated,
            onManageRenewals: widget.onManageRenewals,
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
          );
        }

        final wide = constraints.maxWidth - padding.horizontal >= 680;
        final grid = selected == null
            ? const SizedBox.shrink()
            : Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: !wide
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                children: [
                  Flexible(flex: wide ? 4 : 0, child: options),
                  SizedBox(width: wide ? 18 : 0, height: wide ? 0 : 8),
                  Flexible(flex: wide ? 5 : 0, child: details(selected)),
                ],
              );
        return ListView(
          padding: padding,
          children: [
            _CurrentBanner(
              line: currentName == null
                  ? null
                  : text.zolnitCurrentPlanLine(currentName),
              hint: expires == null
                  ? null
                  : text.zolnitCurrentPlanHint(zolnitDotDate(expires)),
              onOrders: widget.onOrderCreated,
            ),
            const SizedBox(height: 12),
            if (periods.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final key in periods)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(context, key)),
                          selected: period == key,
                          onSelected: (_) => setState(() {
                            _chosen = key;
                            _syncQuotes();
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
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
        vertical: 12,
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
    required this.onManageRenewals,
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
  final VoidCallback onManageRenewals;
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
    final totalPrice = price == null ? '—' : _trimmed(price / 100);
    final perMonthPrice = price == null || !recurring || months <= 1
        ? null
        : _trimmed(price / months / 100);
    final note = switch (period) {
      null || 'onetime_price' || 'reset_price' => null,
      'month_price' => text.zolnitManualPayment,
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
    const name = 18.0;
    const nameWeight = FontWeight.w600;
    const priceSize = 30.0;
    const priceWeight = FontWeight.w600;
    final canBuy =
        onBuy != null &&
        price != null &&
        plan.id != null &&
        !session.busy &&
        session.checkout.allowStripe;
    final methods = session.recurringMethods;
    final showQuotes =
        period == 'month_price' &&
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: equalHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
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
          const SizedBox(height: 12),
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
                  totalPrice,
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
            ],
          ),
          const SizedBox(height: 6),
          if (perMonthPrice != null)
            Text(
              '≈ ¥$perMonthPrice ${text.zolnitPerMonth}',
              style: zolnitText(context, 12, color: colors.muted),
            ),
          if (note != null)
            Padding(
              padding: EdgeInsets.only(top: perMonthPrice != null ? 4 : 0),
              child: Text(
                note,
                style: zolnitText(context, 11, color: colors.muted),
              ),
            ),
          const SizedBox(height: 12),
          if (features.isNotEmpty) ...[
            Text(
              features.take(3).join(' · '),
              style: zolnitText(context, 12, leading: 19, color: colors.muted),
            ),
            const SizedBox(height: 8),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(text.zolnitPlanDetails, style: zolnitText(context, 13)),
            trailing: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
            children: [
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      feature,
                      style: zolnitText(context, 12, color: colors.muted),
                    ),
                  ),
                ),
              if (plan.note case final note?)
                Text(note, style: zolnitText(context, 11, color: colors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          ZolnitButton(
            expand: true,
            primary: true,
            label: current ? text.zolnitRenewCurrent : text.zolnitChoosePlan,
            glyph: AppGlyphs.arrowForward,
            onPressed: canBuy ? onBuy : null,
          ),
          if (showQuotes) ...[
            const SizedBox(height: 14),
            Text(
              text.zolnitMonthlyEnrollment,
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
                onAuthorize: null,
                onRetry: onQuoteRetry,
                onOrders: onOrders,
                onManageRenewals: onManageRenewals,
              ),
            for (final method in methods)
              _QuoteDetails(
                key: ValueKey('zolnit-monthly-${plan.id}-${method['id']}'),
                session: session,
                name: zolnitSanitizedMethodName(context, method['name']),
                option: quotes[method['id']],
                loading: quoteLoading,
                error: quoteFailure ?? quoteErrors[method['id']],
                onAuthorize: quoteCurrent()
                    ? () => onMonthly(plan.id!, method['id'] as int)
                    : null,
                onRetry: onQuoteRetry,
                onOrders: onOrders,
                onManageRenewals: onManageRenewals,
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
    required this.onAuthorize,
    required this.onRetry,
    required this.onOrders,
    required this.onManageRenewals,
  });

  final ZolnitSessionController session;
  final String name;
  final RecurringPlanQuote? option;
  final bool loading;
  final String? error;
  final VoidCallback? onAuthorize;
  final VoidCallback onRetry;
  final VoidCallback onOrders;
  final VoidCallback onManageRenewals;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final quote = option?.quote;
    final reason = option?.unavailableReason;
    final code =
        error ?? reason ?? (quote == null ? 'recurring_unavailable' : null);
    final renewalOff =
        code == 'active_subscription' &&
        ZolnitRenewal.fromOverview(
          session.billingOverview,
        ).any((renewal) => renewal.state == RenewalState.disabled);
    final unavailable = renewalOff
        ? text.zolnitRenewalOffHint
        : error == 'recurring_quote_expired' || error == 'quote_expired'
        ? text.zolnitQuoteExpired
        : code == 'pending_order' ||
              code == 'active_subscription' ||
              code == 'checkout_exists'
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
                if (!const {
                  'active_subscription',
                  'pending_order',
                  'checkout_exists',
                }.contains(code))
                  TextButton(onPressed: onRetry, child: Text(text.retry)),
                if (code == 'pending_order')
                  TextButton(
                    onPressed: onOrders,
                    child: Text(text.zolnitOrders),
                  )
                else if (code == 'active_subscription' ||
                    code == 'checkout_exists')
                  TextButton(
                    onPressed: onManageRenewals,
                    child: Text(
                      code == 'active_subscription'
                          ? text.zolnitManageRenewals
                          : text.zolnitAccountTitle,
                    ),
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
