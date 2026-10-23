import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'catalogue.dart';
import 'connect.dart' show zolnitDisplayName;
import 'data.dart';
import 'invite.dart';
import 'kit.dart';
import 'password.dart';
import 'skin.dart';

enum ZolnitAccountTab { info, orders, invite }

class ZolnitAccountPage extends StatefulWidget {
  const ZolnitAccountPage({
    super.key,
    required this.session,
    required this.tab,
    required this.onTabChanged,
    required this.showPlans,
    required this.showPreferences,
    required this.openHelp,
    required this.logout,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final ZolnitAccountTab tab;
  final ValueChanged<ZolnitAccountTab> onTabChanged;
  final VoidCallback showPlans;
  final VoidCallback showPreferences;
  final VoidCallback openHelp;
  final VoidCallback logout;
  final bool compact;

  @override
  State<ZolnitAccountPage> createState() => _ZolnitAccountPageState();
}

class _ZolnitAccountPageState extends State<ZolnitAccountPage> {
  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final tabs = [
      (ZolnitAccountTab.info, text.zolnitTabAccount),
      (ZolnitAccountTab.orders, text.zolnitTabOrders),
      (ZolnitAccountTab.invite, text.zolnitTabInvite),
    ];
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: skin.gutter,
            vertical: skin.desktop ? 8 : 12,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ZolnitSegmented<ZolnitAccountTab>(
              options: tabs,
              value: widget.tab,
              onChanged: widget.onTabChanged,
              underlined: skin != ZolnitSkin.macos && skin != ZolnitSkin.ios,
            ),
          ),
        ),
        Expanded(
          child: switch (widget.tab) {
            ZolnitAccountTab.info => _AccountInfoTab(
              session: widget.session,
              showPlans: widget.showPlans,
              showPreferences: widget.showPreferences,
              openHelp: widget.openHelp,
              logout: widget.logout,
              compact: widget.compact,
            ),
            ZolnitAccountTab.orders => ZolnitOrdersPage(
              session: widget.session,
            ),
            ZolnitAccountTab.invite => ZolnitInviteTab(
              session: widget.session,
              compact: widget.compact,
            ),
          },
        ),
      ],
    );
  }
}

class _AccountInfoTab extends StatefulWidget {
  const _AccountInfoTab({
    required this.session,
    required this.showPlans,
    required this.showPreferences,
    required this.openHelp,
    required this.logout,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final VoidCallback showPlans;
  final VoidCallback showPreferences;
  final VoidCallback openHelp;
  final VoidCallback logout;
  final bool compact;

  @override
  State<_AccountInfoTab> createState() => _AccountInfoTabState();
}

class _AccountInfoTabState extends State<_AccountInfoTab> {
  List<ZolnitDevice>? _devices;
  ClientFailure? _deviceFailure;
  bool _loading = false;
  String? _revoking;
  bool _passwordChanged = false;
  late int _generation;

  bool _current(int generation) =>
      mounted &&
      widget.session.authenticated &&
      widget.session.api.generation == generation &&
      _generation == generation;

  @override
  void initState() {
    super.initState();
    _generation = widget.session.api.generation;
    unawaited(_loadDevices());
  }

  @override
  void didUpdateWidget(covariant _AccountInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        _generation != widget.session.api.generation) {
      _generation = widget.session.api.generation;
      _loading = false;
      _devices = null;
      _deviceFailure = null;
      _revoking = null;
      _passwordChanged = false;
      unawaited(_loadDevices());
    }
  }

  Future<void> _loadDevices() async {
    if (_loading) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _deviceFailure = null;
    });
    try {
      final devices = await ZolnitAccountClient(widget.session.api).devices();
      if (_current(generation)) setState(() => _devices = devices);
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _deviceFailure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(ZolnitDevice device) async {
    if (_revoking != null) return;
    final generation = _generation;
    final text = context.appLocalizations;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.zolnitRevokeDevice),
        content: Text(text.zolnitRevokeDeviceTip),
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
    if (approved != true || !_current(generation) || _revoking != null) return;
    setState(() {
      _revoking = device.id;
      _deviceFailure = null;
    });
    try {
      await ZolnitAccountClient(widget.session.api).removeDevice(device.id);
      if (_current(generation)) await _loadDevices();
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _deviceFailure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    } finally {
      if (_current(generation)) setState(() => _revoking = null);
    }
  }

  Future<void> _password() async {
    final generation = _generation;
    final changed = await showFormSheet<bool>(
      context: context,
      builder: (_) => ZolnitPasswordForm(session: widget.session),
    );
    if (changed == true && _current(generation)) {
      setState(() => _passwordChanged = true);
    }
  }

  Future<void> _renewal(int id, bool resume) async {
    final text = context.appLocalizations;
    final generation = _generation;
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
    if (approved == true && _current(generation)) {
      await (resume
          ? widget.session.resumeRenewal(id)
          : widget.session.cancelRenewal(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    final session = widget.session;
    final usage = session.usage;
    final name = zolnitDisplayName(session.account, usage);
    final account = ZolnitAccountInfo.fromJson(session.account ?? {});
    final overview = session.billingOverview;
    final entitlement = overview?['entitlement'];
    final source = entitlement is Json ? entitlement['source'] : null;
    final expires = usage?.expiresAt;
    final contracts = overview?['subscriptions'];
    final profile = ZolnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.blue,
                  shape: AppShape.all(skin.badgeCorner),
                ),
                child: SizedBox.square(
                  dimension: 52,
                  child: Center(
                    child: Text(
                      name.characters.first,
                      style: zolnitText(context, 24, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: zolnitText(context, 23, weight: FontWeight.w600),
                ),
              ),
              if (usage?.planName case final plan?)
                Flexible(child: ZolnitPill(label: plan)),
            ],
          ),
          const SizedBox(height: 20),
          _AccountRow(
            label: text.zolnitEmail,
            value: account?.email ?? usage?.email ?? '—',
          ),
          _AccountRow(
            label: text.zolnitAccountPassword,
            child: TextButton(
              onPressed: session.busy ? null : _password,
              child: Text(text.zolnitChangePassword),
            ),
          ),
          _AccountRow(
            label: text.zolnitPlanValidity,
            value: expires != null
                ? zolnitDotDate(expires)
                : entitlement is Json
                ? zolnitDate(entitlement['expires_at'])
                : '—',
          ),
          _AccountRow(
            label: text.zolnitBalance,
            value: zolnitMoney(session.account?['balance']),
          ),
          if (source == 'gift' || source == 'paid') ...[
            const SizedBox(height: 12),
            Text(
              source == 'gift' ? text.zolnitGift : text.zolnitPaid,
              style: zolnitText(context, 12, color: colors.muted),
            ),
          ],
          if (_passwordChanged) ...[
            const SizedBox(height: 12),
            Text(text.zolnitPasswordUpdated),
          ],
        ],
      ),
    );
    final devices = ZolnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZolnitSectionHeading(
            title: text.zolnitDevicesTitle,
            subtitle: text.zolnitDevicesHint,
            actionLabel: text.zolnitRefresh,
            onAction: _loading || _revoking != null ? null : _loadDevices,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CommonCircleLoading(size: 22))
          else if (_deviceFailure case final failure?)
            Text(
              zolnitFailureText(
                context,
                failure.code,
                failure.serverMessage,
                fallback: text.zolnitDevicesUnavailable,
              ),
              style: zolnitText(context, 12, color: colors.muted),
            )
          else if (_devices?.isEmpty == true)
            Text(text.zolnitNoDevices)
          else
            for (final device in _devices ?? const <ZolnitDevice>[]) ...[
              Row(
                children: [
                  GlyphIcon(AppGlyphs.devices, size: 22, color: colors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.label ?? text.zolnitUnknownDevice,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            13,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (device.lastUsedAt case final date?)
                          Text(
                            DateFormat.yMMMd().add_Hm().format(date.toLocal()),
                            style: zolnitText(context, 11, color: colors.muted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('zolnit-revoke-${device.id}'),
                    tooltip: text.zolnitRevokeDevice,
                    onPressed: _revoking != null ? null : () => _revoke(device),
                    icon: const GlyphIcon(AppGlyphs.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
    final actions = LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        final entries = [
          (
            AppGlyphs.layers,
            text.zolnitPlans,
            usage?.planName ?? text.zolnitNoPlan,
            widget.showPlans,
          ),
          (
            AppGlyphs.help,
            text.zolnitHelpSupport,
            text.zolnitAccountHelpHint,
            widget.openHelp,
          ),
          (
            AppGlyphs.settings,
            text.zolnitPreferences,
            text.zolnitAccountPreferencesHint,
            widget.showPreferences,
          ),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (glyph, title, hint, action) in entries)
              SizedBox(
                width: width,
                child: _AccountAction(
                  glyph: glyph,
                  title: title,
                  hint: hint,
                  onTap: action,
                ),
              ),
          ],
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            skin.desktop && !widget.compact && constraints.maxWidth >= 1000;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [profile, const SizedBox(height: 20), actions],
        );
        return ListView(
          padding: zolnitPagePadding(skin, compact: widget.compact),
          children: [
            ZolnitPageHeading(
              title: text.zolnitAccountTitle,
              subtitle: text.zolnitAccountSubtitle,
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: details),
                  const SizedBox(width: 22),
                  Expanded(flex: 2, child: devices),
                ],
              )
            else ...[
              details,
              const SizedBox(height: 20),
              devices,
            ],
            const SizedBox(height: 24),
            ZolnitCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.zolnitRenewals,
                    style: zolnitText(context, 17, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (session.billingFailure != null)
                    Text(
                      zolnitFailureText(
                        context,
                        session.billingFailure,
                        session.billingFailureMessage,
                        fallback: text.zolnitBillingUnavailable,
                      ),
                    )
                  else if (contracts is! List || contracts.isEmpty)
                    Text(text.zolnitNoRenewals),
                  if (contracts is List)
                    for (final contract in contracts.whereType<Json>()) ...[
                      Text(
                        contract['plan_name'] is String
                            ? contract['plan_name'] as String
                            : text.zolnitRenewals,
                        style: zolnitText(context, 14, weight: FontWeight.w600),
                      ),
                      _AccountRow(
                        label: text.zolnitPaidThrough,
                        value: zolnitDate(contract['paid_through']),
                      ),
                      _AccountRow(
                        label: text.zolnitNextRenewal,
                        value: zolnitDate(contract['next_renewal_at']),
                      ),
                      if (contract['id'] is int &&
                          contract['can_cancel'] == true)
                        TextButton(
                          onPressed: session.busy
                              ? null
                              : () => _renewal(contract['id'] as int, false),
                          child: Text(text.zolnitCancelRenewal),
                        ),
                      if (contract['id'] is int &&
                          contract['can_resume'] == true)
                        TextButton(
                          onPressed:
                              session.busy || !session.checkout.allowStripe
                              ? null
                              : () => _renewal(contract['id'] as int, true),
                          child: Text(text.zolnitResumeRenewal),
                        ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: session.busy || _revoking != null
                  ? null
                  : widget.logout,
              child: Text(text.zolnitSignOut),
            ),
            ZolnitFailureMessage(
              code: session.failure,
              serverMessage: session.failureMessage,
            ),
          ],
        );
      },
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.glyph,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final Glyph glyph;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    return ZolnitCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        customBorder: AppShape.all(skin.panelCorner),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              GlyphIcon(glyph, size: 23, color: colors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: zolnitText(context, 13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: zolnitText(context, 11, color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GlyphIcon(
                AppGlyphs.chevronForward,
                size: 14,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 6,
        children: [
          Text(label, style: zolnitText(context, 12, color: colors.muted)),
          child ?? Text(value ?? '—', style: zolnitText(context, 13)),
        ],
      ),
    );
  }
}
