import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'data.dart';
import 'kit.dart';
import 'skin.dart';

class ZolnitInviteTab extends StatefulWidget {
  const ZolnitInviteTab({
    super.key,
    required this.session,
    this.compact = false,
  });

  final ZolnitSessionController session;
  final bool compact;

  @override
  State<ZolnitInviteTab> createState() => _ZolnitInviteTabState();
}

class _ZolnitInviteTabState extends State<ZolnitInviteTab> {
  ZolnitInvite? _invite;
  ClientFailure? _failure;
  bool _loading = false;
  bool _creating = false;
  String? _copied;
  late int _generation;

  bool _current(int generation, ZolnitSessionController session) =>
      mounted &&
      widget.session == session &&
      session.authenticated &&
      session.api.generation == generation &&
      _generation == generation;

  @override
  void initState() {
    super.initState();
    _generation = widget.session.api.generation;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ZolnitInviteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        _generation != widget.session.api.generation) {
      _generation = widget.session.api.generation;
      _loading = false;
      _invite = null;
      _failure = null;
      _creating = false;
      _copied = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final session = widget.session;
    final generation = _generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final invite = await ZolnitInviteClient(session.api).overview();
      if (_current(generation, session)) setState(() => _invite = invite);
    } catch (error) {
      if (_current(generation, session)) {
        setState(() {
          _failure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    } finally {
      if (_current(generation, session)) setState(() => _loading = false);
    }
  }

  Future<void> _createCode() async {
    if (_creating || _loading) return;
    final session = widget.session;
    final generation = _generation;
    setState(() {
      _creating = true;
      _failure = null;
    });
    try {
      await ZolnitInviteClient(session.api).createCode();
      if (_current(generation, session)) await _load();
    } catch (error) {
      if (_current(generation, session)) {
        setState(() {
          _failure = error is ClientFailure
              ? error
              : const ClientFailure('invite_failed');
        });
      }
    } finally {
      if (_current(generation, session)) setState(() => _creating = false);
    }
  }

  Future<void> _copyCode(String code, {bool link = false}) async {
    final session = widget.session;
    final generation = _generation;
    final text = context.appLocalizations;
    try {
      final value = link
          ? zolnitInviteLink(
              Uri.parse('https://link.zolmid.com'),
              code,
            ).toString()
          : code;
      await Clipboard.setData(ClipboardData(text: value));
      if (_current(generation, session)) {
        setState(() {
          _failure = null;
          _copied = link
              ? text.zolnitInviteCopied
              : text.zolnitInviteCodeCopied;
        });
      }
    } catch (error) {
      if (_current(generation, session)) {
        setState(() {
          _copied = null;
          _failure = error is ClientFailure
              ? error
              : const ClientFailure('client_error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    final stats = _invite?.stats;
    final codes = _invite?.codes ?? const [];

    return ListView(
      padding: zolnitPagePadding(skin, compact: widget.compact),
      children: [
        ZolnitPageHeading(
          title: text.zolnitInviteHeadline,
          subtitle: text.zolnitInviteSubtitle,
        ),
        const SizedBox(height: 24),
        if (_loading && _invite == null)
          const Center(child: CommonCircleLoading(size: 22))
        else if (_failure != null && _invite == null)
          ZolnitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  zolnitFailureText(
                    context,
                    _failure!.code,
                    _failure!.serverMessage,
                    fallback: text.zolnitInviteLoadFailed,
                  ),
                  style: zolnitText(context, 12, color: colors.muted),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _loading ? null : _load,
                    child: Text(text.zolnitRefresh),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _InviteMetrics(stats: stats),
          const SizedBox(height: 20),
          ZolnitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ZolnitSectionHeading(
                  title: text.zolnitInviteShare,
                  subtitle: text.zolnitInviteShareHint,
                  actionLabel: text.zolnitRefresh,
                  onAction: _loading || _creating ? null : _load,
                ),
                const SizedBox(height: 16),
                if (codes.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.zolnitInviteNoData,
                        style: zolnitText(context, 12, color: colors.muted),
                      ),
                      const SizedBox(height: 12),
                      ZolnitButton(
                        label: text.zolnitInviteCreateCode,
                        onPressed: _creating || _loading ? null : _createCode,
                      ),
                    ],
                  )
                else
                  for (final code in codes) ...[
                    _InviteCodeRow(
                      code: code,
                      onCopyCode: () => _copyCode(code.code),
                      onCopyLink: () => _copyCode(code.code, link: true),
                    ),
                    const SizedBox(height: 12),
                  ],
                if (codes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ZolnitButton(
                      label: text.zolnitInviteCreateCode,
                      onPressed: _creating || _loading ? null : _createCode,
                    ),
                  ),
                ],
                if (_copied != null)
                  Text(
                    _copied!,
                    style: zolnitText(context, 12, color: colors.sage),
                  ),
              ],
            ),
          ),
          if (_failure != null) ...[
            const SizedBox(height: 12),
            ZolnitFailureMessage(
              code: _failure!.code,
              serverMessage: _failure!.serverMessage,
            ),
          ],
        ],
      ],
    );
  }
}

class _InviteMetrics extends StatelessWidget {
  const _InviteMetrics({required this.stats});

  final ZolnitInviteStats? stats;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    final phone = !skin.desktop;

    String metric(int? cents) {
      if (cents == null) return '\u2014';
      return zolnitMoney(cents);
    }

    final items = [
      (
        text.zolnitInviteRegistered,
        stats != null ? '${stats!.registeredCount}' : '\u2014',
        text.zolnitInvitePeople,
        AppGlyphs.account,
        colors.blue,
      ),
      (
        text.zolnitInviteCommissionConfirmed,
        metric(stats?.confirmedCommissionCents),
        null as String?,
        AppGlyphs.layers,
        colors.sage,
      ),
      (
        text.zolnitInviteCommissionPending,
        metric(stats?.pendingCommissionCents),
        null,
        AppGlyphs.clock,
        colors.clay,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = phone ? 1 : (constraints.maxWidth >= 660 ? 3 : 2);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (label, value, unit, glyph, tint) in items)
              SizedBox(
                width: width,
                child: ZolnitStatTile(
                  label: label,
                  value: value,
                  unit: unit,
                  glyph: glyph,
                  tint: tint,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InviteCodeRow extends StatelessWidget {
  const _InviteCodeRow({
    required this.code,
    required this.onCopyCode,
    required this.onCopyLink,
  });

  final ZolnitInviteCode code;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    return ZolnitCard(
      color: colors.soft,
      bordered: false,
      corner: skin.tileCorner,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  code.code,
                  style: zolnitText(
                    context,
                    14,
                    weight: FontWeight.w600,
                    spacing: 1.2,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCopyCode,
                child: Text(text.zolnitCopyCode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onCopyLink,
              child: Text(text.zolnitCopyLink),
            ),
          ),
          if (code.createdAt case final date?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat.yMMMd().format(date.toLocal()),
                style: zolnitText(context, 10, color: colors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
