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
import 'motion.dart';
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
    required this.onCheckout,
    required this.showRewards,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final ZolnitAccountTab tab;
  final ValueChanged<ZolnitAccountTab> onTabChanged;
  final VoidCallback showPlans;
  final VoidCallback showPreferences;
  final VoidCallback openHelp;
  final VoidCallback logout;
  final ValueChanged<String> onCheckout;
  final VoidCallback showRewards;
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
              showRewards: widget.showRewards,
              compact: widget.compact,
            ),
            ZolnitAccountTab.orders => ZolnitOrdersPage(
              session: widget.session,
              onCheckout: widget.onCheckout,
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
    required this.showRewards,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final VoidCallback showPlans;
  final VoidCallback showPreferences;
  final VoidCallback openHelp;
  final VoidCallback logout;
  final VoidCallback showRewards;
  final bool compact;

  @override
  State<_AccountInfoTab> createState() => _AccountInfoTabState();
}

class _AccountInfoTabState extends State<_AccountInfoTab>
    with WidgetsBindingObserver {
  List<ZolnitDevice>? _devices;
  ClientFailure? _deviceFailure;
  bool _loading = false;
  String? _revoking;
  bool _passwordChanged = false;
  bool _giftCardsAvailable = false;
  int _giftAvailabilityRequest = 0;
  Timer? _deviceTimer;
  late int _generation;

  bool _current(int generation) =>
      mounted &&
      widget.session.authenticated &&
      widget.session.api.generation == generation &&
      _generation == generation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deviceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        unawaited(_loadDevices());
      }
    });
    _generation = widget.session.api.generation;
    unawaited(_loadDevices());
    unawaited(_loadGiftCards());
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
      _giftCardsAvailable = false;
      unawaited(_loadDevices());
      unawaited(_loadGiftCards());
    }
  }

  Future<void> _loadGiftCards() async {
    final generation = _generation;
    final session = widget.session;
    final request = ++_giftAvailabilityRequest;
    try {
      final available = await ZolnitRewardsClient(
        session.api,
      ).giftCardsAvailable();
      if (_current(generation) &&
          identical(widget.session, session) &&
          request == _giftAvailabilityRequest) {
        setState(() => _giftCardsAvailable = available);
      }
    } catch (_) {
      if (_current(generation) &&
          identical(widget.session, session) &&
          request == _giftAvailabilityRequest) {
        setState(() => _giftCardsAvailable = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadDevices());
      unawaited(_loadGiftCards());
    }
  }

  @override
  void dispose() {
    _deviceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadDevices() async {
    if (_loading) return;
    final generation = _generation;
    final session = widget.session;
    bool current() =>
        _current(generation) && identical(widget.session, session);
    setState(() {
      _loading = true;
      _deviceFailure = null;
    });
    try {
      final devices = await ZolnitAccountClient(session.api).devices();
      if (current()) setState(() => _devices = devices);
    } catch (error) {
      if (current() &&
          error is ClientFailure &&
          error.code == 'unauthenticated') {
        await session.refresh();
      }
      if (current()) {
        setState(() {
          _deviceFailure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(ZolnitDevice device) async {
    if (_revoking != null) return;
    final generation = _generation;
    final session = widget.session;
    bool current() =>
        _current(generation) && identical(widget.session, session);
    final text = context.appLocalizations;
    final approved = await showZolnitDialog<bool>(
      context,
      (_) => ZolnitAlert(
        title: text.zolnitRevokeDevice,
        message: text.zolnitRevokeDeviceTip,
        cancelLabel: text.zolnitNotNow,
        confirmLabel: text.zolnitSignOut,
        destructive: true,
      ),
    );
    if (approved != true || !current() || _revoking != null) return;
    setState(() {
      _revoking = device.id;
      _deviceFailure = null;
    });
    try {
      await ZolnitAccountClient(session.api).removeDevice(device.id);
      if (current()) {
        await session.refresh();
        if (current()) await _loadDevices();
      }
    } catch (error) {
      if (current()) {
        setState(() {
          _deviceFailure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    } finally {
      if (current()) setState(() => _revoking = null);
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
    final title = resume ? text.zolnitResumeRenewal : text.zolnitCancelRenewal;
    final approved = await showZolnitDialog<bool>(
      context,
      (_) => ZolnitAlert(
        title: title,
        message: resume
            ? text.zolnitResumeRenewalTip
            : text.zolnitCancelRenewalTip,
        cancelLabel: text.zolnitNotNow,
        confirmLabel: title,
        destructive: !resume,
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
    final contracts = ZolnitRenewal.fromOverview(overview);
    final profile = ZolnitCard(
      padding: const EdgeInsets.all(16),
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
                  dimension: 40,
                  child: Center(
                    child: Text(
                      name.characters.first,
                      style: zolnitText(context, 20, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: zolnitText(context, 20, weight: FontWeight.w600),
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
          Text(
            text.zolnitDevicesHint,
            style: zolnitText(context, 11, color: colors.muted),
          ),
          const SizedBox(height: 16),
          if (_loading && _devices == null)
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
                          text.zolnitLoginSession(device.id),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: zolnitText(
                            context,
                            13,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (device.createdAt case final date?)
                          Text(
                            '${text.zolnitSessionCreated}: ${DateFormat.yMMMd().add_Hm().format(date.toLocal())}',
                            style: zolnitText(context, 11, color: colors.muted),
                          ),
                        if (device.lastUsedAt case final date?)
                          Text(
                            '${text.zolnitSessionLastActive}: ${DateFormat.yMMMd().add_Hm().format(date.toLocal())}',
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
    final entries = [
      if (_giftCardsAvailable)
        (
          AppGlyphs.layers,
          text.zolnitGiftCard,
          text.zolnitGiftPrompt,
          widget.showRewards,
        ),
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
    final actions = ZolnitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (glyph, title, hint, action) in entries)
            ListTile(
              leading: GlyphIcon(glyph, size: 22, color: colors.muted),
              title: Text(
                title,
                style: zolnitText(context, 13, weight: FontWeight.w600),
              ),
              subtitle: Text(
                hint,
                style: zolnitText(context, 11, color: colors.muted),
              ),
              trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
              onTap: action,
            ),
        ],
      ),
    );
    Widget renewalTile(ZolnitRenewal renewal) {
      final data = renewal.data;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  renewal.planName ?? text.zolnitRenewals,
                  style: zolnitText(context, 14, weight: FontWeight.w600),
                ),
                Text(
                  zolnitRenewalLabel(context, renewal.state),
                  style: zolnitText(context, 12, color: colors.accent),
                ),
              ],
            ),
            if (data['paid_through'] != null)
              _AccountRow(
                label: text.zolnitPaidThrough,
                value: zolnitDate(data['paid_through']),
              ),
            if (renewal.state != RenewalState.disabled &&
                data['next_renewal_at'] != null)
              _AccountRow(
                label: text.zolnitNextRenewal,
                value: zolnitDate(data['next_renewal_at']),
              ),
            if (renewal.id != null && renewal.canCancel)
              TextButton(
                onPressed: session.busy
                    ? null
                    : () => _renewal(renewal.id!, false),
                child: Text(text.zolnitCancelRenewal),
              ),
            if (renewal.id != null && renewal.canResume)
              TextButton(
                onPressed: session.busy || !session.checkout.allowStripe
                    ? null
                    : () => _renewal(renewal.id!, true),
                child: Text(text.zolnitResumeRenewal),
              ),
            if (renewal.state == RenewalState.pending)
              Text(
                text.zolnitPendingOrder,
                style: zolnitText(context, 11, color: colors.muted),
              ),
          ],
        ),
      );
    }

    final renewals = ZolnitCard(
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
          else if (contracts.isEmpty)
            Text(text.zolnitNoRenewals),
          for (final renewal in contracts.where(
            (item) => item.state != RenewalState.ended,
          ))
            renewalTile(renewal),
          if (contracts.any((item) => item.state == RenewalState.ended))
            ExpansionTile(
              trailing: const GlyphIcon(AppGlyphs.chevronDown, size: 16),
              tilePadding: EdgeInsets.zero,
              title: Text(
                text.zolnitRenewalHistory,
                style: zolnitText(context, 13),
              ),
              children: [
                for (final renewal in contracts.where(
                  (item) => item.state == RenewalState.ended,
                ))
                  renewalTile(renewal),
              ],
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 740;
        return ListView(
          padding: zolnitPagePadding(skin, compact: widget.compact),
          children: [
            Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: !wide
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: wide ? 3 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [profile, const SizedBox(height: 12), renewals],
                  ),
                ),
                SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 12),
                Flexible(
                  flex: wide ? 2 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions,
                      const SizedBox(height: 12),
                      ExpansionTile(
                        trailing: const GlyphIcon(
                          AppGlyphs.chevronDown,
                          size: 16,
                        ),
                        title: Text(text.zolnitDevicesTitle),
                        children: [devices],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = ZolnitColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
