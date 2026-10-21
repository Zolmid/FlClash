import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

String zolnitMoney(dynamic cents) => cents is num
    ? NumberFormat.currency(name: 'CNY', symbol: '¥').format(cents / 100)
    : '—';

String zolnitDate(dynamic seconds) =>
    seconds is int && seconds > 0 && seconds < 253402300800
    ? DateFormat.yMMMd().format(
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      )
    : '—';

String zolnitBytes(dynamic bytes) => bytes is num
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB'
    : '—';

String zolnitOrderStatus(BuildContext context, dynamic status) {
  final text = context.appLocalizations;
  return switch (status) {
    0 => text.zolnitPending,
    1 => text.zolnitActivating,
    2 => text.zolnitCanceled,
    3 => text.zolnitCompleted,
    4 => text.zolnitCredited,
    _ => text.unknown,
  };
}

/// Known failure codes get localized text; others show the server's reason.
String zolnitFailureText(
  BuildContext context,
  String? code,
  String? serverMessage, {
  String? fallback,
}) {
  final text = context.appLocalizations;
  return switch (code) {
    'pending_order' => text.zolnitPendingOrder,
    'quote_expired' || 'recurring_quote_expired' => text.zolnitQuoteExpired,
    'checkout_exists' => text.zolnitCheckoutExists,
    'checkout_processing' => text.zolnitCheckoutProcessing,
    'rate_limited' => text.zolnitRateLimited,
    'recurring_unavailable' => text.zolnitRecurringUnavailable,
    'payment_disallowed' ||
    'stripe_disabled_for_distribution' => text.zolnitPaymentUnavailable,
    _ => serverMessage ?? fallback ?? text.zolnitFailure,
  };
}

class ZolnitValue extends StatelessWidget {
  const ZolnitValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyle.headline.of(context)),
      ],
    ),
  );
}
