import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';

export 'nodes.dart' show ZolnitNodesPage;

export 'cashier.dart' show ZolnitCashierPage;

class ZolnitOrdersPage extends StatefulWidget {
  const ZolnitOrdersPage({
    super.key,
    required this.session,
    required this.onCheckout,
  });

  final ZolnitSessionController session;
  final ValueChanged<String> onCheckout;

  @override
  State<ZolnitOrdersPage> createState() => _ZolnitOrdersPageState();
}

class _ZolnitOrdersPageState extends State<ZolnitOrdersPage> {
  final Map<String, int> _methods = {};
  final Set<String> _cancelling = {};
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = widget.session.api.generation;
  }

  @override
  void didUpdateWidget(covariant ZolnitOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        _generation != widget.session.api.generation) {
      _generation = widget.session.api.generation;
      _methods.clear();
    }
  }

  Future<void> _cancel(String tradeNo) async {
    if (_cancelling.contains(tradeNo)) return;
    setState(() => _cancelling.add(tradeNo));
    final text = context.appLocalizations;
    final session = widget.session;
    final generation = session.api.generation;
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
      if (approved == true &&
          mounted &&
          widget.session == session &&
          session.api.generation == generation) {
        await session.cancelOrder(tradeNo);
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(tradeNo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final session = widget.session;
    final methods = session.paymentMethods
        .where((m) => m['id'] is int && (m['id'] as int) > 0)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (session.orders.isEmpty) Text(text.zolnitNoOrders),
        for (final order in session.orders)
          if (order['trade_no'] is String) ...[
            ZolnitPanel(
              child: Builder(
                builder: (context) {
                  final tradeNo = order['trade_no'] as String;
                  final typedOrder = ZolnitOrder.fromJson(order);
                  final cancelling = _cancelling.contains(tradeNo);
                  final preferred = _methods[tradeNo];
                  final selected =
                      methods.any((method) => method['id'] == preferred)
                      ? preferred
                      : (methods.isNotEmpty
                            ? methods.first['id'] as int
                            : null);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typedOrder?.planName ?? text.zolnitOrderDetails,
                        style: AppTextStyle.headline.of(context),
                      ),
                      Text(
                        zolnitOrderDateTime(order['created_at']),
                        style: AppTextStyle.caption1.of(context),
                      ),
                      Text(
                        '${text.zolnitOrderNumber} · $tradeNo',
                        style: AppTextStyle.caption2.of(context),
                      ),
                      Text(zolnitOrderStatus(context, order['status'])),
                      ZolnitValue(
                        label: text.zolnitReferenceAmount,
                        value: zolnitMoney(order['total_amount']),
                      ),
                      Text(
                        text.zolnitChargeCurrencyNotice,
                        style: AppTextStyle.caption1.of(context),
                      ),
                      if (order['status'] == 0) ...[
                        if (methods.isNotEmpty)
                          DropdownButton<int>(
                            value: selected,
                            isExpanded: true,
                            items: [
                              for (final method in methods)
                                DropdownMenuItem<int>(
                                  value: method['id'] as int,
                                  child: Text(
                                    zolnitSanitizedMethodName(
                                      context,
                                      method['name'],
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: session.busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _methods[tradeNo] = value);
                                    }
                                  },
                          ),
                        if (methods.isEmpty) Text(text.zolnitNoMethods),
                        if (!session.checkout.allowStripe)
                          Text(text.zolnitPaymentUnavailable),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed:
                                  session.busy || !session.checkout.allowStripe
                                  ? null
                                  : () => widget.onCheckout(tradeNo),
                              child: Text(text.zolnitPay),
                            ),
                            TextButton(
                              onPressed: session.busy || cancelling
                                  ? null
                                  : () => _cancel(tradeNo),
                              child: Text(text.zolnitCancelOrder),
                            ),
                          ],
                        ),
                      ],
                      if (session.checkout.tradeNo == tradeNo) ...[
                        const SizedBox(height: 12),
                        Text(text.zolnitPaymentReturn),
                        if (session.checkout.failure != null)
                          ZolnitFailureMessage(
                            code: session.checkout.failure,
                            serverMessage: session.checkout.failureMessage,
                          ),
                        TextButton(
                          onPressed: session.busy
                              ? null
                              : session.refreshPayment,
                          child: Text(text.zolnitRefresh),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ZolnitFailureMessage(
          code: session.failure,
          serverMessage: session.failureMessage,
        ),
      ],
    );
  }
}
