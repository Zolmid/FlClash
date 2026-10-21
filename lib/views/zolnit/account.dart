import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';

class ZolnitAccountPage extends StatelessWidget {
  const ZolnitAccountPage({
    super.key,
    required this.session,
    required this.showOrders,
    required this.logout,
  });

  final ZolnitSessionController session;
  final VoidCallback showOrders;
  final VoidCallback logout;

  Future<void> _change(BuildContext context, int id, bool resume) async {
    final text = context.appLocalizations;
    final generation = session.api.generation;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          resume ? text.zolnitResumeRenewal : text.zolnitCancelRenewal,
        ),
        content: Text(
          resume ? text.zolnitResumeRenewalTip : text.zolnitCancelRenewalTip,
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
    await (resume ? session.resumeRenewal(id) : session.cancelRenewal(id));
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final overview = session.billingOverview;
    final entries = overview?['subscriptions'];
    final contracts = entries is List
        ? entries.whereType<Json>().toList()
        : const <Json>[];
    final entitlement = overview?['entitlement'];
    final source = entitlement is Json ? entitlement['source'] : null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ZolnitPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.account?['email'] is String
                    ? session.account!['email'] as String
                    : text.account,
                style: AppTextStyle.title2.of(context),
              ),
              if (source == 'gift') Text(text.zolnitGift),
              if (source == 'paid') Text(text.zolnitPaid),
              if (entitlement is Json)
                ZolnitValue(
                  label: text.subscriptionInfo,
                  value: zolnitDate(entitlement['expires_at']),
                ),
              TextButton(onPressed: showOrders, child: Text(text.zolnitOrders)),
              TextButton(
                onPressed: session.busy ? null : logout,
                child: Text(text.zolnitSignOut),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(text.zolnitRenewals, style: AppTextStyle.title2.of(context)),
        const SizedBox(height: 12),
        if (session.billingFailure != null) Text(text.zolnitBillingUnavailable),
        if (contracts.isEmpty && session.billingFailure == null)
          Text(text.zolnitNoRenewals),
        for (final contract in contracts) ...[
          ZolnitPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract['plan_name'] is String
                      ? contract['plan_name'] as String
                      : text.zolnitRenewals,
                  style: AppTextStyle.headline.of(context),
                ),
                ZolnitValue(
                  label: text.zolnitPaidThrough,
                  value: zolnitDate(contract['paid_through']),
                ),
                ZolnitValue(
                  label: text.zolnitNextRenewal,
                  value: zolnitDate(contract['next_renewal_at']),
                ),
                if (contract['id'] is int && contract['can_cancel'] == true)
                  TextButton(
                    onPressed: session.busy
                        ? null
                        : () => _change(context, contract['id'] as int, false),
                    child: Text(text.zolnitCancelRenewal),
                  ),
                if (contract['id'] is int && contract['can_resume'] == true)
                  TextButton(
                    onPressed: session.busy || !session.checkout.allowStripe
                        ? null
                        : () => _change(context, contract['id'] as int, true),
                    child: Text(text.zolnitResumeRenewal),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ZolnitFailureMessage(visible: session.failure != null),
      ],
    );
  }
}
