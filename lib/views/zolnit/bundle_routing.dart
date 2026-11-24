import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/common/zolnit_routing.dart';
import 'package:fl_clash/common/zolnit_return_route.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_routing.dart';
import 'package:fl_clash/providers/zolnit_return_route.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'kit.dart';
import 'node_groups.dart';
import 'skin.dart';

class ZolnitBundleRoutingPanel extends ConsumerStatefulWidget {
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
  ConsumerState<ZolnitBundleRoutingPanel> createState() =>
      _ZolnitBundleRoutingPanelState();
}

class _ZolnitBundleRoutingPanelState
    extends ConsumerState<ZolnitBundleRoutingPanel> {
  late final RouteTracker _routeTracker = ref.read(
    routeTrackerProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    _routeTracker.attach();
  }

  @override
  void dispose() {
    _routeTracker.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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
        services
            .where((s) => s.route.id == widget.selectedServiceId)
            .firstOrNull ??
        services.firstOrNull;
    final groups = ref.watch(groupsProvider);
    final policy = service == null ? null : groups.getGroup(service.groupName);
    final managed =
        profile != null && isCurrentZolnitBundleProfile(profile, session);
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final returnRoute = currentZolnitReturnRoute(session, profile, groups);
    final returnEnabled =
        connected &&
        !ref.watch(safeModeProvider) &&
        bundle?.isFresh(ref.read(zolnitBundleClockProvider)()) == true;
    final available =
        managed &&
        profile.zolnitBundleId == bundle?.bundleId &&
        !ref.watch(safeModeProvider) &&
        connected &&
        policy?.type == GroupType.Selector;
    final now = ref.read(zolnitBundleClockProvider)();
    final eligible =
        service != null &&
        bundle!.routingManifest.nodes.any(
          (node) =>
              node.enabled &&
              node.verified &&
              node.failureDomain.isNotEmpty &&
              node.services.contains(service.route.id) &&
              service.route.allowedCountries.contains(node.countryCode) &&
              (!service.route.isAi || node.countryCode != 'HK'),
        );
    final automaticAllowed = ref.watch(zolnitClientBundleAutomaticProvider);
    final leaseReady = ref.watch(zolnitCoreLeaseReadyProvider);
    final autoEnabled =
        automaticAllowed &&
        leaseReady &&
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
      ZolnitBundleStatus.refreshFailed =>
        bundle == null
            ? l10n.zolnitBundleUnavailable
            : l10n.zolnitBundleRefreshFailed,
      ZolnitBundleStatus.unavailable => l10n.zolnitBundleUnavailable,
      ZolnitBundleStatus.loading => l10n.loading,
      _ =>
        bundle != null && !eligible
            ? l10n.zolnitBundleNoCandidates
            : bundle != null && !automaticAllowed
            ? l10n.zolnitBundleAutomaticPending
            : bundle != null && !leaseReady
            ? l10n.zolnitRoutePreparing
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
    final liveAutoExit =
        available &&
            leaseReady &&
            service != null &&
            mode == service.route.groupName
        ? ref.watch(
            routeTrackerProvider.select(
              (route) =>
                  route.live &&
                      route.picks[service.groupName] == service.route.groupName
                  ? route.picks[service.route.groupName]
                  : null,
            ),
          )
        : null;
    final target = service == null
        ? null
        : zolnitAppliedRoute(
            groups,
            service.groupName,
            picks: {service.route.groupName: ?liveAutoExit},
          );
    final manualGroup = service == null
        ? null
        : groups.getGroup(service.manualGroup);
    final manualMembers = {
      for (final proxy in manualGroup?.all ?? const <Proxy>[])
        if (isSmartRoutingProxyType(proxy.type)) proxy.name,
    };
    final manualNodes =
        bundle?.outbounds
            .where((node) => manualMembers.contains(node.proxyName))
            .toList() ??
        const <ZolnitBundleOutbound>[];
    final outbound = bundle?.outbounds
        .where((node) => node.proxyName == target)
        .firstOrNull;
    Widget currentLabel(String name) => Text(
      name,
      key: const ValueKey('bundle-current-route'),
      style: zolnitText(context, 11, color: ZolnitColors.of(context).muted),
    );
    if (message == null &&
        (!managed || service == null) &&
        returnRoute == null) {
      return const SizedBox.shrink();
    }
    final colors = ZolnitColors.of(context);
    final serviceScope = (
      session,
      session.api.generation,
      bundle?.bundleId,
      profile?.id,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ZolnitCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (returnRoute != null) ...[
              _ReturnControls(
                session: session,
                route: returnRoute,
                enabled: returnEnabled,
              ),
              const SizedBox(height: 12),
            ],
            if (message != null)
              Text(
                message,
                key: const ValueKey('bundle-status'),
                style: zolnitText(context, 12, color: colors.muted),
              ),
            if (managed && service != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    key: const ValueKey('bundle-service'),
                    value: service.route.id,
                    isExpanded: true,
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
                      if (value != null) widget.onServiceChanged(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.mode,
                    style: zolnitText(context, 12, color: colors.muted),
                  ),
                  _ServiceModeControl(
                    key: ValueKey((serviceScope, service.groupName)),
                    service: service,
                    mode: mode,
                    available: available,
                    autoEnabled: autoEnabled,
                    session: session,
                    manualNodes: manualNodes,
                    manualSelection: manualGroup?.realNow,
                  ),
                ],
              ),
              if (mode != service.manualGroup && !connected)
                currentLabel(l10n.disconnected)
              else if (mode != service.manualGroup &&
                  bundle != null &&
                  outbound != null)
                FutureBuilder<ZolnitRouteMetadata>(
                  future: loadZolnitRouteMetadata(bundle),
                  initialData: cachedZolnitRouteMetadata(bundle),
                  builder: (context, snapshot) {
                    final metadata = snapshot.data;
                    final entry = metadata == null
                        ? null
                        : groupZolnitRoutes(
                            session.nodeList,
                            hosts: metadata.hosts,
                            paths: metadata.paths,
                            exitIds: bundle.exitIds,
                          ).where((row) => row.contains(target)).firstOrNull;
                    return currentLabel(
                      l10n.zolnitRouteCurrent(
                        entry?.title ??
                            zolnitDisplayTitle(outbound.displayName),
                      ),
                    );
                  },
                )
              else if (target == 'DIRECT' && mode != service.manualGroup)
                currentLabel(l10n.zolnitRouteCurrent(l10n.direct))
              else if (mode == service.route.groupName && message == null)
                currentLabel(
                  groups.getGroup(service.route.groupName) == null
                      ? l10n.zolnitRoutePreparing
                      : l10n.zolnitRouteUnverified,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceModeControl extends ConsumerStatefulWidget {
  const _ServiceModeControl({
    super.key,
    required this.service,
    required this.mode,
    required this.available,
    required this.autoEnabled,
    required this.session,
    required this.manualNodes,
    required this.manualSelection,
  });

  final List<ZolnitBundleOutbound> manualNodes;
  final String? manualSelection;
  final ManagedRouteService service;
  final String? mode;
  final bool available;
  final bool autoEnabled;
  final ZolnitSessionController session;

  @override
  ConsumerState<_ServiceModeControl> createState() =>
      _ServiceModeControlState();
}

class _ServiceModeControlState extends ConsumerState<_ServiceModeControl> {
  int _revision = 0;
  String? _pending;
  String? _pendingRoute;
  bool _failed = false;

  Future<void> _change(String value, {bool manual = false}) async {
    final revision = ++_revision;
    final profileId = ref.read(currentProfileProvider)?.id;
    final bundleId = widget.session.clientBundle?.bundleId;
    final generation = widget.session.api.generation;
    final container = ProviderScope.containerOf(context, listen: false);
    final session = widget.session;
    final configuration = ref
        .read(coreHandlerProvider)
        .configurationChanges
        .value;
    setState(() {
      _pending = manual ? null : value;
      _pendingRoute = manual ? value : null;
      _failed = false;
    });
    bool sameScope() =>
        session.authenticated &&
        identical(
          container.read(coreHandlerProvider).configurationChanges.value,
          configuration,
        ) &&
        container.read(currentProfileProvider)?.id == profileId &&
        session.clientBundle?.bundleId == bundleId &&
        session.api.generation == generation &&
        container.read(coreStatusProvider) == CoreStatus.connected &&
        !container.read(safeModeProvider);
    bool current() => mounted && revision == _revision && sameScope();
    var applied = false;
    try {
      applied = await ref
          .read(proxiesActionProvider.notifier)
          .changeProxyIfCurrent(
            groupName: manual
                ? widget.service.manualGroup
                : widget.service.groupName,
            proxyName: value,
            isCurrent: current,
          );
      if (applied &&
          current() &&
          !manual &&
          value == widget.service.route.groupName) {
        ref.read(zolnitRoutingProvider).kick();
      }
    } catch (_) {
      applied = false;
    } finally {
      if (mounted && revision == _revision) {
        setState(() {
          _pending = null;
          _pendingRoute = null;
          _failed = !applied && sameScope();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          key: const ValueKey('bundle-routing-mode'),
          value: _pending ?? widget.mode,
          isExpanded: true,
          hint: Text(text.unknown),
          icon: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem(
              value: widget.service.route.groupName,
              enabled: widget.autoEnabled,
              child: Text(text.auto),
            ),
            DropdownMenuItem(
              value: widget.service.manualGroup,
              child: Text(text.manual),
            ),
            DropdownMenuItem(value: 'DIRECT', child: Text(text.direct)),
          ],
          onChanged: !widget.available
              ? null
              : (value) {
                  if (value != null &&
                      value != (_pending ?? widget.mode) &&
                      (value != widget.service.route.groupName ||
                          widget.autoEnabled)) {
                    unawaited(_change(value));
                  }
                },
        ),
        if ((_pending ?? widget.mode) == widget.service.manualGroup) ...[
          DropdownButton<String>(
            key: const ValueKey('bundle-manual-route'),
            value:
                widget.manualNodes.any(
                  (node) =>
                      node.proxyName ==
                      (_pendingRoute ?? widget.manualSelection),
                )
                ? (_pendingRoute ?? widget.manualSelection)
                : null,
            isExpanded: true,
            hint: Text(text.zolnitChooseRoute),
            icon: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
            underline: const SizedBox.shrink(),
            items: [
              for (final node in widget.manualNodes)
                DropdownMenuItem(
                  value: node.proxyName,
                  child: Text(
                    zolnitDisplayTitle(node.displayName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged:
                !widget.available ||
                    _pending != null ||
                    widget.manualNodes.isEmpty
                ? null
                : (value) {
                    if (value != null &&
                        widget.manualNodes.any(
                          (node) => node.proxyName == value,
                        ) &&
                        value != (_pendingRoute ?? widget.manualSelection)) {
                      unawaited(_change(value, manual: true));
                    }
                  },
          ),
        ],
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Semantics(
            liveRegion: _pending != null || _pendingRoute != null || _failed,
            child: _pending != null || _pendingRoute != null
                ? Text(
                    text.loading,
                    key: const ValueKey('bundle-mode-pending'),
                    style: zolnitText(context, 12, color: colors.muted),
                  )
                : _failed
                ? Text(
                    text.zolnitRouteChangeFailed,
                    key: const ValueKey('bundle-mode-error'),
                    style: zolnitText(
                      context,
                      12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _ReturnControls extends ConsumerStatefulWidget {
  const _ReturnControls({
    required this.session,
    required this.route,
    required this.enabled,
  });

  final ZolnitSessionController session;
  final ZolnitReturnRoute route;
  final bool enabled;

  @override
  ConsumerState<_ReturnControls> createState() => _ReturnControlsState();
}

class _ReturnControlsState extends ConsumerState<_ReturnControls> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _change(bool enabled, {String? optionId}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final applied = await setZolnitReturnRouting(
        ref,
        widget.session,
        enabled,
        optionId: optionId,
      );
      if (mounted && !applied) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final route = widget.route;
    final available = widget.enabled && route.activationAvailable && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.zolnitReturnRoute, style: zolnitText(context, 13)),
        if (route.activationAvailable)
          Row(
            children: [
              Expanded(child: Text(text.zolnitReturnEnabled)),
              Switch(
                key: const ValueKey('bundle-return-enabled'),
                value: route.active,
                onChanged:
                    available && (route.active || route.options.isNotEmpty)
                    ? (value) => unawaited(_change(value))
                    : null,
              ),
            ],
          ),
        if (!route.active)
          Text(text.zolnitReturnLocal, style: zolnitText(context, 12)),
        DropdownButton<String>(
          key: const ValueKey('bundle-return-route'),
          isExpanded: true,
          value: route.selectedId,
          hint: Text(
            route.options.isEmpty
                ? text.zolnitRouteUnavailable
                : text.zolnitSelectServer,
          ),
          icon: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
          underline: const SizedBox.shrink(),
          items: [
            for (final option in route.options)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.label(text)),
              ),
          ],
          onChanged: available && route.active && route.options.isNotEmpty
              ? (value) {
                  if (value != null) {
                    unawaited(_change(true, optionId: value));
                  }
                }
              : null,
        ),
        if (_busy)
          Text(
            text.loading,
            key: const ValueKey('bundle-return-pending'),
            style: zolnitText(context, 12),
          ),
        if (_failed)
          Text(
            text.zolnitRouteChangeFailed,
            key: const ValueKey('bundle-return-error'),
            style: zolnitText(context, 12),
          ),
      ],
    );
  }
}
