import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/proxies/card.dart' show selectGroupProxy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';
import 'skin.dart';

class ZolnitBundleRoutingPanel extends ConsumerWidget {
  const ZolnitBundleRoutingPanel({
    super.key,
    required this.session,
    required this.selectedServiceId,
    required this.onServiceChanged,
  });
  final ZolnitSessionController session;
  final String selectedServiceId;
  final ValueChanged<String> onServiceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(zolnitClientBundleTransportProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.appLocalizations;
    final status = ref.watch(zolnitBundleStatusProvider);
    final bundle = session.clientBundle;
    final profile = ref.watch(currentProfileProvider);
    final services =
        bundle?.routingManifest.services ?? const <ManagedRouteService>[];
    final service =
        services.where((s) => s.route.id == selectedServiceId).firstOrNull ??
        services.firstOrNull;
    final groups = ref.watch(groupsProvider);
    final policy = service == null ? null : groups.getGroup(service.groupName);
    final managed =
        profile != null && isCurrentZolnitBundleProfile(profile, session);
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final available =
        managed &&
        !ref.watch(safeModeProvider) &&
        connected &&
        policy?.type == GroupType.Selector;
    final now = ref.read(zolnitBundleClockProvider)();
    final eligible =
        service != null &&
        bundle!.routingManifest.nodes.any(
          (node) =>
              node.enabled &&
              node.services.contains(service.route.id) &&
              service.route.allowedCountries.contains(node.countryCode) &&
              (!service.route.isAi || node.countryCode != 'HK'),
        );
    final automaticAllowed = ref.watch(zolnitClientBundleAutomaticProvider);
    final autoEnabled =
        automaticAllowed &&
        available &&
        bundle!.isFresh(now) &&
        eligible &&
        !{
          ZolnitBundleStatus.expired,
          ZolnitBundleStatus.forbidden,
          ZolnitBundleStatus.invalid,
          ZolnitBundleStatus.loading,
        }.contains(status);
    final failureMessage = switch (status) {
      ZolnitBundleStatus.expired => l10n.zolnitBundleExpired,
      ZolnitBundleStatus.forbidden => l10n.zolnitBundleForbidden,
      ZolnitBundleStatus.invalid => l10n.zolnitBundleInvalid,
      ZolnitBundleStatus.refreshFailed => l10n.zolnitBundleRefreshFailed,
      ZolnitBundleStatus.unavailable => l10n.zolnitBundleUnavailable,
      ZolnitBundleStatus.loading => l10n.loading,
      _ =>
        bundle != null && !eligible
            ? l10n.zolnitBundleNoCandidates
            : bundle != null && !automaticAllowed
            ? l10n.zolnitBundleAutomaticPending
            : null,
    };
    final message = bundle != null && !bundle.isFresh(now)
        ? l10n.zolnitBundleExpired +
              (failureMessage != null &&
                      status != ZolnitBundleStatus.expired &&
                      status != ZolnitBundleStatus.loading
                  ? ' $failureMessage'
                  : '')
        : failureMessage;
    String label(ManagedRouteService value) => switch (value.route.id) {
      'ai' => l10n.zolnitAiService,
      'media' => l10n.zolnitMediaService,
      _ => value.route.id,
    };
    final values = service == null
        ? const <String>[]
        : [service.route.groupName, service.manualGroup, 'DIRECT'];
    final mode = values.contains(policy?.realNow) ? policy!.realNow : null;
    final target = mode == 'DIRECT'
        ? 'DIRECT'
        : mode == null
        ? null
        : groups.getGroup(mode)?.realNow;
    final current = target == 'DIRECT'
        ? l10n.direct
        : target == null || target == 'REJECT'
        ? l10n.zolnitRouteUnavailable
        : bundle?.outbounds
                  .where((o) => o.proxyName == target)
                  .firstOrNull
                  ?.displayName ??
              l10n.unknown;
    if (message == null && (!managed || service == null)) {
      return const SizedBox.shrink();
    }
    final colors = ZolnitColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ZolnitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null)
              Text(
                message,
                key: const ValueKey('bundle-status'),
                style: zolnitText(context, 12, color: colors.muted),
              ),
            if (managed && service != null) ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    key: const ValueKey('bundle-service'),
                    value: service.route.id,
                    icon: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final item in services)
                        DropdownMenuItem(
                          value: item.route.id,
                          child: Text(label(item)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onServiceChanged(value);
                    },
                  ),
                  DropdownButton<String>(
                    key: const ValueKey('bundle-routing-mode'),
                    value: mode,
                    hint: Text(l10n.unknown),
                    icon: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: service.route.groupName,
                        enabled: autoEnabled,
                        child: Text(l10n.auto),
                      ),
                      DropdownMenuItem(
                        value: service.manualGroup,
                        child: Text(l10n.manual),
                      ),
                      DropdownMenuItem(
                        value: 'DIRECT',
                        child: Text(l10n.direct),
                      ),
                    ],
                    onChanged: !available
                        ? null
                        : (value) {
                            if (value == null ||
                                (value == service.route.groupName &&
                                    !autoEnabled) ||
                                !values.contains(value)) {
                              return;
                            }
                            selectGroupProxy(
                              ref,
                              groupName: service.groupName,
                              groupType: GroupType.Selector,
                              proxyName: value,
                            );
                          },
                  ),
                ],
              ),
              Text(
                connected
                    ? l10n.zolnitRouteCurrent(current)
                    : l10n.disconnected,
                key: const ValueKey('bundle-current-route'),
                style: zolnitText(context, 11, color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
