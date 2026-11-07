import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/zolnit_rewards.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'data.dart';
import 'kit.dart';
import 'skin.dart';

class ZolnitRewardsPage extends StatefulWidget {
  const ZolnitRewardsPage({
    super.key,
    required this.session,
    required this.onRedeemed,
    this.attemptStore,
    this.embedded = false,
  });

  final ZolnitSessionController session;
  final Future<void> Function() onRedeemed;
  final ZolnitGiftAttemptStore? attemptStore;
  final bool embedded;

  @override
  State<ZolnitRewardsPage> createState() => _ZolnitRewardsPageState();
}

class _ZolnitRewardsPageState extends State<ZolnitRewardsPage> {
  late final int _generation = widget.session.api.generation;
  late final ZolnitRewardsClient _client = ZolnitRewardsClient(
    widget.session.api,
  );
  late final ZolnitGiftAttemptStore? _store =
      widget.attemptStore ?? _accountStore();
  late final ZolnitGiftCardAttempt _attempt = ZolnitGiftCardAttempt(
    _client,
    store: _store,
  );
  final _input = TextEditingController();
  Json? _history;
  bool _busy = false;
  bool _historyBusy = false;
  bool _refreshFailed = false;
  bool _historyFailed = false;
  bool _error = false;
  int _historyRequest = 0;

  bool get _current =>
      mounted &&
      widget.session.authenticated &&
      widget.session.api.generation == _generation;

  ZolnitGiftAttemptStore? _accountStore() {
    final uuid = widget.session.account?['uuid'];
    if (uuid is! String || uuid.isEmpty) return null;
    return ZolnitGiftPreferencesStore(widget.session.api.origin, uuid);
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    unawaited(_loadHistory(1));
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (!_current) {
      _input.clear();
      _attempt.clear();
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _attempt.clear();
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(int page) async {
    if (!_current) return;
    final request = ++_historyRequest;
    setState(() {
      _historyBusy = true;
      _historyFailed = false;
    });
    try {
      final history = await _client.history(page: page);
      if (_current && request == _historyRequest) {
        setState(() => _history = history);
      }
    } catch (_) {
      if (_current && request == _historyRequest) {
        setState(() => _historyFailed = true);
      }
    } finally {
      if (_current && request == _historyRequest) {
        setState(() => _historyBusy = false);
      }
    }
  }

  Future<void> _check() async {
    if (_busy || _input.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      if (_store == null) {
        throw const ClientFailure('account_identity_unavailable');
      }
      await _attempt.recover();
      await _attempt.check();
    } catch (_) {
      if (_current) setState(() => _error = true);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (!_current) return;
    try {
      await widget.onRedeemed();
      if (_current) setState(() => _refreshFailed = false);
    } catch (_) {
      if (_current) setState(() => _refreshFailed = true);
    }
  }

  Future<void> _redeem() async {
    if (_busy) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await _attempt.redeem();
      if (!_current) return;
      _input.clear();
      setState(() {});
      await Future.wait([_refresh(), _loadHistory(1)]);
    } catch (_) {
      if (_current) setState(() => _error = true);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Widget _rewards(Object? value) {
    final text = context.appLocalizations;
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in value)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: ZolnitColors.of(context).soft,
                shape: AppShape.sm,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: _rewards(item),
                ),
              ),
            ),
        ],
      );
    }
    if (value is! Json) return const SizedBox.shrink();
    final plan = value['plan'];
    final lines = <(String, String)>[
      if (value['balance'] is num)
        (text.zolnitGiftBalance, '+${zolnitMoney(value['balance'])}'),
      if (value['transfer_enable'] is num)
        (text.traffic, zolnitBytes(value['transfer_enable'])),
      if (value['expire_days'] is num)
        (
          text.zolnitPlanValidity,
          '${value['expire_days']} ${text.zolnitDaysUnit}',
        ),
      if (value['device_limit'] is int)
        ('', text.zolnitFeatureDevices(value['device_limit'])),
      if (value['reset_package'] == true || value['reset_package'] == 1)
        ('', text.zolnitResetTraffic),
      if (plan is Json && plan['name'] is String)
        (text.zolnitPlans, plan['name'] as String),
      if (plan is Json && plan['non_expiring'] == true)
        (text.zolnitPlanValidity, text.infiniteTime)
      else if (plan is Json &&
          plan['validity_days'] is num &&
          (plan['validity_days'] as num) > 0)
        (
          text.zolnitPlanValidity,
          '${plan['validity_days']} ${text.zolnitDaysUnit}',
        )
      else if (value['plan_validity_days'] is num &&
          (value['plan_validity_days'] as num) > 0)
        (
          text.zolnitPlanValidity,
          '${value['plan_validity_days']} ${text.zolnitDaysUnit}',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, amount) in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              children: [
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: zolnitText(
                      context,
                      12,
                      color: ZolnitColors.of(context).muted,
                    ),
                  ),
                Text(
                  amount,
                  style: zolnitText(context, 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _safeReason(String reason) {
    final code = _input.text.trim();
    if (code.isEmpty) return reason;
    return reason.replaceAll(
      RegExp(RegExp.escape(code), caseSensitive: false),
      '••••',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    final preview = _attempt.preview;
    final result = _attempt.result;
    final template = preview?['template'];
    final records = _history?['records'];
    final page = _history?['current_page'] is int
        ? _history!['current_page'] as int
        : 1;
    final last = _history?['last_page'] is int
        ? _history!['last_page'] as int
        : 1;
    final form = ZolnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result == null)
            SecretTextFormField(
              controller: _input,
              enabled: _current && !_busy,
              showVisibilityToggle: false,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: text.zolnitGiftCode,
                hintText: text.zolnitGiftPrompt,
              ),
              onChanged: (value) => setState(() {
                _attempt.edit(value);
                _error = false;
              }),
            ),
          if (result == null) const SizedBox(height: 12),
          if (result == null)
            FilledButton(
              onPressed: _busy || !_current ? null : _check,
              child: Text(text.zolnitGiftCheck),
            ),
          if (result == null &&
              _attempt.canRetry &&
              preview?['can_redeem'] != true)
            TextButton(
              onPressed: _busy ? null : _redeem,
              child: Text(text.retry),
            ),
          if (preview != null && result == null) ...[
            const SizedBox(height: 12),
            if (template is Json && template['name'] is String)
              Text(
                template['name'] as String,
                style: zolnitText(context, 17, weight: FontWeight.w600),
              ),
            if (template is Json && template['description'] is String)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  template['description'] as String,
                  style: zolnitText(context, 12, color: colors.muted),
                ),
              ),
            if (preview['expires_at'] is int)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text.zolnitExpiresOn(zolnitDate(preview['expires_at'])),
                  style: zolnitText(context, 12, color: colors.muted),
                ),
              ),
            if (template is Json &&
                template['type'] == 3 &&
                preview['rewards'] is Json &&
                (preview['rewards'] as Json).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                text.zolnitGiftIncluded,
                style: zolnitText(context, 13, weight: FontWeight.w600),
              ),
            ] else
              const SizedBox(height: 8),
            _rewards(preview['rewards']),
            if (template is Json && template['type'] == 3) ...[
              const SizedBox(height: 12),
              Text(
                text.zolnitGiftPossible,
                style: zolnitText(context, 13, weight: FontWeight.w600),
              ),
              Text(
                text.zolnitGiftRandomTip,
                style: zolnitText(context, 12, color: colors.muted),
              ),
              _rewards(preview['possible_rewards']),
            ],
            if (preview['can_redeem'] != true && preview['reason'] is String)
              Text(_safeReason(preview['reason'] as String)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || preview['can_redeem'] != true
                  ? null
                  : _redeem,
              child: Text(text.zolnitGiftConfirm),
            ),
          ],
          if (result != null) ...[
            Row(
              children: [
                GlyphIcon(
                  AppGlyphs.checkCircle,
                  size: 22,
                  color: colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.zolnitGiftRedeemed,
                    style: zolnitText(context, 18, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (result['template_name'] is String)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  result['template_name'] as String,
                  style: zolnitText(context, 13, color: colors.muted),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              text.zolnitGiftActual,
              style: zolnitText(context, 13, weight: FontWeight.w600),
            ),
            _rewards(result['rewards']),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _attempt.edit('')),
              child: Text(text.zolnitGiftContinue),
            ),
          ],
          if (_error) Text(text.zolnitGiftFailure),
          if (_refreshFailed)
            TextButton(onPressed: _refresh, child: Text(text.retry)),
          if (_refreshFailed) Text(text.zolnitGiftRefreshFailed),
        ],
      ),
    );
    final history = ZolnitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.zolnitGiftHistory,
            style: zolnitText(context, 17, weight: FontWeight.w600),
          ),
          if (_historyBusy) const LinearProgressIndicator(),
          if (_historyFailed)
            TextButton(
              onPressed: () => _loadHistory(page),
              child: Text(text.retry),
            ),
          if (records is List && records.isEmpty) Text(text.zolnitGiftEmpty),
          if (records is List)
            for (final record in records)
              if (record is Json) ...[
                const SizedBox(height: 12),
                Text(
                  record['template_name'] is String
                      ? record['template_name'] as String
                      : text.zolnitGiftCard,
                  style: zolnitText(context, 13, weight: FontWeight.w600),
                ),
                _rewards(record['rewards']),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    zolnitOrderDateTime(record['created_at']),
                    style: zolnitText(context, 12, color: colors.muted),
                  ),
                ),
              ],
          Wrap(
            children: [
              TextButton(
                onPressed: _historyBusy || page <= 1
                    ? null
                    : () => _loadHistory(page - 1),
                child: Text(text.zolnitGiftPrevious),
              ),
              TextButton(
                onPressed: _historyBusy || page >= last
                    ? null
                    : () => _loadHistory(page + 1),
                child: Text(text.zolnitGiftNext),
              ),
            ],
          ),
        ],
      ),
    );
    final body = !_current
        ? Center(child: Text(text.zolnitSessionExpired))
        : LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: zolnitPagePadding(
                skin,
                compact: constraints.maxWidth < 740,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: constraints.maxWidth >= 740
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: form),
                              const SizedBox(width: 16),
                              Expanded(child: history),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              form,
                              const SizedBox(height: 16),
                              history,
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: colors.paper,
        leading: IconButton(
          tooltip: text.back,
          onPressed: () => Navigator.maybePop(context),
          icon: GlyphIcon(AppGlyphs.arrowBack, color: colors.ink),
        ),
        title: Text(text.zolnitGiftCard),
      ),
      body: body,
    );
  }
}
