import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';

class ZolnitNodesPage extends ConsumerWidget {
  const ZolnitNodesPage({super.key, required this.session, required this.sync});

  final ZolnitSessionController session;
  final Future<int?> Function() sync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    if (session.nodes.isNotEmpty) {
      final profile = ref.watch(currentProfileProvider);
      final groups = ref.watch(currentGroupsStateProvider).value;
      if (profile?.label == zolnitProfileLabel(session) && groups.isNotEmpty) {
        return const ProxiesView();
      }
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(text.zolnitProfileSource),
        const SizedBox(height: 12),
        TextButton(
          onPressed: session.busy ? null : sync,
          child: Text(text.zolnitSync),
        ),
        if (session.nodes.isEmpty) Text(text.zolnitNoNodes),
        for (final node in session.nodes) ...[
          ZolnitPanel(
            child: Text(
              node['name'] is String ? node['name'] as String : text.unknown,
              style: AppTextStyle.headline.of(context),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class ZolnitPlansPage extends StatelessWidget {
  const ZolnitPlansPage({
    super.key,
    required this.session,
    required this.onOrderCreated,
  });

  final ZolnitSessionController session;
  final VoidCallback onOrderCreated;

  Future<void> _create(BuildContext context, Json plan, String period) async {
    final text = context.appLocalizations;
    final generation = session.api.generation;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.zolnitBuy),
        content: Text(
          '${plan['name'] as String? ?? ''} · ${zolnitMoney(plan[period])}',
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
    if (approved != true ||
        !context.mounted ||
        session.api.generation != generation) {
      return;
    }
    final tradeNo = await session.createOrder(
      planId: plan['id'] as int,
      period: period,
    );
    if (tradeNo != null &&
        context.mounted &&
        session.api.generation == generation) {
      onOrderCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final periods = {
      'month_price': text.zolnitMonthly,
      'quarter_price': text.zolnitQuarterly,
      'half_year_price': text.zolnitHalfYearly,
      'year_price': text.zolnitYearly,
      'two_year_price': text.zolnitTwoYearly,
      'three_year_price': text.zolnitThreeYearly,
      'onetime_price': text.zolnitOneTime,
      'reset_price': text.zolnitResetTraffic,
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (session.plans.isEmpty) Text(text.zolnitNoPlan),
        for (final plan in session.plans) ...[
          ZolnitPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan['name'] is String
                      ? plan['name'] as String
                      : text.zolnitPlans,
                  style: AppTextStyle.title2.of(context),
                ),
                for (final entry in periods.entries)
                  if (plan[entry.key] is num)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${entry.value} · ${zolnitMoney(plan[entry.key])}',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                session.busy ||
                                    !session.checkout.allowStripe ||
                                    plan['id'] is! int
                                ? null
                                : () => _create(context, plan, entry.key),
                            child: Text(text.zolnitBuy),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          if (!session.checkout.allowStripe)
            Text(text.zolnitPaymentUnavailable),
          const SizedBox(height: 16),
        ],
        ZolnitFailureMessage(visible: session.failure != null),
      ],
    );
  }
}

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
                          Text(text.zolnitFailure),
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
        ZolnitFailureMessage(visible: session.failure != null),
      ],
    );
  }
}
