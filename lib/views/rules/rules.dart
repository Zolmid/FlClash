import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fl_clash/common/added_rule_match.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/views/profiles/extend/extend.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'proxy_chain.dart';

List<CoreRule> _searchRules(({List<CoreRule> rules, String query}) input) {
  final query = SearchQuery(input.query);
  return input.rules.where((rule) => query.matches(rule.searchFields)).toList();
}

class RulesView extends ConsumerStatefulWidget {
  const RulesView({super.key});

  @override
  ConsumerState<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends ConsumerState<RulesView>
    with WidgetsBindingObserver, ActivePollingMixin<RulesView> {
  late final ScrollController _scrollController;
  late final CoreController _rulesCore;
  final _pendingRules = <int, CoreRule>{};
  final _mutationScheduler = SerialTaskScheduler();
  List<CoreRule>? _rules;
  String? _generation;
  List<CoreRule> _visibleRules = const [];
  bool _filtering = false;
  int _filterRevision = 0;
  Object? _operation;
  Object? _refreshOperation;
  String? _error;
  Object _providerSession = Object();
  String _query = '';

  CoreController get _core => ref.read(coreHandlerProvider);

  bool get _connected => ref.read(coreStatusProvider) == CoreStatus.connected;

  bool get _available =>
      _connected &&
      !_rulesCore.isApplyingConfiguration &&
      ref.read(tunnelStateProvider) != TunnelState.pending;

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  @override
  bool get canPoll => super.canPoll && _available;

  @override
  void initState() {
    super.initState();
    _scrollController = sheetScrollController(context);
    _rulesCore = _core;
    _rulesCore.configurationChanges.addListener(_invalidateRules);
    ref.listenManual(coreStatusProvider, (_, _) => _invalidateRules());
    ref.listenManual(currentProfileIdProvider, (_, _) => _invalidateRules());
    ref.listenManual(tunnelStateProvider, (_, _) => _invalidateRules());
  }

  void _invalidateRules() {
    _providerSession = Object();
    _cancelPendingRules();
    setState(() {
      _operation = null;
      _refreshOperation = null;
      _rules = null;
      _generation = null;
      _visibleRules = const [];
      _filtering = false;
      _filterRevision++;
      _error = null;
    });
    restartPolling();
  }

  @override
  void dispose() {
    _rulesCore.configurationChanges.removeListener(_invalidateRules);
    _cancelPendingRules();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) => _refresh(isCurrent: isCurrent);

  Future<void> _updateProvider(ExternalProvider provider) async {
    if (!_available || ref.read(isUpdatingProvider(provider.updatingKey))) {
      return;
    }
    final session = _providerSession;
    final l10n = context.appLocalizations;
    bool current() => mounted && identical(session, _providerSession);
    setState(() => _error = null);
    try {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          .updateProvider(provider, showLoading: true);
      if (!current()) return;
      if (message.isNotEmpty) throw MessageException(message);
      await _refresh();
    } catch (error) {
      if (current()) {
        setState(() => _error = userFacingErrorMessage(error, l10n));
      }
    }
  }

  Future<void> _refresh({PollGuard? isCurrent}) async {
    if (!_available || _operation != null || _pendingRules.isNotEmpty) {
      return;
    }

    final operation = Object();
    _refreshOperation = operation;
    final background = isCurrent != null && _rules != null;
    if (!background) {
      setState(() {
        _operation = operation;
      });
    }

    bool current() =>
        mounted &&
        identical(_refreshOperation, operation) &&
        (isCurrent?.call() ?? true);

    try {
      final snapshot = await _core.getRules();
      if (!current()) {
        return;
      }

      setState(() {
        _rules = snapshot.rules;
        _generation = snapshot.generation.isEmpty ? null : snapshot.generation;
        _refilter();
        _error = null;
      });
    } catch (error) {
      if (current()) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
      if (mounted && identical(_operation, operation)) {
        setState(() {
          _operation = null;
        });
      }
    }
  }

  void _refilter() {
    final revision = ++_filterRevision;
    final rules = _rules ?? const <CoreRule>[];
    final query = _query.trim();
    if (query.isEmpty) {
      _filtering = false;
      _visibleRules = rules;
      return;
    }
    final input = (rules: rules, query: query);
    const isolateThreshold = 1000;
    if (rules.length < isolateThreshold) {
      _filtering = false;
      _visibleRules = _searchRules(input);
      return;
    }
    _filtering = true;
    unawaited(
      compute(_searchRules, input).then(
        (rules) {
          if (!mounted || revision != _filterRevision) return;
          setState(() {
            _visibleRules = rules;
            _filtering = false;
          });
        },
        onError: (Object error) {
          if (!mounted || revision != _filterRevision) return;
          setState(() {
            _filtering = false;
            _error = userFacingErrorMessage(error, context.appLocalizations);
          });
        },
      ),
    );
  }

  void _cancelPendingRules() {
    for (final index in _pendingRules.keys) {
      debouncer.cancel((this, index));
    }
    _pendingRules.clear();
  }

  void _scheduleEnabled(CoreRule rule, bool enabled) {
    final generation = _generation;
    if (!_available || generation == null) return;
    final pending = rule.copyWith(disabled: !enabled);
    setState(() {
      _pendingRules[rule.index] = pending;
      _refreshOperation = null;
    });
    debouncer.call((this, rule.index), () {
      return _mutationScheduler.run(() async {
        if (!mounted || !identical(_pendingRules[rule.index], pending)) {
          return;
        }
        try {
          await _setEnabled(rule, enabled, generation);
        } finally {
          if (mounted && identical(_pendingRules[rule.index], pending)) {
            setState(() => _pendingRules.remove(rule.index));
          }
        }
      });
    });
  }

  Future<void> _setEnabled(
    CoreRule rule,
    bool enabled,
    String generation,
  ) async {
    if (!_available || _generation != generation) {
      return;
    }

    final operation = Object();
    final failure = context.appLocalizations.ruleUpdateFailed;

    setState(() {
      _operation = operation;
      _refreshOperation = null;
      _error = null;
    });

    bool current() => mounted && identical(_operation, operation);

    try {
      final applied = await _core.setRuleDisabled(
        rule.toDisabledParams(!enabled, generation: generation),
      );
      if (!current()) {
        return;
      }

      if (!applied) {
        setState(() {
          _error = failure;
        });
      }

      final snapshot = await _core.getRules();
      if (current()) {
        setState(() {
          if (_generation != snapshot.generation) _cancelPendingRules();
          _rules = snapshot.rules;
          _generation = snapshot.generation.isEmpty
              ? null
              : snapshot.generation;
          _refilter();
        });
      }
    } catch (error) {
      if (current()) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (current()) {
        setState(() {
          _operation = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final connected = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final profile = ref.watch(currentProfileProvider);
    final addedRules =
        profile != null &&
            profile.type != ProfileType.custom &&
            profile.extendType == ExtendType.standard
        ? ref.watch(addedRulesStreamProvider(profile.id)).value ??
              const <Rule>[]
        : const <Rule>[];
    final profileRules =
        profile != null &&
            profile.type != ProfileType.custom &&
            profile.extendType == ExtendType.standard
        ? ref.watch(profileAddedRulesProvider(profile.id)).value
        : null;
    final configuredMatchTarget = profile?.matchTarget?.trim();
    final matchTarget = configuredMatchTarget?.isNotEmpty == true
        ? configuredMatchTarget
        : _rules?.reversed
              .where(
                (rule) =>
                    rule.index >= addedRules.length && rule.type == 'Match',
              )
              .firstOrNull
              ?.proxy;
    final rules = _visibleRules;
    final busy = _operation != null;

    return CommonScaffold(
      title: l10n.rules,
      isLoading: busy && _rules == null,
      searchState: AppBarSearchState(
        onSearch: (value) {
          setState(() {
            _query = value;
            _refilter();
          });
        },
      ),
      body: Builder(
        builder: (context) => Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            Expanded(
              child: _buildRulesContent(
                context,
                bottomInset: BottomInsetScope.of(context),
                rules: rules,
                addedRules: addedRules,
                matchTarget: matchTarget,
                onOpenAddedRule: profileRules == null || profile == null
                    ? null
                    : (rule) => BaseNavigator.push(
                        context,
                        profileRules.any((item) => item.id == rule.id)
                            ? ExtendView(profileId: profile.id)
                            : const AddedRulesView(),
                      ),
                connected: connected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesContent(
    BuildContext context, {
    required double bottomInset,
    required List<CoreRule> rules,
    required List<Rule> addedRules,
    required String? matchTarget,
    required ValueChanged<Rule>? onOpenAddedRule,
    required bool connected,
  }) {
    final l10n = context.appLocalizations;

    if (!connected) {
      return NullStatus(
        label: l10n.disconnected,
        illustration: NullStatusIllustration.rules,
      );
    }

    if (_rules == null || _filtering) {
      return const NullStatus(illustration: NullStatusIllustration.rules);
    }

    return NullStatusSwitcher(
      isEmpty: rules.isEmpty,
      nullStatus: NullStatus(
        label: l10n.nullTip(l10n.rules),
        illustration: NullStatusIllustration.rules,
      ),
      child: FloatingScrollbar(
        controller: _scrollController,
        hintBuilder: (fraction) {
          if (rules.isEmpty) {
            return '';
          }

          final index = (fraction * (rules.length - 1)).round();
          return '#${rules[index].index + 1}';
        },
        child: SuperListView.separated(
          controller: _scrollController,
          physics: const NextClampingScrollPhysics(),
          padding: EdgeInsets.only(
            top: context.contentTopPadding,
            bottom: 16 + bottomInset,
          ),
          itemCount: rules.length,
          separatorBuilder: (_, _) => const Divider(height: 0),
          itemBuilder: (_, index) {
            final rule = rules[index];
            final isAdded = matchesAddedRule(
              rule,
              addedRules,
              matchTarget: matchTarget,
            );

            return _RuleItem(
              rule: _pendingRules[rule.index] ?? rule,
              isAdded: isAdded,
              onOpenAddedRule: !isAdded || onOpenAddedRule == null
                  ? null
                  : () => onOpenAddedRule(addedRules[rule.index]),
              onChanged: _generation == null || !_available
                  ? null
                  : (value) => _scheduleEnabled(rule, value),
              onUpdate: _updateProvider,
            );
          },
        ),
      ),
    );
  }
}

class _RuleItem extends ConsumerWidget {
  final CoreRule rule;
  final bool isAdded;
  final VoidCallback? onOpenAddedRule;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<ExternalProvider> onUpdate;

  const _RuleItem({
    required this.rule,
    required this.isAdded,
    required this.onOpenAddedRule,
    required this.onChanged,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final styles = RecordTextStyles.of(context);
    final payload = rule.payload.isEmpty ? rule.type : rule.payload;
    final provider = rule.type == 'RuleSet'
        ? ref
              .watch(providersProvider)
              .where(
                (provider) =>
                    provider.name == rule.payload &&
                    provider.type == 'Rule' &&
                    provider.vehicleType == 'HTTP',
              )
              .firstOrNull
        : null;
    final updating =
        provider != null && ref.watch(isUpdatingProvider(provider.updatingKey));

    void closeRules() {
      final route = ModalRoute.of(context);
      if (route != null && !route.isFirst) Navigator.of(context).pop();
    }

    return RecordListItem(
      tone: rule.disabled ? RecordTone.muted : RecordTone.neutral,
      onTap: () => showInSheet<void>(
        context,
        builder: (_) => CommonScaffold(
          title: l10n.details(l10n.rule),
          body: _RuleDetails(rule: rule),
        ),
      ),
      header: RecordHeader(
        trailing: Text(
          '${l10n.ruleHits} ${rule.hitCount} · ${l10n.ruleMisses} ${rule.missCount}',
          textAlign: TextAlign.end,
          style: styles.muted,
        ),
        children: [
          Text('#${rule.index + 1}'),
          if (isAdded)
            RecordLabel(
              label: l10n.addedRules,
              onPressed: onOpenAddedRule,
              tone: RecordTone.warning,
            ),
          if (rule.disabled)
            RecordLabel(label: l10n.ruleDisabled, tone: RecordTone.muted),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider != null)
            IconButton(
              tooltip: '${l10n.sync}: ${provider.name}',
              onPressed: updating ? null : () => onUpdate(provider),
              icon: updating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const GlyphIcon(AppGlyphs.sync),
            ),
          Semantics(
            label: '${l10n.ruleEnabled}: $payload',
            child: Switch(value: !rule.disabled, onChanged: onChanged),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            rule.payload.isEmpty
                ? TextSpan(text: rule.type)
                : TextSpan(
                    children: [
                      TextSpan(text: '${rule.type}('),
                      TextSpan(
                        text: rule.payload,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const TextSpan(text: ')'),
                    ],
                  ),
            style: styles.primary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          RuleProxyChain(target: rule.proxy, onNavigate: closeRules),
        ],
      ),
    );
  }
}

class _RuleDetails extends StatelessWidget {
  final CoreRule rule;

  const _RuleDetails({required this.rule});

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: context.contentTopPadding, bottom: 16),
      children: [
        generateSectionV3(
          title: l10n.basicInfo,
          items: [
            for (final (title, value) in [
              (l10n.rule, '#${rule.index + 1}'),
              (l10n.ruleType, rule.type),
              (l10n.content, rule.payload),
              (l10n.ruleTarget, rule.proxy),
              (
                l10n.status,
                rule.disabled ? l10n.ruleDisabled : l10n.ruleEnabled,
              ),
              if (rule.size >= 0)
                (l10n.rules, l10n.rulesCount(rule.size, '${rule.size}')),
              (l10n.ruleHits, '${rule.hitCount}'),
              (l10n.ruleMisses, '${rule.missCount}'),
              if (rule.hitAt != null)
                (l10n.ruleLastHit, rule.hitAt!.toLocal().showFull),
              if (rule.missAt != null)
                (l10n.ruleLastMiss, rule.missAt!.toLocal().showFull),
            ])
              DetailRow.text(title: title, value: value),
          ],
        ),
      ],
    );
  }
}
