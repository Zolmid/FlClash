import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';
import 'skin.dart';
import 'kit.dart';

class ZolnitCashierPage extends StatefulWidget {
  const ZolnitCashierPage({
    super.key,
    required this.session,
    required this.tradeNo,
    required this.onClose,
  });

  final ZolnitSessionController session;
  final String tradeNo;
  final VoidCallback onClose;

  @override
  State<ZolnitCashierPage> createState() => _ZolnitCashierPageState();
}

class _ZolnitCashierPageState extends State<ZolnitCashierPage> {
  int? _methodId;
  bool _details = false;
  bool _cancelling = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (timer) {
      final s = widget.session;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (s.api.liveReads?.supports('order.status') != true ||
              timer.tick % 12 == 0) &&
          !s.busy &&
          s.checkout.tradeNo == widget.tradeNo &&
          {
            CheckoutStage.awaitingPayment,
            CheckoutStage.processing,
            CheckoutStage.qr,
          }.contains(s.checkout.stage)) {
        unawaited(s.refreshPayment());
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final text = context.appLocalizations;
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(text.zolnitCancelOrder),
          content: Text(text.zolnitCancelOrderTip),
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
      if (approved == true) {
        await widget.session.cancelOrder(widget.tradeNo);
        if (mounted && widget.session.failure == null) widget.onClose();
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final session = widget.session;
    final order = session.orders
        .where((order) => order['trade_no'] == widget.tradeNo)
        .singleOrNull;
    final typedOrder = order == null ? null : ZolnitOrder.fromJson(order);
    final methods = session.paymentMethods
        .where((method) => method['id'] is int && (method['id'] as int) > 0)
        .toList();
    final selected = methods.any((method) => method['id'] == _methodId)
        ? _methodId
        : methods.firstOrNull?['id'] as int?;
    final recurring = session.hasRecurringTerms(widget.tradeNo);
    final knownSingle = session.knownSinglePayment(widget.tradeNo);
    final checking = session.checkout.tradeNo == widget.tradeNo;
    final status = order?['status'];
    final colors = ZolnitColors.of(context);
    final planName =
        typedOrder?.planName ??
        session.planList
            .where((p) => p.id == order?['plan_id'])
            .firstOrNull
            ?.name ??
        text.zolnitPlans;
    final period = switch (order?['period']) {
      'month_price' || 'monthly' => text.zolnitMonthly,
      'quarter_price' || 'quarterly' => text.zolnitQuarterly,
      'half_year_price' || 'half_yearly' => text.zolnitHalfYearly,
      'year_price' || 'yearly' => text.zolnitYearly,
      'two_year_price' || 'two_yearly' => text.zolnitTwoYearly,
      'three_year_price' || 'three_yearly' => text.zolnitThreeYearly,
      'reset_price' => text.zolnitResetTraffic,
      _ => null,
    };
    final state = checking ? session.checkout.stage : CheckoutStage.idle;
    final done = status == 3 || state == CheckoutStage.completed;
    final closed =
        status == 2 || status == 4 || state == CheckoutStage.cancelled;
    final waiting =
        state == CheckoutStage.processing ||
        state == CheckoutStage.awaitingPayment ||
        state == CheckoutStage.qr ||
        state == CheckoutStage.launching ||
        status == 1;
    final canContinue =
        !session.busy &&
        status == 0 &&
        (state == CheckoutStage.awaitingPayment || state == CheckoutStage.qr);
    final payable =
        status == 0 && !done && !closed && !waiting && !session.busy;
    final method = methods.where((m) => m['id'] == selected).firstOrNull;
    final usesSgd =
        method?['payment'] == 'ZolnitStripe' &&
        session.billingSettlementCurrency == 'SGD';
    final settled = checking ? session.checkout.chargeMinorSgd : null;
    final checkoutStatus = done
        ? text.zolnitCompleted
        : zolnitOrderStatus(context, status);
    final qr = state == CheckoutStage.qr ? session.checkout.qr : null;
    const white = Color(0xfff4f9fb);
    const mist = Color(0xffc6d8df);
    final summary = ZolnitCard(
      color: colors.isDark ? const Color(0xff273e49) : const Color(0xff284753),
      bordered: false,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const ZolnitBrand(width: 93, brightness: Brightness.dark),
              ZolnitPill(
                label: checkoutStatus,
                background: const Color(0xff405e69),
                foreground: white,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            settled == null
                ? text.zolnitReferenceAmount
                : text.zolnitSettlementTotal,
            style: zolnitText(context, 12, color: mist),
          ),
          Text(
            settled == null
                ? zolnitMoney(order?['total_amount'])
                : NumberFormat.currency(
                    name: 'SGD',
                    symbol: 'SGD ',
                  ).format(settled / 100),
            style: zolnitText(
              context,
              42,
              color: white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0x446e8b98), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const GlyphIcon(AppGlyphs.layers, size: 20, color: mist),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [planName, ?period].join(' · '),
                      style: zolnitText(
                        context,
                        16,
                        color: white,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      recurring
                          ? text.zolnitMonthlyEnrollment
                          : knownSingle
                          ? text.zolnitManualPayment
                          : text.zolnitOrderDetails,
                      style: zolnitText(context, 12, color: mist),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    String nameOf(Json m) =>
        !recurring &&
            session.nativeWalletForMethod(
                  m['id'] as int,
                  ClientPaymentPolicy.fromEnvironment(),
                ) ==
                'payment_sheet'
        ? text.zolnitInAppPayment
        : zolnitSanitizedMethodName(context, m['name']);
    final payment = ZolnitCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            done || closed || waiting
                ? text.zolnitPaymentStatus
                : text.zolnitPaymentMethod,
            style: zolnitText(context, 17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (!done && !closed && !waiting && methods.isNotEmpty)
            for (final m in methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: GlyphIcon(
                  AppGlyphs.lock,
                  size: 19,
                  color: colors.accentStrong,
                ),
                title: Text(nameOf(m)),
                selected: selected == m['id'],
                trailing: selected == m['id']
                    ? GlyphIcon(
                        AppGlyphs.checkCircle,
                        size: 20,
                        color: colors.accentStrong,
                      )
                    : null,
                onTap: !payable || methods.length < 2
                    ? null
                    : () => setState(() => _methodId = m['id'] as int),
              )
          else if (done || closed || waiting)
            Text(
              done
                  ? text.zolnitCompleted
                  : closed
                  ? checkoutStatus
                  : text.zolnitConfirmingPayment,
            )
          else
            Text(text.zolnitNoMethods),
          if (usesSgd && !done && !closed)
            Text(
              text.zolnitChargeCurrencyNotice,
              style: zolnitText(context, 12, color: colors.muted),
            ),
          if (qr != null && qr.isValidAt(DateTime.now()))
            Center(
              child: QrImageView(
                data: qr.payload,
                size: 180,
                backgroundColor: Colors.white,
                semanticsLabel: text.zolnitScanToPay,
                errorStateBuilder: (_, _) =>
                    Text(text.zolnitPaymentUnavailable),
              ),
            ),
          if (checking && session.checkout.failure != null)
            ZolnitFailureMessage(
              code: session.checkout.failure,
              serverMessage: session.checkout.failureMessage,
            )
          else if (session.failure != null)
            ZolnitFailureMessage(
              code: session.failure,
              serverMessage: session.failureMessage,
            ),
          const SizedBox(height: 16),
          if (done || closed)
            FilledButton(onPressed: widget.onClose, child: Text(text.back))
          else
            FilledButton(
              onPressed:
                  !_cancelling &&
                      (payable || canContinue) &&
                      session.checkout.allowStripe &&
                      selected != null
                  ? () => session.payOrder(widget.tradeNo, selected)
                  : null,
              child: Text(
                canContinue
                    ? text.zolnitPay
                    : waiting
                    ? text.zolnitConfirmingPayment
                    : text.zolnitPay,
              ),
            ),
          if (status == 0 && !done && !closed && (!waiting || canContinue))
            TextButton(
              onPressed: session.busy || _cancelling ? null : _cancel,
              child: Text(text.zolnitCancelOrder),
            ),
        ],
      ),
    );
    final details = ZolnitCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              text.zolnitOrderDetails,
              style: zolnitText(context, 14, weight: FontWeight.w600),
            ),
            trailing: GlyphIcon(
              _details ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
              size: 17,
            ),
            onTap: () => setState(() => _details = !_details),
          ),
          if (_details)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  [
                    if (order?['created_at'] != null)
                      zolnitOrderDateTime(order!['created_at']),
                    '${text.zolnitOrderNumber} · ${widget.tradeNo}',
                  ].join('\n'),
                  style: zolnitText(context, 11, color: colors.muted),
                ),
              ),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 740;
        return ListView(
          key: const ValueKey('zolnit-cashier'),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 24 : 16,
            vertical: 16,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                summary,
                                const SizedBox(height: 12),
                                details,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: payment),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 12),
                          payment,
                          const SizedBox(height: 12),
                          details,
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
