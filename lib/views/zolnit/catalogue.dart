import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';

export 'plans.dart' show ZolnitPlansPage;
export 'nodes.dart' show ZolnitNodesPage;

class ZolnitOrdersPage extends StatefulWidget {
  const ZolnitOrdersPage({super.key, required this.session});

  final ZolnitSessionController session;

  @override
  State<ZolnitOrdersPage> createState() => _ZolnitOrdersPageState();
}

class _ZolnitOrdersPageState extends State<ZolnitOrdersPage> {
  final Map<String, int> _methods = {};

  Future<void> _cancel(String tradeNo) async {
    final text = context.appLocalizations;
    final generation = widget.session.api.generation;
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
        widget.session.api.generation == generation) {
      await widget.session.cancelOrder(tradeNo);
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
                  final selected =
                      _methods[tradeNo] ??
                      (methods.isNotEmpty ? methods.first['id'] as int : null);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tradeNo, style: AppTextStyle.headline.of(context)),
                      Text(zolnitOrderStatus(context, order['status'])),
                      ZolnitValue(
                        label: text.zolnitAmountDue,
                        value: zolnitMoney(order['total_amount']),
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
                                    method['name'] is String
                                        ? method['name'] as String
                                        : text.unknown,
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
                                  : () => session.payOrder(
                                      tradeNo,
                                      selected ?? 0,
                                    ),
                              child: Text(text.zolnitPay),
                            ),
                            TextButton(
                              onPressed: session.busy
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
