import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/providers/zolnit_bundle.dart';
import 'package:fl_clash/providers/zolnit_registration.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'account.dart';
import 'auth.dart';
import 'catalogue.dart';
import 'connect.dart';
import 'notices.dart';
import 'notes.dart';
import 'preferences.dart';
import 'rewards.dart';
import 'plans.dart';
import 'shell.dart';
import 'skin.dart';
import 'help.dart';
import 'kit.dart';
import 'motion.dart';
import 'update.dart';

class ZolnitHomePage extends ConsumerStatefulWidget {
  const ZolnitHomePage({super.key, this.skin});

  final ZolnitSkin? skin;

  @override
  ConsumerState<ZolnitHomePage> createState() => _ZolnitHomePageState();
}

class _ZolnitHomePageState extends ConsumerState<ZolnitHomePage>
    with WidgetsBindingObserver {
  int _selected = 0;
  int _pagePosition = 0;
  int _pageTransition = 0;
  ZolnitPageDirection _pageDirection = ZolnitPageDirection.forward;
  ZolnitAccountTab _accountTab = ZolnitAccountTab.info;
  bool _showingPreferences = false;
  bool _showingRewards = false;
  int _preferencesOrigin = 3;
  String? _cashierTradeNo;
  bool _syncing = false;
  bool _syncFailed = false;
  int? _syncGeneration;
  Future<int?>? _syncFlight;
  Future<void>? _refreshFlight;
  Future<void>? _reconcileFlight;
  Future<void>? _paymentFlight;
  DateTime? _nextOrderCheck;
  Timer? _refreshTimer;
  DateTime? _nextRefresh;
  int _refreshFailures = 0;
  int? _observedGeneration;
  bool _foreground = true;
  late final ZolnitSessionController _session;
  late final ZolnitRegistrationCoordinator _registration;
  final ZolnitRealtimePreferencesStore _realtimeStore =
      ZolnitRealtimePreferencesStore();
  ZolnitRealtimeChannel? _realtime;
  String? _realtimeSubject;
  Future<void>? _inboxFlight;
  int? _inboxGeneration;
  int? _inboxFlightEpoch;
  int _inboxEpoch = 0;
  RawDialogRoute<void>? _popupRoute;
  String? _popupItemId;
  final _popupContent = ValueNotifier<ZolnitRealtimeInboxItem?>(null);
  final _canonicalNotices = ValueNotifier<Map<String, ZolnitRealtimeInboxItem>>(
    {},
  );
  final _noticeRevision = ValueNotifier<int>(0);
  final _withdrawn = <String>{};
  final _popups = Queue<ZolnitRealtimeInboxItem>();
  Future<int?>? _buildNumber;
  int _unread = 0;
  CommonAction? _cachedActions;
  bool _updateHintsHealthy = false;
  final _brandKey = GlobalKey();

  BuildContext get _brandContext => _brandKey.currentContext ?? context;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ref.read(zolnitSessionProvider)..addListener(_sessionChanged);
    _registration = ref.read(zolnitRegistrationProvider);
    ref.listenManual(initProvider, (_, ready) {
      if (ready) unawaited(_refreshData(force: true));
    });
    _armRefresh();
    scheduleMicrotask(_sessionChanged);
  }

  DateTime get _now => ref.read(zolnitBundleClockProvider)();

  CommonAction get _updateActions {
    if (_cachedActions case final cached?) return cached;
    final CommonAction actions = ref.read(commonActionProvider.notifier);
    _cachedActions = actions;
    return actions;
  }

  /// Tells the updater whether server update hints can arrive, only when that
  /// changes: an unhealthy report makes it check on its own at once.
  void _reportUpdateHints(bool healthy) {
    if (_updateHintsHealthy == healthy) return;
    _updateHintsHealthy = healthy;
    _updateActions.setAppUpdateRealtimeHintsHealthy(healthy);
  }

  void _armRefresh() {
    _refreshTimer?.cancel();
    if (_foreground) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_refreshData());
      });
    }
  }

  void _sessionChanged() {
    if (!_session.authenticated) {
      if (_observedGeneration != null) _inboxEpoch++;
      _reportUpdateHints(false);
      if (_observedGeneration != null) _nextRefresh = null;
      _observedGeneration = null;
      _clearPopups();
      _realtimeSubject = null;
      _withdrawn.clear();
      _canonicalNotices.value = {};
      _unread = 0;
      unawaited(_realtime?.dispose() ?? Future<void>.value());
      _realtime = null;
      return;
    }
    if (_observedGeneration != _session.api.generation) {
      _inboxEpoch++;
      _reportUpdateHints(false);
      _clearPopups();
      _realtimeSubject = null;
      _withdrawn.clear();
      _canonicalNotices.value = {};
      _unread = 0;
      final old = _realtime;
      _realtime = null;
      unawaited(old?.dispose() ?? Future.value());
      _observedGeneration = _session.api.generation;
      _nextRefresh = null;
      _nextOrderCheck = null;
      _refreshFailures = 0;
      scheduleMicrotask(() => unawaited(_refreshData(force: true)));
    }
  }

  Future<void> _refreshData({bool force = false}) {
    if (!mounted || !_foreground) return Future.value();
    if (!_session.authenticated) {
      if (_session.restoreState == ZolnitRestoreState.offline &&
          (force || _nextRefresh?.isAfter(_now) != true)) {
        _refreshFailures = (_refreshFailures + 1).clamp(0, 4);
        _nextRefresh = _now.add(
          Duration(seconds: 15 * (1 << _refreshFailures)),
        );
        return _session.restore();
      }
      return Future.value();
    }
    if (!ref.read(initProvider)) return Future.value();
    if (_refreshFlight case final pending?) return pending;
    if (!force && _realtime?.healthy == true) {
      final pending = _pendingOrders();
      final live = _session.api.liveReads?.supports('order.status') == true;
      if (pending.isEmpty ||
          (!live && _nextOrderCheck?.isAfter(_now) == true)) {
        return Future.value();
      }
      if (!live) _nextOrderCheck = _now.add(const Duration(seconds: 60));
      return _reconcileOrders(pending);
    }
    if (!force && _nextRefresh?.isAfter(_now) == true) {
      return Future.value();
    }
    final generation = _session.api.generation;
    late final Future<void> work;
    work = () async {
      try {
        if (_realtime?.healthy != true) {
          unawaited(
            _refreshRealtimeInbox(generation).catchError((Object _) {}),
          );
        }
        await _session.refresh();
        if (!mounted ||
            !_foreground ||
            !_session.authenticated ||
            _session.api.generation != generation) {
          return;
        }

        await Future.wait([_session.refreshBilling(), _sync()]);
        if (!mounted || _session.api.generation != generation) return;
        if (_syncFailed ||
            _session.failure != null ||
            _session.billingFailure != null) {
          _refreshFailures = (_refreshFailures + 1).clamp(0, 4);
        } else {
          _refreshFailures = 0;
        }
        _nextRefresh = _now.add(
          Duration(
            seconds: _refreshFailures == 0 ? 120 : 15 * (1 << _refreshFailures),
          ),
        );
      } finally {
        if (identical(_refreshFlight, work)) _refreshFlight = null;
        if (mounted &&
            _session.authenticated &&
            _session.api.generation != generation) {
          scheduleMicrotask(() => unawaited(_refreshData(force: true)));
        }
      }
    }();
    _refreshFlight = work;
    return work;
  }

  List<String> _pendingOrders() => [
    for (final order in _session.orders)
      if (order['status'] == 0 &&
          order['trade_no'] is String &&
          order['trade_no'] != _cashierTradeNo)
        order['trade_no'] as String,
  ].take(3).toList();

  // The HTTP sweep is off while healthy; keep pending orders reconciling.
  Future<void> _reconcileOrders(List<String> tradeNos) {
    if (_reconcileFlight case final pending?) return pending;
    final generation = _session.api.generation;
    late final Future<void> work;
    work = () async {
      try {
        for (final tradeNo in tradeNos) {
          final status = await _session.api.orderStatus(tradeNo);
          if (!_currentRealtime(generation)) return;
          if (status != 0) {
            await _refreshData(force: true);
            return;
          }
        }
      } catch (_) {
        // The order check retries on the next tick.
      } finally {
        if (identical(_reconcileFlight, work)) _reconcileFlight = null;
      }
    }();
    _reconcileFlight = work;
    return work;
  }

  void _reconcileCheckout(int gen) {
    final checkout = _session.checkout;
    if (_paymentFlight != null ||
        !_currentRealtime(gen) ||
        checkout.tradeNo == null ||
        !{
          CheckoutStage.awaitingPayment,
          CheckoutStage.qr,
          CheckoutStage.processing,
        }.contains(checkout.stage)) {
      return;
    }
    late final Future<void> work;
    work = _session.refreshPayment().catchError((Object _) {}).whenComplete(() {
      if (identical(_paymentFlight, work)) _paymentFlight = null;
    });
    _paymentFlight = work;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _reportUpdateHints(false);
    _armRefresh();
    _realtime?.setForeground(_foreground);
    if (_foreground) unawaited(_refreshData(force: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _reportUpdateHints(false);
    unawaited(_realtime?.dispose() ?? Future<void>.value());
    _clearPopups();
    _noticeRevision.dispose();
    _popupContent.dispose();
    _canonicalNotices.dispose();
    _registration.cancel();
    _session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String? _realtimeScope() {
    final subject = _realtimeSubject;
    return subject == null ? null : '${_session.api.origin.origin}:$subject';
  }

  bool _currentRealtime(int gen) =>
      mounted && _session.authenticated && _session.api.generation == gen;

  void _connectRealtime(String scope, int gen) {
    if (_realtime != null || !_currentRealtime(gen) || !_foreground) return;
    late final ZolnitRealtimeChannel channel;
    channel = ZolnitRealtimeChannel(
      api: _session.api,
      scopeKey: () => scope,
      store: _realtimeStore,
      connect: ref.read(zolnitRealtimeConnectorProvider),
      onHealthChanged: () {
        if (!_currentRealtime(gen) || !identical(channel, _realtime)) return;
        _reportUpdateHints(channel.healthy && _foreground);
        if (!_foreground) return;
        if (!channel.healthy) {
          scheduleMicrotask(() {
            if (_currentRealtime(gen) && !channel.healthy) {
              unawaited(_refreshData(force: true));
            }
          });
        } else {
          scheduleMicrotask(() => _reconcileCheckout(gen));
        }
      },
      onResync: () async {
        if (!_currentRealtime(gen)) return;
        _inboxEpoch++;
        await Future.wait([
          _refreshData(force: true),
          _refreshRealtimeInbox(gen),
        ]);
        if (_session.failure != null ||
            _session.billingFailure != null ||
            _syncFailed) {
          throw StateError('snapshot unavailable');
        }
      },
      onEvent: (e) =>
          _applyEvent(e.id, e.type, e.data, scope, gen, DateTime.now(), false),
    );
    _realtime = channel;
    unawaited(channel.start());
  }

  Future<void> _applyEvent(
    String id,
    String type,
    Json data,
    String scope,
    int gen,
    DateTime at,
    bool read, {
    bool canonical = false,
    bool Function()? isCurrentSnapshot,
  }) async {
    if (!_currentRealtime(gen) || scope != _realtimeScope()) return;
    switch (type) {
      case 'config.changed':
        await _sync();
        if (_syncFailed) throw StateError('config refresh failed');
        return;
      case 'notice.changed':
        await _session.refreshRealtimeNotices();
        return;
      case 'account.changed':
        _reconcileCheckout(gen);
        await _session.refresh();
        if (_currentRealtime(gen)) {
          await Future.wait([_session.refreshBilling(), _sync()]);
        }
        if (_session.failure != null || _session.billingFailure != null) {
          throw StateError('account refresh failed');
        }
        return;
      case 'account.usage':
        _session.applyRealtimeUsage(data);
        return;
    }
    final String title, body;
    String? updateVersion;
    if (type == 'client.update') {
      final target = data['platform'],
          build = data['build'],
          version = data['version'];
      if ((target != 'all' && target != _session.api.clientPlatform) ||
          build is! int ||
          build <= 0 ||
          version is! String ||
          !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
          version.length > 32) {
        return;
      }
      _buildNumber ??= PackageInfo.fromPlatform()
          .then((i) => int.tryParse(i.buildNumber))
          .catchError((Object _) => null);
      final current = await _buildNumber;
      if (current == null) {
        _buildNumber = null;
        return;
      }
      if (!_currentRealtime(gen) || build <= current) return;
      if (!mounted) return;
      updateVersion = version;
      title = '${context.appLocalizations.discoverNewVersion} · $version';
      body = data['body'] is String
          ? data['body'] as String
          : 'ZolNit $version ($build)';
    } else if ({
      'notice.published',
      'notice.popup',
      'account.notice',
    }.contains(type)) {
      if (data['title'] is! String || data['body'] is! String) return;
      title = data['title'] as String;
      body = data['body'] as String;
    } else {
      return;
    }
    if (title.trim().isEmpty ||
        body.trim().isEmpty ||
        utf8.encode(title).length > 200 ||
        utf8.encode(body).length > 2048) {
      return;
    }
    final item = ZolnitRealtimeInboxItem(
      id: id,
      title: title,
      body: body,
      createdAt: at,
      popup: type == 'notice.popup',
      read: read,
    );
    final merge = canonical
        ? await _realtimeStore.applyCanonicalInbox(
            scope,
            item,
            isCurrent: () =>
                _currentRealtime(gen) &&
                scope == _realtimeScope() &&
                (isCurrentSnapshot?.call() ?? false),
          )
        : (await _realtimeStore.appendInbox(scope, item)
              ? ZolnitInboxMerge.inserted
              : ZolnitInboxMerge.unchanged);
    final fresh = merge == ZolnitInboxMerge.inserted;
    if (merge == ZolnitInboxMerge.updated && _currentRealtime(gen)) {
      _canonicalNotices.value = {..._canonicalNotices.value, item.id: item};
      if (_popupItemId == item.id) _popupContent.value = item;
      final queued = _popups.toList();
      _popups.clear();
      for (final pending in queued) {
        if (pending.id != item.id) {
          _popups.add(pending);
        } else if (item.popup) {
          _popups.add(item);
        }
      }
      await _updateUnread(scope, gen);
    }
    if (fresh && updateVersion != null && _currentRealtime(gen)) {
      unawaited(
        _updateActions
            .notifyAppUpdateHint(version: updateVersion)
            .catchError((Object _) => false),
      );
    }
    if (fresh && _currentRealtime(gen)) await _updateUnread(scope, gen);
    if (fresh && !read && _currentRealtime(gen) && _foreground && item.popup) {
      if (_popups.length < 8) _popups.add(item);
      _showNextPopup(scope, gen);
    }
  }

  void _clearPopups() {
    _popupItemId = null;
    _popupContent.value = null;
    _popups.clear();
    final route = _popupRoute;
    _popupRoute = null;
    if (route != null && route.isActive) {
      scheduleMicrotask(() {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  void _showNextPopup(String scope, int gen) {
    if (!_currentRealtime(gen) ||
        !_foreground ||
        scope != _realtimeScope() ||
        _popupRoute != null ||
        _popups.isEmpty) {
      return;
    }
    final item = _popups.removeFirst();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_currentRealtime(gen) || !_foreground || scope != _realtimeScope()) {
        return;
      }
      if (_withdrawn.contains(item.id)) {
        _showNextPopup(scope, gen);
        return;
      }
      if (_popupRoute != null) {
        _popups.addFirst(item);
        return;
      }
      final latest = _canonicalNotices.value[item.id] ?? item;
      if (!latest.popup) {
        _showNextPopup(scope, gen);
        return;
      }
      final route = zolnitDialogRoute<void>(
        _brandContext,
        (dialog) => ValueListenableBuilder<ZolnitRealtimeInboxItem?>(
          valueListenable: _popupContent,
          builder: (dialog, current, _) => AlertDialog(
            title: Text(current?.title ?? item.title),
            content: SingleChildScrollView(
              child: ReleaseNotesContent(body: current?.body ?? item.body),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  if (ModalRoute.of(dialog)?.isCurrent != true) return;
                  zolnitCloseDialog<void>(dialog);
                  unawaited(_markRead(item, scope, gen));
                },
                child: Text(dialog.appLocalizations.zolnitGotIt),
              ),
            ],
          ),
        ),
      );
      _popupRoute = route;
      _popupItemId = item.id;
      _popupContent.value = latest;
      unawaited(
        Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
          if (identical(_popupRoute, route)) {
            _popupRoute = null;
            _popupItemId = null;
            _popupContent.value = null;
            _showNextPopup(scope, gen);
          }
        }),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _updateUnread(String scope, int gen) async {
    final inbox = await _realtimeStore.readInbox(scope);
    final count = inbox.where((item) => !item.read).length;
    if (_currentRealtime(gen) &&
        scope == _realtimeScope() &&
        _unread != count) {
      setState(() => _unread = count);
    }
  }

  Future<bool> _markRead(
    ZolnitRealtimeInboxItem item,
    String scope,
    int gen,
  ) async {
    if (item.read || !_currentRealtime(gen) || scope != _realtimeScope()) {
      return false;
    }
    try {
      final live = await _realtime?.markInboxRead(item.id) ?? false;
      if (!_currentRealtime(gen)) return false;
      if (!live) await _session.api.markRealtimeInboxRead(item.id);
      if (_currentRealtime(gen)) {
        await _realtimeStore.appendInbox(scope, item.asRead());
      }
      if (_currentRealtime(gen)) await _updateUnread(scope, gen);
      return _currentRealtime(gen);
    } catch (_) {
      return false;
    }
  }

  Future<void> _withdrawMessages(
    String scope,
    int gen,
    List<String> ids,
  ) async {
    if (ids.isEmpty || !_currentRealtime(gen)) return;
    await _realtimeStore.withdrawInbox(scope, ids);
    if (!_currentRealtime(gen)) return;
    _withdrawn.addAll(ids);
    _popups.removeWhere((e) => _withdrawn.contains(e.id));
    if (_withdrawn.contains(_popupItemId)) {
      final route = _popupRoute;
      _popupRoute = null;
      _popupItemId = null;
      _popupContent.value = null;
      if (route?.isActive == true) route?.navigator?.removeRoute(route);
    }
    _noticeRevision.value++;
    await _updateUnread(scope, gen);
  }

  Future<void> _refreshRealtimeInbox(int gen) {
    if (_inboxGeneration == gen && _inboxFlight != null) {
      final activeEpoch = _inboxFlightEpoch;
      return _inboxFlight!.then((_) {
        if (_currentRealtime(gen) && activeEpoch != _inboxEpoch) {
          return _refreshRealtimeInbox(gen);
        }
      });
    }
    _inboxGeneration = gen;
    final epoch = _inboxEpoch;
    _inboxFlightEpoch = epoch;
    bool currentSnapshot() => _currentRealtime(gen) && epoch == _inboxEpoch;
    late final Future<void> job;
    job =
        Future<void>.microtask(() async {
          final inbox = await _session.api.realtimeInbox();
          if (!currentSnapshot()) return;
          final scope = '${_session.api.origin.origin}:${inbox.subject}';
          if (_realtimeSubject != null && _realtimeSubject != inbox.subject) {
            throw StateError('account binding changed');
          }
          _realtimeSubject = inbox.subject;
          await _withdrawMessages(scope, gen, inbox.withdrawn);
          for (final e in inbox.events.take(100)) {
            if (!currentSnapshot()) return;
            final id = e['id'],
                type = e['type'],
                data = e['data'],
                seconds = e['created_at'];
            if (id is! String ||
                !RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
                type is! String ||
                !{
                  'notice.published',
                  'notice.popup',
                  'client.update',
                  'account.notice',
                }.contains(type) ||
                data is! Json ||
                seconds is! int ||
                seconds < 0 ||
                seconds > 253402300799) {
              continue;
            }
            await _applyEvent(
              id,
              type,
              data,
              scope,
              gen,
              DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
              e['read'] == true,
              canonical: true,
              isCurrentSnapshot: currentSnapshot,
            );
          }
          await _updateUnread(scope, gen);
          _connectRealtime(scope, gen);
        }).whenComplete(() {
          if (identical(_inboxFlight, job)) _inboxFlight = null;
        });
    return _inboxFlight = job;
  }

  Future<void> _openNotices() async {
    final scope = _realtimeScope(), gen = _session.api.generation;
    List<ZolnitRealtimeInboxItem> inbox = [];
    try {
      if (scope != null) inbox = await _realtimeStore.readInbox(scope);
    } catch (_) {}
    if (!_currentRealtime(gen)) return;
    if (!mounted) return;
    final noticeRevision = _noticeRevision.value;
    await showZolnitNotices(
      _brandContext,
      _session.noticeList,
      inbox,
      session: _session,
      isCurrent: () =>
          _currentRealtime(gen) && _noticeRevision.value == noticeRevision,
      invalidation: _noticeRevision,
      canonicalNotices: _canonicalNotices,
      onOpen: (item) async =>
          scope != null && await _markRead(item, scope, gen),
    );
  }

  Future<void> _website([String path = '/']) async {
    final mode = await supportsLaunchMode(LaunchMode.inAppBrowserView)
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;
    await launchUrl(
      Uri.parse('https://link.zolmid.com').replace(fragment: path),
      mode: mode,
    );
  }

  Future<void> _register() async {
    await _registration.start();
  }

  void _openHelp(BuildContext from) {
    unawaited(
      openZolnitPage<void>(
        from,
        ZolnitHelpPage(session: ref.read(zolnitSessionProvider)),
      ),
    );
  }

  Future<int?> _sync() {
    final generation = ref.read(zolnitSessionProvider).api.generation;
    if (_syncGeneration == generation && _syncFlight != null) {
      return _syncFlight!;
    }
    final operation = _performSync(generation);
    _syncFlight = operation;
    return operation;
  }

  Future<int?> _performSync(int generation) async {
    bool current() =>
        mounted &&
        _syncGeneration == generation &&
        ref.read(zolnitSessionProvider).api.generation == generation;
    setState(() {
      _syncGeneration = generation;
      _syncing = true;
      _syncFailed = false;
    });
    try {
      final id = await ref.read(zolnitSyncProfileProvider)();
      return id;
    } catch (_) {
      if (current()) setState(() => _syncFailed = true);
      return null;
    } finally {
      if (current()) {
        _syncFlight = null;
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _signedIn() async {
    final session = ref.read(zolnitSessionProvider);
    await Future.wait([session.refreshBilling(), _sync()]);
  }

  Future<void> _refreshAfterRedemption() async {
    final session = _session;
    final generation = session.api.generation;
    final pendingSync = _syncGeneration == generation ? _syncFlight : null;
    await session.refresh();
    if (!mounted ||
        !session.authenticated ||
        session.api.generation != generation) {
      throw const ClientFailure('superseded');
    }
    await session.refresh();
    if (!mounted ||
        !session.authenticated ||
        session.api.generation != generation) {
      throw const ClientFailure('superseded');
    }
    if (pendingSync != null) await pendingSync;
    if (!mounted ||
        !session.authenticated ||
        session.api.generation != generation) {
      throw const ClientFailure('superseded');
    }
    await Future.wait([session.refreshBilling(), _sync()]);
    if (!mounted ||
        session.api.generation != generation ||
        session.failure != null ||
        session.billingFailure != null ||
        _syncFailed) {
      throw const ClientFailure('refresh_failed');
    }
  }

  Future<void> _connect() async {
    final session = ref.read(zolnitSessionProvider);
    final generation = session.api.generation;
    var applied = false;
    try {
      applied = await _setConnection(!ref.read(isStartProvider));
    } catch (_) {
      applied = false;
    }
    if (mounted &&
        session.authenticated &&
        session.api.generation == generation &&
        !applied) {
      setState(() => _syncFailed = true);
    }
  }

  Future<bool> _setConnection(bool running) async {
    if (ref.read(safeModeProvider)) return false;
    if (!running) {
      return ref.read(setupActionProvider.notifier).setRunning(false);
    }
    if (ref.read(isStartProvider)) return true;
    final generation = ref.read(zolnitSessionProvider).api.generation;
    var id = await _sync();
    if (mounted &&
        id == null &&
        ref.read(zolnitSessionProvider).api.generation == generation) {
      id = cachedManualZolnitBundleProfile(
        ref.read(profilesProvider),
        ref.read(zolnitSessionProvider),
        enabled: ref.read(zolnitClientBundleTransportProvider),
      )?.id;
    }
    if (!mounted ||
        id == null ||
        ref.read(zolnitSessionProvider).api.generation != generation ||
        !ref.read(zolnitSessionProvider).authenticated) {
      return false;
    }
    ref.read(currentProfileIdProvider.notifier).value = id;
    return ref.read(setupActionProvider.notifier).setRunning(true);
  }

  void _select(int index) {
    setState(() {
      _movePage(index);
      _selected = index;
      _accountTab = ZolnitAccountTab.info;
      _showingPreferences = false;
      _showingRewards = false;
      _cashierTradeNo = null;
    });
    unawaited(_refreshData());
    if (index == 3) unawaited(ref.read(zolnitSessionProvider).refreshBilling());
    if (index == 2) {
      final session = ref.read(zolnitSessionProvider);
      if (session.checkout.allowStripe &&
          session.api.distribution != 'apple-app-store') {
        unawaited(session.refreshRecurringOptions());
      }
    }
  }

  void _showOrders() {
    setState(() {
      _movePage(3);
      _selected = 3;
      _accountTab = ZolnitAccountTab.orders;
      _showingPreferences = false;
      _showingRewards = false;
      _cashierTradeNo = null;
    });
  }

  void _showInvitations() {
    if (!_session.authenticated) return;
    HapticFeedback.selectionClick();
    setState(() {
      _movePage(3);
      _selected = 3;
      _accountTab = ZolnitAccountTab.invite;
      _showingPreferences = false;
      _showingRewards = false;
      _cashierTradeNo = null;
    });
  }

  void _showCashier(String tradeNo) {
    setState(() {
      _movePage(4);
      _selected = 3;
      _accountTab = ZolnitAccountTab.orders;
      _showingPreferences = false;
      _showingRewards = false;
      _cashierTradeNo = tradeNo;
    });
  }

  void _showPreferences() {
    setState(() {
      if (!_showingPreferences) _preferencesOrigin = _selected;
      _movePage(4);
      _selected = 3;
      _showingPreferences = true;
      _showingRewards = false;
      _cashierTradeNo = null;
    });
  }

  void _showRewards() {
    setState(() {
      _movePage(4);
      _selected = 3;
      _showingPreferences = false;
      _showingRewards = true;
      _cashierTradeNo = null;
    });
  }

  void _returnFromRewards() {
    setState(() {
      _showingRewards = false;
      _selected = 3;
      _accountTab = ZolnitAccountTab.info;
      _movePage(3);
    });
  }

  void _returnToAccount() {
    setState(() {
      _showingPreferences = false;
      _showingRewards = false;
      _selected = _preferencesOrigin;
      _movePage(_preferencesOrigin);
    });
  }

  void _movePage(int position) {
    if (position == _pagePosition) return;
    _pageDirection = zolnitPageDirection(_pagePosition, position);
    _pagePosition = position;
    _pageTransition++;
  }

  Future<void> _logout() async {
    final deletion = ref.read(zolnitSessionProvider).logout();
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoRun: false));
    setState(() {
      _movePage(0);
      _selected = 0;
      _accountTab = ZolnitAccountTab.info;
      _showingPreferences = false;
      _showingRewards = false;
      _cashierTradeNo = null;
      _syncFailed = false;
      _syncing = false;
      _syncGeneration = null;
    });
    try {
      if (!ref.read(safeModeProvider)) {
        await ref.read(setupActionProvider.notifier).setRunning(false);
      }
    } finally {
      await deletion;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(zolnitSessionProvider);
    final base = Theme.of(context);
    final brand = base.brightness == Brightness.dark
        ? ZolnitColors.dark
        : ZolnitColors.light;
    final theme = brand.theme(
      base.copyWith(
        colorScheme: seededColorScheme(
          seedColor: ZolnitColors.light.accent,
          brightness: base.brightness,
          style: ColorStyle.soft,
        ),
      ),
    );
    return ZolnitSkinScope(
      skin: widget.skin ?? ZolnitSkin.host,
      child: Theme(
        data: theme,
        child: Builder(
          builder: (context) => Material(
            key: _brandKey,
            color: brand.paper,
            child: ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                if (!session.authenticated) {
                  return ZolnitLoginPage(
                    session: session,
                    banner: const ZolnitUpdateBanner(
                      padding: EdgeInsets.only(bottom: 12),
                    ),
                    onSignedIn: _signedIn,
                    openWebsite: () => unawaited(_website()),
                    openRegistration: () => unawaited(_register()),
                    openRecovery: () => unawaited(_website('/forgetpassword')),
                  );
                }
                final text = context.appLocalizations;
                final labels = [
                  text.connection,
                  text.zolnitAllNodes,
                  text.zolnitPlans,
                  text.account,
                ];
                final glyphs = [
                  AppGlyphs.home,
                  AppGlyphs.proxies,
                  AppGlyphs.layers,
                  AppGlyphs.account,
                ];
                final title = _showingRewards
                    ? text.zolnitGiftCard
                    : _showingPreferences
                    ? text.zolnitPreferences
                    : _cashierTradeNo != null
                    ? text.zolnitCashierTitle
                    : labels[_selected];
                final name = zolnitDisplayName(session.account, session.usage);
                final page = _showingRewards
                    ? ZolnitRewardsPage(
                        key: const ValueKey('zolnit-rewards'),
                        session: session,
                        onRedeemed: _refreshAfterRedemption,
                        embedded: true,
                      )
                    : _showingPreferences
                    ? ZolnitPreferencesPage(
                        key: const ValueKey('zolnit-preferences'),
                        compact: false,
                        openWebsite: () => unawaited(_website()),
                      )
                    : _cashierTradeNo != null
                    ? ZolnitCashierPage(
                        session: session,
                        tradeNo: _cashierTradeNo!,
                        onClose: _showOrders,
                      )
                    : switch (_selected) {
                        0 => Column(
                          children: [
                            Expanded(
                              child: ZolnitConnectPage(
                                key: const ValueKey('zolnit-connect'),
                                session: session,
                                compact: false,
                                syncing: _syncing,
                                syncFailed: _syncFailed,
                                connect: _connect,
                                openNodes: () => _select(1),
                                openPlans: () => _select(2),
                              ),
                            ),
                            _HomeInvitationCard(onTap: _showInvitations),
                          ],
                        ),
                        1 => ZolnitNodesPage(
                          key: const ValueKey('zolnit-nodes'),
                          session: session,
                          sync: _sync,
                          compact: false,
                        ),
                        2 => ZolnitPlansPage(
                          key: const ValueKey('zolnit-plans'),
                          session: session,
                          onOrderCreated: _showCashier,
                          onOrders: _showOrders,
                          onManageRenewals: () => _select(3),
                          compact: false,
                        ),
                        _ => ZolnitAccountPage(
                          key: const ValueKey('zolnit-account'),
                          session: session,
                          tab: _accountTab,
                          onTabChanged: (tab) => setState(() {
                            _accountTab = tab;
                            _showingPreferences = false;
                          }),
                          showPlans: () => _select(2),
                          showPreferences: _showPreferences,
                          openHelp: () => _openHelp(context),
                          compact: false,
                          logout: _logout,
                          onCheckout: _showCashier,
                          showRewards: _showRewards,
                        ),
                      };
                return PopScope(
                  canPop:
                      !_showingRewards &&
                      !_showingPreferences &&
                      _cashierTradeNo == null,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _showingRewards) {
                      _returnFromRewards();
                    } else if (!didPop && _showingPreferences) {
                      _returnToAccount();
                    } else if (!didPop && _cashierTradeNo != null) {
                      _showOrders();
                    }
                  },
                  child: DisplayFeatureSubScreen(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final layout = ZolnitLayout.fromWidth(width);
                        final gutter = zolnitPagePadding(
                          ZolnitSkin.of(context),
                          compact: !layout.useSidebar,
                        );
                        final body = ZolnitLayoutScope(
                          layout: layout,
                          width: width,
                          child: Column(
                            children: [
                              ZolnitTopBar(
                                compact: !layout.useSidebar,
                                title: title,
                                showBrand:
                                    _selected == 0 && !_showingPreferences,
                                initial: name.characters.first,
                                unread: _unread,
                                onNotices: () => unawaited(_openNotices()),
                                onHelp: () => _openHelp(context),
                                onAccount: () => _select(3),
                                onBack: _showingRewards
                                    ? _returnFromRewards
                                    : _showingPreferences
                                    ? _returnToAccount
                                    : _cashierTradeNo != null
                                    ? _showOrders
                                    : null,
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1200,
                                    ),
                                    child: Column(
                                      children: [
                                        if (!_showingPreferences)
                                          ZolnitUpdateBanner(
                                            padding: EdgeInsets.fromLTRB(
                                              gutter.left,
                                              14,
                                              gutter.right,
                                              0,
                                            ),
                                          ),
                                        Expanded(
                                          child: ZolnitPageSwitcher(
                                            switchKey: _pageTransition,
                                            direction: _pageDirection,
                                            child: page,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (layout.useBottomNav)
                                SafeArea(
                                  top: false,
                                  child: NavigationDock(
                                    selectedIndex: _selected,
                                    onSelected: _select,
                                    destinations: [
                                      for (var i = 0; i < labels.length; i++)
                                        NavigationDockDestination(
                                          glyph: glyphs[i],
                                          label: labels[i],
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                        return Row(
                          children: [
                            if (layout.useRail)
                              ZolnitNavRail(
                                labels: labels,
                                glyphs: glyphs,
                                selected: _selected,
                                onSelected: _select,
                              )
                            else if (layout.useSidebar)
                              ZolnitSidebar(
                                labels: labels,
                                glyphs: glyphs,
                                selected: _selected,
                                onSelected: _select,
                                onHelp: () => _openHelp(context),
                                onPreferences: _showPreferences,
                              ),
                            Expanded(
                              key: const ValueKey('zolnit-content'),
                              child: body,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeInvitationCard extends StatelessWidget {
  const _HomeInvitationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final text = context.appLocalizations;
    final padding = zolnitPagePadding(
      skin,
      compact: !ZolnitLayoutScope.of(context).useSidebar,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 12),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FractionallySizedBox(
            widthFactor: constraints.maxWidth >= 740 ? 0.4 : 1,
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                button: true,
                child: InkWell(
                  key: const ValueKey('home-invitation-card'),
                  customBorder: AppShape.all(skin.tileCorner),
                  onTap: onTap,
                  child: ZolnitCard(
                    corner: skin.tileCorner,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        GlyphIcon(AppGlyphs.gift, color: colors.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.zolnitInviteShare,
                                style: zolnitText(
                                  context,
                                  14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                text.zolnitInviteNoData,
                                style: zolnitText(
                                  context,
                                  12,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlyphIcon(
                          AppGlyphs.chevronForward,
                          color: colors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
