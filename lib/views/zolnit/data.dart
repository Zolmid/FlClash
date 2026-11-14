import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

String? zolnitConfigurationMessage(
  BuildContext context,
  ZolnitSessionController session,
  ZolnitBundleStatus status, {
  required bool privateTransport,
  bool stopped = false,
}) {
  final text = context.appLocalizations;
  if (!privateTransport) {
    return session.failure == null
        ? null
        : zolnitFailureText(context, session.failure, null);
  }
  if (status == ZolnitBundleStatus.loading) return text.loading;
  final failure = session.clientBundleFailure;
  if (failure != null) status = bundleFailureStatus(failure);
  if (session.clientBundle == null &&
      (status == ZolnitBundleStatus.unloaded ||
          status == ZolnitBundleStatus.ready)) {
    return text.loading;
  }
  return switch (status) {
    ZolnitBundleStatus.loading => text.loading,
    ZolnitBundleStatus.forbidden => text.zolnitBundleForbidden,
    ZolnitBundleStatus.invalid =>
      stopped ? text.zolnitBundleInvalidWhenStopped : text.zolnitBundleInvalid,
    ZolnitBundleStatus.expired =>
      session.clientBundle == null
          ? text.zolnitBundleUnavailable
          : text.zolnitBundleExpired,
    ZolnitBundleStatus.refreshFailed =>
      session.clientBundle == null
          ? text.zolnitBundleUnavailable
          : text.zolnitBundleRefreshFailed,
    ZolnitBundleStatus.unavailable => text.zolnitBundleUnavailable,
    _ => null,
  };
}

String zolnitMoney(dynamic cents) => cents is num
    ? NumberFormat.currency(name: 'CNY', symbol: '¥').format(cents / 100)
    : '—';

String zolnitDate(dynamic seconds) =>
    seconds is int && seconds > 0 && seconds < 253402300800
    ? DateFormat.yMMMd().format(
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      )
    : '—';

String zolnitOrderDateTime(dynamic seconds) =>
    seconds is int && seconds > 0 && seconds < 253402300800
    ? DateFormat.yMMMd().add_Hm().format(
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal(),
      )
    : '—';

String zolnitBytes(dynamic bytes) => bytes is num
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB'
    : '—';

String zolnitDotDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)}';
}

String zolnitOrderStatus(BuildContext context, dynamic status) {
  final text = context.appLocalizations;
  return switch (status) {
    0 => text.zolnitPending,
    1 => text.zolnitActivating,
    2 => text.zolnitCanceled,
    3 => text.zolnitCompleted,
    4 => text.zolnitCredited,
    _ => text.zolnitStatusUnconfirmed,
  };
}

String zolnitSanitizedMethodName(BuildContext context, dynamic raw) {
  if (raw is! String || raw.isEmpty) {
    return context.appLocalizations.zolnitOnlinePayment;
  }
  final lower = raw.toLowerCase();
  if (lower == 'stripe' ||
      lower.contains('stripe') ||
      lower.startsWith('pm_') ||
      lower.startsWith('card_')) {
    return context.appLocalizations.zolnitOnlinePayment;
  }
  return raw;
}

String zolnitRenewalLabel(BuildContext context, RenewalState state) {
  final text = context.appLocalizations;
  return switch (state) {
    RenewalState.enabled => text.zolnitRenewalActive,
    RenewalState.disabled => text.zolnitRenewalOff,
    RenewalState.pending => text.zolnitRenewalPending,
    RenewalState.ended => text.zolnitRenewalEnded,
    RenewalState.attention => text.zolnitRenewalAttention,
  };
}

String zolnitFailureText(
  BuildContext context,
  String? code,
  String? serverMessage, {
  String? fallback,
}) {
  final text = context.appLocalizations;
  return switch (code) {
    'pending_order' => text.zolnitPendingOrder,
    'active_subscription' => text.zolnitExistingRenewal,
    'quote_expired' || 'recurring_quote_expired' => text.zolnitQuoteExpired,
    'checkout_exists' => text.zolnitCheckoutExists,
    'checkout_processing' => text.zolnitCheckoutProcessing,
    'payment_status_unknown' => text.zolnitPaymentCheckStatus,
    'user_cancelled' => text.zolnitPaymentCancelled,
    'sdk_error' || 'payment_error' => text.zolnitPaymentCheckStatus,
    'rate_limited' => text.zolnitRateLimited,
    'recurring_unavailable' => text.zolnitRecurringUnavailable,
    'payment_disallowed' ||
    'wallet_unavailable' ||
    'stripe_disabled_for_distribution' => text.zolnitPaymentUnavailable,
    'network' || 'timeout' => text.networkException,
    'registration_browser_unavailable' =>
      text.zolnitRegistrationBrowserUnavailable,
    'registration_return_expired' => text.zolnitRegistrationReturnExpired,
    'storage_unavailable' => text.zolnitSessionStorageUnavailable,
    'invalid_credentials' => text.zolnitSignInRejected,
    'unauthenticated' => text.zolnitSessionExpired,
    'entitlement_unavailable' => text.zolnitBundleForbidden,
    'client_api_unavailable' ||
    'bundle_unavailable' ||
    'profile_sync_failed' => text.zolnitBundleUnavailable,
    _ => fallback ?? text.zolnitFailure,
  };
}
