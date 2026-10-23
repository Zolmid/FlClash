import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'zolnit_vault.dart';

final zolnitSessionProvider = Provider<ZolnitSessionController>((ref) {
  final policy = ClientPaymentPolicy.fromEnvironment();
  final api = XboardClient(
    origin: Uri.parse('https://link.zolmid.com'),
    clientPlatform: policy.platformHeader,
    distribution: policy.distributionHeader,
    userAgent: globalState.ua,
    contentLanguage: _contentLanguage,
  );
  final checkout = CheckoutController(
    backend: XboardCheckoutBackend(api, confirmRecurring: _confirmRecurring),
    platform: NativeCheckoutPlatform(merchantName: 'ZolNit'),
    allowedHttpsOrigins: const {
      'https://checkout.stripe.com',
      'https://link.zolmid.com',
    },
    allowStripe: policy.allowStripe,
  );
  final session = ZolnitSessionController(
    api: api,
    billing: ZolnitBillingClient(api),
    checkout: checkout,
    confirmRecurring: _confirmRecurring,
    vault: ref.read(zolnitSessionVaultProvider),
    onAuthenticationInvalidated: () async {
      if (!ref.read(safeModeProvider)) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    },
  );
  ref.onDispose(session.dispose);
  return session;
});

String _contentLanguage() => switch (Intl.getCurrentLocale()) {
  'zh_CN' => 'zh-CN',
  'zh_TW' => 'zh-TW',
  'ja' => 'ja-JP',
  'ko' => 'ko-KR',
  'ru' => 'ru-RU',
  _ => 'en-US',
};

Future<bool> _confirmRecurring(Json intent) async {
  const fields = [
    'first_total_cents',
    'first_charge_amount_cents',
    'total_cents',
    'charge_amount_cents',
    'surplus_credit_cents',
  ];
  if (fields.any((key) => intent[key] is! int || (intent[key] as int) < 0) ||
      intent['charge_currency'] != 'SGD') {
    return false;
  }
  final text = currentAppLocalizations;
  String money(String key, String currency) =>
      NumberFormat.currency(name: currency).format((intent[key] as int) / 100);
  final result = await dialogs.showMessage(
    title: text.zolnitRenewals,
    message: TextSpan(
      text: [
        text.zolnitRecurringConsent,
        '${text.zolnitFirstCharge}: ${money('first_total_cents', 'CNY')} / ${money('first_charge_amount_cents', 'SGD')}',
        '${text.zolnitFollowingCharge}: ${money('total_cents', 'CNY')} / ${money('charge_amount_cents', 'SGD')}',
        '${text.zolnitCredited}: ${money('surplus_credit_cents', 'CNY')}',
        if (intent['next_charge_at'] is int)
          '${text.zolnitNextRenewal}: ${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch((intent['next_charge_at'] as int) * 1000))}',
        if (intent['gift_replacement'] == true) text.zolnitGiftReplacement,
        if (intent['switch_immediately'] == true) text.zolnitPlanSwitch,
      ].join('\n\n'),
    ),
  );
  return result == true;
}

final zolnitProfileDownloaderProvider = Provider<Dio>((ref) {
  final downloader = Dio(
    BaseOptions(
      followRedirects: false,
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      headers: {'User-Agent': globalState.ua},
    ),
  );
  ref.onDispose(() => downloader.close(force: true));
  return downloader;
});

String? zolnitProfileLabel(ZolnitSessionController session) {
  final email = session.account?['email'] ?? session.subscription?['email'];
  return email is String && email.isNotEmpty
      ? 'ZolNit · ${email.toLowerCase()} @ ${session.api.origin.host}'
      : null;
}

final zolnitSyncProfileProvider = Provider<Future<int?> Function()>((ref) {
  final session = ref.watch(zolnitSessionProvider);
  final downloader = ref.watch(zolnitProfileDownloaderProvider);
  Future<int?>? pending;
  int? pendingGeneration;

  Future<int?> sync() async {
    if (!session.authenticated) throw const ClientFailure('unauthenticated');
    final generation = session.api.generation;
    final data = session.subscription;
    final value = data?['subscribe_url'];
    final email = session.account?['email'] ?? data?['email'];
    if (data?['plan_id'] == null || session.nodes.isEmpty) return null;
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        email is! String ||
        email.isEmpty) {
      throw const ClientFailure('invalid_subscription');
    }
    final source = uri.replace(
      queryParameters: {...uri.queryParametersAll, 'flag': 'meta'},
    );
    final label = zolnitProfileLabel(session)!;
    final existing = ref
        .read(profilesProvider)
        .where((p) => p.label == label)
        .firstOrNull;
    final profile = (existing ?? Profile.normal(label: label)).copyWith(
      url: source.toString(),
    );
    bool current() =>
        session.authenticated && session.api.generation == generation;
    File? staged;
    try {
      final response = await downloader.getUri<Uint8List>(source);
      if (!current()) throw const ClientFailure('superseded');
      if (response.statusCode != 200 ||
          response.data == null ||
          response.data!.isEmpty) {
        throw const ClientFailure('profile_sync_failed');
      }
      final target = File(await appPath.getProfilePath(profile.id.toString()));
      await target.parent.create(recursive: true);
      staged = File('${target.path}.zolnit-$generation.partial');
      final bytes = await compute(decompressUnlabeled, response.data!);
      await staged.writeAsBytes(bytes, flush: true);
      if (!current()) throw const ClientFailure('superseded');
      final message = await ref
          .read(coreHandlerProvider)
          .validateProfile(staged.path, '');
      if (!current()) throw const ClientFailure('superseded');
      if (message.isNotEmpty) throw const ClientFailure('profile_sync_failed');
      staged.renameSync(target.path);
      ref
          .read(profilesActionProvider.notifier)
          .putProfile(
            profile.copyWith(
              subscriptionInfo: SubscriptionInfo.formHString(
                response.headers.value('subscription-userinfo'),
              ),
              lastUpdateDate: DateTime.now(),
            ),
          );
      return profile.id;
    } catch (error) {
      if (error is ClientFailure && error.code == 'superseded') rethrow;
      throw const ClientFailure('profile_sync_failed');
    } finally {
      if (staged?.existsSync() == true) staged!.deleteSync();
    }
  }

  return () {
    final generation = session.api.generation;
    if (pending != null && pendingGeneration == generation) return pending!;
    final operation = Future<int?>.microtask(() {
      if (session.api.generation != generation) {
        throw const ClientFailure('superseded');
      }
      return sync();
    });
    pending = operation;
    pendingGeneration = generation;
    return operation.whenComplete(() {
      if (identical(pending, operation)) pending = null;
    });
  };
});
