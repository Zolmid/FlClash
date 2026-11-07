import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';
import 'kit.dart';
import 'skin.dart';

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
  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final session = widget.session;
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
                  final pending = order['status'] == 0;
                  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              typedOrder?.planName ?? text.zolnitOrderDetails,
                              style: AppTextStyle.headline.of(
                                context,
                                emphasized: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _OrderStatus(status: order['status']),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '${zolnitOrderDateTime(order['created_at'])}\n'
                              '${text.zolnitOrderNumber} · $tradeNo',
                              style: AppTextStyle.caption1
                                  .of(context)
                                  .copyWith(color: muted),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            zolnitMoney(order['total_amount']),
                            style: AppTextStyle.title3.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ],
                      ),
                      if (pending)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () => widget.onCheckout(tradeNo),
                            child: Text(text.zolnitPay),
                          ),
                        ),
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

class _OrderStatus extends StatelessWidget {
  const _OrderStatus({required this.status});

  final dynamic status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ZolnitColors.of(context);
    final (fill, ink) = switch (status) {
      0 => (scheme.warningContainer, scheme.onWarningContainer),
      3 || 4 => (scheme.successContainer, scheme.onSuccessContainer),
      1 => (colors.blue, colors.ink),
      _ => (colors.soft, colors.muted),
    };
    return ZolnitPill(
      label: zolnitOrderStatus(context, status),
      background: fill,
      foreground: ink,
    );
  }
}
