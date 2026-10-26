import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/zolnit_apple.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';
import 'skin.dart';

class ZolnitApplePlansPage extends ConsumerStatefulWidget {
  const ZolnitApplePlansPage({
    super.key,
    required this.session,
    this.compact = false,
  });
  final ZolnitSessionController session;
  final bool compact;
  @override
  ConsumerState<ZolnitApplePlansPage> createState() =>
      _ZolnitApplePlansPageState();
}

class _ZolnitApplePlansPageState extends ConsumerState<ZolnitApplePlansPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() => ref.read(zolnitAppleBillingProvider).load()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(zolnitAppleBillingProvider);
    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final text = context.appLocalizations;
        final skin = ZolnitSkin.of(context);
        final controller = billing.controller;
        String period(String value) => switch (value) {
          'monthly' => text.zolnitMonthly,
          'quarterly' => text.zolnitQuarterly,
          'half_yearly' => text.zolnitHalfYearly,
          'yearly' => text.zolnitYearly,
          _ => text.zolnitAppleUnavailable,
        };
        final products = controller?.products ?? [];
        return ListView(
          padding: zolnitPagePadding(skin, compact: widget.compact),
          children: [
            ZolnitPageHeading(
              title: text.zolnitPlansHeadline,
              subtitle: text.zolnitAppleAutoRenewal,
            ),
            const SizedBox(height: 24),
            if (billing.loading) const LinearProgressIndicator(),
            if (!billing.loading &&
                (billing.config?.available != true || products.isEmpty))
              Text(text.zolnitAppleUnavailable, style: zolnitText(context, 14)),
            if (billing.failure != null || controller?.failure != null)
              Text(text.zolnitFailure, style: zolnitText(context, 13)),
            for (final plan in widget.session.planList) ...[
              const SizedBox(height: 16),
              ZolnitCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: zolnitText(context, 20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    for (final mapping
                        in billing.config?.products.where(
                              (item) => item.planId == plan.id,
                            ) ??
                            const <AppleProductMapping>[])
                      if (billing.config
                              ?.productFor(mapping.planId, mapping.period)
                              ?.productId ==
                          mapping.productId)
                        for (final product in products.where(
                          (product) => product.id == mapping.productId,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    period(mapping.period),
                                    product.price,
                                  ].join(' · '),
                                  style: zolnitText(context, 16),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: billing.busy
                                      ? null
                                      : () => unawaited(
                                          billing.subscribe(product.id),
                                        ),
                                  child: Text(text.zolnitAppleSubscribe),
                                ),
                              ],
                            ),
                          ),
                    if (billing.config?.products.any(
                          (item) => item.planId == plan.id,
                        ) !=
                        true)
                      Text(
                        text.zolnitAppleUnavailable,
                        style: zolnitText(context, 13),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(text.zolnitAppleConsent, style: zolnitText(context, 12)),
            if (billing.busy) ...[
              const SizedBox(height: 12),
              Text(text.zolnitApplePending, style: zolnitText(context, 13)),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: billing.busy
                      ? null
                      : () => unawaited(billing.load()),
                  child: Text(text.retry),
                ),
                TextButton(
                  onPressed: controller == null || billing.busy
                      ? null
                      : () => unawaited(billing.restore()),
                  child: Text(text.zolnitAppleRestore),
                ),
                if (controller?.stage == ApplePurchaseStage.awaitingBackend)
                  TextButton(
                    onPressed: () => unawaited(billing.retryVerification()),
                    child: Text(text.retry),
                  ),
                if (billing.config != null)
                  TextButton(
                    onPressed: () => unawaited(
                      launchUrl(
                        billing.config!.managementUri,
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    child: Text(text.zolnitAppleManage),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
