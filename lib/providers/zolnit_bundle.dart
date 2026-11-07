import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:zolnit_client/zolnit_client.dart';
import 'zolnit_signed_subscription.dart';

final zolnitClientBundleTransportProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('ZOLNIT_CLIENT_BUNDLE'),
);
final zolnitClientBundleAutomaticProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'ZOLNIT_CLIENT_BUNDLE_AUTOMATIC',
    defaultValue: true,
  ),
);
final zolnitBundleClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum ZolnitBundleStatus {
  unloaded,
  loading,
  ready,
  expired,
  refreshFailed,
  forbidden,
  invalid,
  unavailable,
}

class ZolnitBundleStatusNotifier extends Notifier<ZolnitBundleStatus> {
  @override
  ZolnitBundleStatus build() => ZolnitBundleStatus.unloaded;
  void set(ZolnitBundleStatus value) => state = value;
}

final zolnitBundleStatusProvider =
    NotifierProvider<ZolnitBundleStatusNotifier, ZolnitBundleStatus>(
      ZolnitBundleStatusNotifier.new,
    );

class ZolnitBundleActivity {
  const ZolnitBundleActivity({
    this.refreshing = false,
    this.failure,
    this.retained,
    this.generation,
  });
  final bool refreshing;
  final String? failure;
  final ZolnitClientBundle? retained;
  final int? generation;
}

class ZolnitBundleActivityNotifier extends Notifier<ZolnitBundleActivity> {
  @override
  ZolnitBundleActivity build() => const ZolnitBundleActivity();
  void set(ZolnitBundleActivity value) => state = value;
}

final zolnitBundleActivityProvider =
    NotifierProvider<ZolnitBundleActivityNotifier, ZolnitBundleActivity>(
      ZolnitBundleActivityNotifier.new,
    );

bool _transientBundleFailure(String code) =>
    switch (bundleFailureStatus(code)) {
      ZolnitBundleStatus.refreshFailed => true,
      ZolnitBundleStatus.unavailable => code != 'core_version_required',
      _ => false,
    };

bool isZolnitBundleProfile(Profile profile) =>
    profile.zolnitAccountId != null ||
    profile.zolnitBundleId != null ||
    profile.zolnitOrigin != null;

bool isCurrentZolnitBundleProfile(
  Profile profile,
  ZolnitSessionController session,
) =>
    session.authenticated &&
    session.clientBundleAccountId != null &&
    profile.zolnitAccountId == session.clientBundleAccountId &&
    profile.zolnitOrigin == session.api.origin.origin &&
    profile.zolnitBundleId != null;

Profile? cachedManualZolnitBundleProfile(
  List<Profile> profiles,
  ZolnitSessionController session, {
  required bool enabled,
}) {
  final bundle = session.clientBundle;
  if (!enabled ||
      bundle == null ||
      !session.authenticated ||
      (session.clientBundleFailure != null &&
          session.clientBundleFailure != 'bundle_unavailable') ||
      const {
        'entitlement_unavailable',
        'core_version_required',
        'invalid_client_bundle',
        'client_bundle_binding_mismatch',
      }.contains(session.clientBundleFailure)) {
    return null;
  }
  return profiles
      .where(
        (profile) =>
            isCurrentZolnitBundleProfile(profile, session) &&
            bundle.routingManifest.services.any((service) {
              final choice = profile.selectedMap[service.groupName];
              return choice == service.manualGroup || choice == 'DIRECT';
            }),
      )
      .firstOrNull;
}

String clientBundleApplicationDigest(
  String configDigest,
  ZolnitClientBundle bundle,
) => sha256
    .convert(
      utf8.encode(
        '$configDigest:${bundle.accountId}:${bundle.bundleId}:${bundle.expiresAt.millisecondsSinceEpoch}:${bundle.connectionSha256}:${bundle.routingSha256}',
      ),
    )
    .toString();

Future<String> zolnitBundlePath(Profile profile) async {
  final id = profile.zolnitBundleId;
  if (id == null) throw const ClientFailure('invalid_client_bundle');
  final digest = sha256.convert(utf8.encode(id)).toString();
  return path.join(
    await appPath.profilesPath,
    'zolnit',
    profile.id.toString(),
    '$digest.json',
  );
}

ZolnitClientBundle _decodeStoredBundle(
  ({String content, DateTime now, String accountId, String bundleId}) input,
) {
  try {
    final raw = jsonDecode(input.content);
    if (raw is! Json) throw const ClientFailure('invalid_client_bundle');
    final bundle = ZolnitClientBundle.parse(
      raw,
      now: input.now,
      expectedAccountId: input.accountId,
      allowExpired: true,
    );
    if (bundle.bundleId != input.bundleId) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    return bundle;
  } catch (error) {
    if (error is ClientFailure) rethrow;
    throw const ClientFailure('invalid_client_bundle');
  }
}

Future<ZolnitClientBundle> readZolnitClientBundle(
  Profile profile,
  DateTime now,
) async => compute(_decodeStoredBundle, (
  content: await File(await zolnitBundlePath(profile)).readAsString(),
  now: now,
  accountId: profile.zolnitAccountId ?? '',
  bundleId: profile.zolnitBundleId ?? '',
));

Future<ZolnitClientBundle> readActiveZolnitClientBundle(
  Profile profile,
  DateTime now,
  ZolnitSessionController session,
) async {
  final signed = session.signedSubscriptions?.active;
  if (signed != null && signed.accountId == profile.zolnitAccountId) {
    final bundle = session.clientBundle;
    if (!isCurrentZolnitBundleProfile(profile, session) ||
        bundle == null ||
        bundle.bundleId != profile.zolnitBundleId ||
        !bundle.isFresh(now)) {
      throw const ClientFailure('signed_subscription_required');
    }
    return bundle;
  }
  final account = profile.zolnitAccountId;
  if (account != null &&
      await session.signedSubscriptions?.refusesUnsigned(
            session.api,
            account,
          ) ==
          true) {
    throw const ClientFailure('signed_subscription_required');
  }
  return readZolnitClientBundle(profile, now);
}

PreparedZolnitRouting prepareClientBundleConfiguration(
  ({ZolnitClientBundle bundle, DateTime now, bool automaticAllowed}) input,
) {
  try {
    final document = loadPlainYaml(input.bundle.document);
    if (document is! Map) throw const ClientFailure('invalid_client_bundle');
    final config = Map<String, dynamic>.from(document);
    final rawProxies = config['proxies'];
    final rawGroups = config['proxy-groups'];
    if (rawProxies is! List || rawGroups is! List) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final names = <String>{};
    for (final proxy in rawProxies) {
      if (proxy is! Map ||
          proxy['name'] is! String ||
          !isSmartRoutingProxyType(proxy['type']) ||
          !names.add(proxy['name'] as String)) {
        throw const ClientFailure('client_bundle_binding_mismatch');
      }
    }
    if (!const SetEquality<String>().equals(
      names,
      input.bundle.outbounds.map((o) => o.proxyName).toSet(),
    )) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    final providers = config['proxy-providers'];
    if (providers != null && (providers is! Map || providers.isNotEmpty)) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    final groups = <String>{};
    for (final group in rawGroups) {
      if (group is! Map ||
          group['name'] is! String ||
          !groups.add(group['name'] as String) ||
          names.contains(group['name'])) {
        throw const ClientFailure('client_bundle_binding_mismatch');
      }
    }
    final outboundFingerprints = <String, String>{
      for (final outbound in input.bundle.outbounds)
        if (outbound.configurationFingerprint != null)
          outbound.id: outbound.configurationFingerprint!,
    };
    final checked = SmartRoutingManifest.parse(
      input.bundle.routingJson,
      proxyNames: names,
      groupNames: groups,
      outboundFingerprints: outboundFingerprints,
    );
    if (checked == null ||
        checked.nodes.length != input.bundle.routingManifest.nodes.length) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    final routing = Map<String, dynamic>.from(input.bundle.routingJson);
    if (!input.automaticAllowed || !input.bundle.isFresh(input.now)) {
      routing['nodes'] = <Json>[];
    }
    config.remove(routingManifestKey);
    return prepareZolnitRouting(
      config,
      routingMetadata: routing,
      outboundFingerprints: outboundFingerprints,
    );
  } catch (error) {
    if (error is ClientFailure) rethrow;
    throw const ClientFailure('invalid_client_bundle');
  }
}

String prepareBundleRenewalOverlay(
  ({Map<String, dynamic> source, String compiledYaml}) input,
) {
  final value = loadPlainYaml(input.compiledYaml);
  if (value is! Map) throw const ClientFailure('invalid_client_bundle');
  final overlay = Map<String, dynamic>.from(value);
  for (final key in ['proxies', 'proxy-groups', 'sub-rules']) {
    overlay.remove(key);
  }
  final original = input.source['rules'];
  final compiled = overlay['rules'];
  if (original is! List || compiled is! List) {
    throw const ClientFailure('invalid_client_bundle');
  }
  final serverRules = original.toSet();
  overlay['rules'] = compiled
      .where((rule) => !serverRules.contains(rule))
      .toList();
  return jsonEncode(overlay);
}

Future<void> _privateMode(String location, String mode) async {
  if (Platform.isWindows || Platform.isAndroid || Platform.isIOS) return;
  final result = await Process.run('/bin/chmod', [mode, location]);
  if (result.exitCode != 0) {
    throw const ClientFailure('client_bundle_storage_failed');
  }
}

Future<void> _saveClientBundle(
  Profile profile,
  ZolnitClientBundle bundle,
  DateTime now,
) async {
  final target = File(await zolnitBundlePath(profile));
  await target.parent.create(recursive: true);
  await _privateMode(target.parent.path, '700');
  if (await target.exists()) {
    final existing = await readZolnitClientBundle(profile, now);
    if (!const DeepCollectionEquality().equals(
      existing.toJson(),
      bundle.toJson(),
    )) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    return;
  }
  final staging = await target.parent.createTemp('bundle-');
  final partial = File(path.join(staging.path, 'entry.json'));
  try {
    await partial.writeAsString(jsonEncode(bundle.toJson()), flush: true);
    await _privateMode(partial.path, '600');
    await partial.rename(target.path);
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

ZolnitBundleStatus bundleFailureStatus(String? code) => switch (code) {
  'entitlement_unavailable' ||
  'subscription_tombstone' => ZolnitBundleStatus.forbidden,
  'subscription_expired' => ZolnitBundleStatus.expired,
  'client_bundle_expired' => ZolnitBundleStatus.expired,
  'invalid_client_bundle' ||
  'invalid_signed_subscription' ||
  'subscription_replay' ||
  'signed_subscription_stale_owner' ||
  'client_bundle_binding_mismatch' => ZolnitBundleStatus.invalid,
  'client_api_unavailable' ||
  'bundle_unavailable' ||
  'core_version_required' => ZolnitBundleStatus.unavailable,
  _ => ZolnitBundleStatus.refreshFailed,
};

class _BundleSyncRevision {
  int value = 0;
}

final _bundleSyncRevisionProvider = Provider((_) => _BundleSyncRevision());

final zolnitSyncClientBundleProvider = Provider<Future<int?> Function()>((ref) {
  return _createBundleSync(ref, ref.watch(zolnitSessionProvider));
});

final zolnitSyncCurrentClientBundleProvider =
    Provider<Future<int?> Function(Map<String, dynamic>)>((ref) {
      final session = ref.watch(zolnitSessionProvider);
      return (lease) {
        final generation = session.api.generation;
        final subscriptions = session.signedSubscriptions;
        final binding = subscriptions?.active;
        if (binding == null ||
            lease['accountId'] != binding.accountId ||
            lease['accountGeneration'] != generation) {
          return Future.error(const ClientFailure('superseded'));
        }
        return _createBundleSync(
          ref,
          session,
          readNative: () async {
            final projection =
                await CoreSignedSubscriptionOwner(
                  ref.read(coreHandlerProvider),
                ).current(
                  accountId: binding.accountId,
                  deviceId: binding.device.deviceId,
                  intent: binding.intent,
                  lease: lease,
                );
            if (!ref.mounted ||
                !session.authenticated ||
                !subscriptions!.acceptNativeState(
                  session.api,
                  generation: generation,
                  accountId: binding.accountId,
                  deviceId: binding.device.deviceId,
                  intent: projection.intent,
                  state: projection.state,
                )) {
              throw const ClientFailure('superseded');
            }
            return projection.data;
          },
        )();
      };
    });

Future<int?> Function() _createBundleSync(
  Ref ref,
  ZolnitSessionController session, {
  Future<Json?> Function()? readNative,
}) {
  Future<int?>? pending;
  int? pendingGeneration;
  Future<int?> sync() async {
    if (!session.authenticated) throw const ClientFailure('unauthenticated');
    final generation = session.api.generation;
    final revision = ref.read(_bundleSyncRevisionProvider);
    final sequence = ++revision.value;
    final clock = ref.read(zolnitBundleClockProvider);
    bool current() =>
        ref.mounted &&
        revision.value == sequence &&
        session.authenticated &&
        session.api.generation == generation;
    final status = ref.read(zolnitBundleStatusProvider.notifier);
    final activity = ref.read(zolnitBundleActivityProvider.notifier);
    final retained = session.clientBundle;
    final background =
        retained != null &&
        retained.isFresh(clock()) &&
        ref.read(zolnitBundleStatusProvider) == ZolnitBundleStatus.ready;
    if (background) {
      activity.set(
        ZolnitBundleActivity(
          refreshing: true,
          retained: retained,
          generation: generation,
        ),
      );
    } else {
      status.set(ZolnitBundleStatus.loading);
    }
    Directory? staging;
    try {
      final core = ref.read(coreHandlerProvider);
      final coreVersion = (await core.getCoreVersion()).trim();
      if (!current()) throw const ClientFailure('superseded');
      int? profileId;
      Profile? preparedProfile;
      final bundle = await session.refreshClientBundle(
        coreVersion: coreVersion,
        clock: clock,
        readNative: readNative,
        prepare: (bundle) async {
          final prepared = await compute(prepareClientBundleConfiguration, (
            bundle: bundle,
            now: clock(),
            automaticAllowed: ref.read(zolnitClientBundleAutomaticProvider),
          ));
          if (!current()) throw const ClientFailure('superseded');
          final existing = ref
              .read(profilesProvider)
              .where(
                (p) =>
                    p.zolnitAccountId == bundle.accountId &&
                    p.zolnitOrigin == session.api.origin.origin,
              )
              .firstOrNull;
          final profile = (existing ?? Profile.normal(label: 'ZolNit'))
              .copyWith(
                type: ProfileType.file,
                url: '',
                autoUpdate: false,
                zolnitAccountId: bundle.accountId,
                zolnitOrigin: session.api.origin.origin,
                zolnitBundleId: bundle.bundleId,
              );
          final parent = Directory(
            path.dirname(await zolnitBundlePath(profile)),
          );
          await parent.create(recursive: true);
          await _privateMode(parent.path, '700');
          final signed =
              session.signedSubscriptions?.active?.accountId ==
              bundle.accountId;
          if (!signed) {
            final validationDir = await parent.createTemp('validate-');
            staging = validationDir;
            final config = File(path.join(validationDir.path, 'config.yaml'));
            await config.writeAsString(
              yaml.encode(prepared.config),
              flush: true,
            );
            await _privateMode(config.path, '600');
            final message = await core.validateProfile(config.path, '');
            if (!current()) throw const ClientFailure('superseded');
            if (message.isNotEmpty) {
              throw const ClientFailure('invalid_client_bundle');
            }
          }
          if (!signed) await _saveClientBundle(profile, bundle, clock());
          if (!current()) throw const ClientFailure('superseded');
          final keep = <String>{if (!signed) await zolnitBundlePath(profile)};
          if (!signed && existing?.zolnitBundleId != null) {
            keep.add(await zolnitBundlePath(existing!));
          }
          await for (final entry in parent.list(followLinks: false)) {
            if (entry is File &&
                RegExp(
                  r'^[0-9a-f]{64}\.json$',
                ).hasMatch(path.basename(entry.path)) &&
                !keep.contains(entry.path)) {
              await entry.delete();
            }
          }
          if (!current()) throw const ClientFailure('superseded');
          preparedProfile = profile.copyWith(lastUpdateDate: clock());
          profileId = profile.id;
        },
        publish: (_) {
          ref
              .read(profilesActionProvider.notifier)
              .putProfile(preparedProfile!);
        },
      );
      if (!current()) throw const ClientFailure('superseded');
      if (bundle == null) {
        throw ClientFailure(
          session.clientBundleFailure ?? 'bundle_unavailable',
        );
      }
      status.set(
        bundle.isFresh(clock())
            ? ZolnitBundleStatus.ready
            : ZolnitBundleStatus.expired,
      );
      activity.set(const ZolnitBundleActivity());
      return profileId;
    } catch (error) {
      if (!current()) throw const ClientFailure('superseded');
      final code = error is ClientFailure
          ? error.code
          : 'client_bundle_storage_failed';
      final kept = session.clientBundle;
      if (background &&
          _transientBundleFailure(code) &&
          kept != null &&
          kept.bundleId == retained.bundleId &&
          kept.isFresh(clock())) {
        activity.set(ZolnitBundleActivity(failure: code));
      } else {
        status.set(bundleFailureStatus(code));
        activity.set(const ZolnitBundleActivity());
      }
      throw ClientFailure(code);
    } finally {
      final validationDir = staging;
      if (validationDir != null && await validationDir.exists()) {
        await validationDir.delete(recursive: true);
      }
    }
  }

  return () {
    final generation = session.api.generation;
    if (pending != null && pendingGeneration == generation) return pending!;
    final operation = Future<int?>.microtask(sync);
    pending = operation;
    pendingGeneration = generation;
    return operation.whenComplete(() {
      if (identical(operation, pending)) pending = null;
    });
  };
}
