import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fl_clash/common/package.dart';
import 'package:fl_clash/providers/zolnit_realtime.dart';
import 'package:zolnit_client/zolnit_client.dart';

final class ZolnitInboxCoordinator {
  ZolnitInboxCoordinator({
    required this.api,
    required this.current,
    required this.foreground,
    required this.liveRead,
    required this.updateTitle,
    required this.onConnect,
    required this.onPopup,
    required this.onUpdated,
    required this.onWithdrawn,
    required this.onUnread,
    required this.onUpdateHint,
  });

  final XboardClient Function() api;
  final bool Function(int) current;
  final bool Function() foreground;
  final Future<bool> Function(String) liveRead;
  final String Function() updateTitle;
  final void Function(String, int) onConnect;
  final void Function(ZolnitRealtimeInboxItem, String, int) onPopup;
  final void Function(ZolnitRealtimeInboxItem) onUpdated;
  final void Function(Set<String>) onWithdrawn;
  final void Function() onUnread;
  final void Function(String) onUpdateHint;
  final store = ZolnitRealtimePreferencesStore();
  final canonicalNotices = ValueNotifier<Map<String, ZolnitRealtimeInboxItem>>(
    {},
  );
  final noticeRevision = ValueNotifier<int>(0);
  final withdrawn = <String>{};
  final _readFlights = <(String, int, String)>{};
  final _pendingPresentation = <String, ZolnitInboxMerge>{};
  String? _subject;
  Future<void>? _flight;
  int? _flightGeneration, _flightEpoch;
  int _epoch = 0;
  int unread = 0;
  Timer? _readRetry;
  Future<PackageInfo?>? _installedPackage;
  bool _disposed = false;

  String? get scope =>
      _subject == null ? null : '${api().origin.origin}:$_subject';

  bool _current(int gen) => !_disposed && current(gen);

  void invalidate() => _epoch++;

  void reset() {
    _readRetry?.cancel();
    _readRetry = null;
    invalidate();
    _subject = null;
    withdrawn.clear();
    _pendingPresentation.clear();
    canonicalNotices.value = {};
    unread = 0;
  }

  void dispose() {
    _disposed = true;
    _readRetry?.cancel();
    _pendingPresentation.clear();
    canonicalNotices.dispose();
    noticeRevision.dispose();
  }

  Future<List<ZolnitRealtimeInboxItem>> read(String scope) =>
      store.readInbox(scope);

  Future<
    ({
      ZolnitRealtimeInboxItem item,
      String? updateVersion,
      bool installedUpdate,
    })?
  >
  _prepare(
    String id,
    String type,
    Json data,
    int gen,
    DateTime at,
    bool read,
  ) async {
    final String title, body;
    String? updateVersion;
    var installedUpdate = false;
    if (type == 'client.update') {
      final target = data['platform'],
          build = data['build'],
          version = data['version'];
      if ((target != 'all' && target != api().clientPlatform) ||
          build is! int ||
          build <= 0 ||
          version is! String ||
          !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
          version.length > 32) {
        return null;
      }
      _installedPackage ??= PackageInfo.fromPlatform()
          .then<PackageInfo?>((info) => info)
          .catchError((Object _) => null);
      final package = await _installedPackage;
      final currentBuild = int.tryParse(package?.buildNumber ?? '');
      if (currentBuild == null || currentBuild <= 0 || package == null) {
        _installedPackage = null;
        return null;
      }
      if (!_current(gen)) return null;
      final int comparison;
      try {
        comparison = compareVersions(package.version.split('+').first, version);
      } on FormatException {
        return null;
      }
      installedUpdate =
          comparison > 0 || (comparison == 0 && currentBuild >= build);
      if (!installedUpdate) updateVersion = version;
      title = '${updateTitle()} · $version';
      body = data['body'] is String
          ? data['body'] as String
          : 'ZolNit $version ($build)';
    } else if ({
      'notice.published',
      'notice.popup',
      'account.notice',
    }.contains(type)) {
      if (data['title'] is! String || data['body'] is! String) return null;
      title = data['title'] as String;
      body = data['body'] as String;
    } else {
      return null;
    }
    if (title.trim().isEmpty ||
        body.trim().isEmpty ||
        utf8.encode(title).length > 200 ||
        utf8.encode(body).length > 2048) {
      return null;
    }
    final item = ZolnitRealtimeInboxItem(
      id: id,
      title: title,
      body: body,
      createdAt: at,
      popup: type == 'notice.popup',
      read: read,
    );
    return (
      item: item,
      updateVersion: updateVersion,
      installedUpdate: installedUpdate,
    );
  }

  Future<void> apply(
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
    if (!_current(gen) || scope != this.scope) return;
    final prepared = await _prepare(id, type, data, gen, at, read);
    if (prepared == null || !_current(gen) || scope != this.scope) return;
    final item = prepared.item;
    final merge = canonical
        ? await store.applyCanonicalInbox(
            scope,
            item,
            isCurrent: () =>
                _current(gen) &&
                scope == this.scope &&
                (isCurrentSnapshot?.call() ?? false),
          )
        : (await store.appendInbox(
                scope,
                item,
                isCurrent: () => _current(gen) && scope == this.scope,
              )
              ? ZolnitInboxMerge.inserted
              : ZolnitInboxMerge.unchanged);
    await _present(
      prepared,
      merge,
      scope,
      gen,
      canonical: canonical,
      isCurrentSnapshot: isCurrentSnapshot,
    );
  }

  Future<void> _present(
    ({
      ZolnitRealtimeInboxItem item,
      String? updateVersion,
      bool installedUpdate,
    })
    prepared,
    ZolnitInboxMerge merge,
    String scope,
    int gen, {
    required bool canonical,
    bool Function()? isCurrentSnapshot,
    List<ZolnitRealtimeInboxItem>? batchInbox,
  }) async {
    final id = prepared.item.id;
    final read = prepared.item.read;
    final updateVersion = prepared.updateVersion;
    final installedUpdate = prepared.installedUpdate;
    if (!_current(gen) || scope != this.scope) return;
    if (canonical && merge != ZolnitInboxMerge.unchanged) {
      // An invalidated platform write needs presentation in a current snapshot.
      if (_pendingPresentation[id] != ZolnitInboxMerge.inserted) {
        _pendingPresentation[id] = merge;
      }
    }
    if (canonical && !(isCurrentSnapshot?.call() ?? false)) return;
    final automaticReadKey = (scope, gen, id);
    if (installedUpdate &&
        !read &&
        _current(gen) &&
        _readFlights.add(automaticReadKey)) {
      try {
        final stored = batchInbox ?? await store.readInbox(scope);
        final existing = stored.where((entry) => entry.id == id).firstOrNull;
        if (existing != null &&
            !existing.read &&
            _current(gen) &&
            (!canonical || (isCurrentSnapshot?.call() ?? false))) {
          final confirmed = await markRead(existing, scope, gen);
          if (confirmed && batchInbox != null) {
            final index = batchInbox.indexWhere((entry) => entry.id == id);
            if (index >= 0) batchInbox[index] = batchInbox[index].asRead();
          }
          if (!confirmed && _current(gen)) {
            _readRetry ??= Timer(const Duration(minutes: 1), () {
              _readRetry = null;
              if (_current(gen)) {
                unawaited(refresh(gen).catchError((Object _) {}));
              }
            });
          }
        }
      } finally {
        _readFlights.remove(automaticReadKey);
      }
    }
    if (canonical && !(isCurrentSnapshot?.call() ?? false)) return;
    final presentation = canonical ? _pendingPresentation[id] ?? merge : merge;
    if (presentation == ZolnitInboxMerge.unchanged) return;
    final inbox = batchInbox ?? await _updateUnread(scope, gen);
    if (!_current(gen) || scope != this.scope) return;
    if (canonical && !(isCurrentSnapshot?.call() ?? false)) return;
    if (canonical) _pendingPresentation.remove(id);
    final confirmed = inbox.where((entry) => entry.id == id).firstOrNull;
    if (confirmed == null) return;
    final fresh = presentation == ZolnitInboxMerge.inserted;
    if (presentation == ZolnitInboxMerge.updated) {
      canonicalNotices.value = {...canonicalNotices.value, id: confirmed};
      onUpdated(confirmed);
    }
    if (fresh && updateVersion != null) {
      onUpdateHint(updateVersion);
    }
    if (fresh && !confirmed.read && foreground() && confirmed.popup) {
      onPopup(confirmed, scope, gen);
    }
  }

  Future<List<ZolnitRealtimeInboxItem>> _updateUnread(
    String scope,
    int gen,
  ) async {
    final inbox = await store.readInbox(scope);
    _setUnread(inbox, scope, gen);
    return inbox;
  }

  void _setUnread(List<ZolnitRealtimeInboxItem> inbox, String scope, int gen) {
    final count = inbox.where((item) => !item.read).length;
    if (_current(gen) && scope == this.scope && unread != count) {
      unread = count;
      onUnread();
    }
  }

  Future<bool> markRead(
    ZolnitRealtimeInboxItem item,
    String scope,
    int gen,
  ) async {
    if (item.read || !_current(gen) || scope != this.scope) {
      return false;
    }
    try {
      final live = await liveRead(item.id);
      if (!_current(gen)) return false;
      if (!live) await api().markRealtimeInboxRead(item.id);
      if (_current(gen)) {
        await store.appendInbox(
          scope,
          item.asRead(),
          isCurrent: () => _current(gen) && scope == this.scope,
        );
      }
      if (_current(gen)) await _updateUnread(scope, gen);
      return _current(gen);
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh(int gen) {
    if (_flightGeneration == gen && _flight != null) {
      final activeEpoch = _flightEpoch;
      return _flight!.then((_) {
        if (_current(gen) && activeEpoch != _epoch) {
          return refresh(gen);
        }
      });
    }
    _flightGeneration = gen;
    final epoch = _epoch;
    _flightEpoch = epoch;
    bool currentSnapshot() => _current(gen) && epoch == _epoch;
    late final Future<void> job;
    job =
        Future<void>.microtask(() async {
          final inbox = await api().realtimeInbox();
          if (!currentSnapshot()) return;
          final scope = '${api().origin.origin}:${inbox.subject}';
          if (_subject != null && _subject != inbox.subject) {
            throw StateError('account binding changed');
          }
          _subject = inbox.subject;
          final prepared =
              <
                ({
                  ZolnitRealtimeInboxItem item,
                  String? updateVersion,
                  bool installedUpdate,
                })
              >[];
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
                seconds > 253402300799)
              continue;
            final value = await _prepare(
              id,
              type,
              data,
              gen,
              DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
              e['read'] == true,
            );
            if (value != null) prepared.add(value);
          }
          if (!currentSnapshot()) return;
          final batch = await store.mergeSnapshot(
            scope,
            [for (final e in prepared) e.item],
            inbox.withdrawn,
            isCurrent: () => currentSnapshot() && scope == this.scope,
          );
          if (!_current(gen) || scope != this.scope) return;
          for (final entry in batch.merges.entries) {
            if (_pendingPresentation[entry.key] != ZolnitInboxMerge.inserted) {
              _pendingPresentation[entry.key] = entry.value;
            }
          }
          if (!currentSnapshot()) return;
          if (inbox.withdrawn.isNotEmpty) {
            withdrawn.addAll(inbox.withdrawn);
            for (final id in inbox.withdrawn) {
              _pendingPresentation.remove(id);
            }
            onWithdrawn(withdrawn);
            noticeRevision.value++;
          }
          _setUnread(batch.inbox, scope, gen);
          final presented = <String>{};
          for (final entry in prepared) {
            if (!currentSnapshot()) return;
            if (!presented.add(entry.item.id)) continue;
            await _present(
              entry,
              batch.merges[entry.item.id] ?? ZolnitInboxMerge.unchanged,
              scope,
              gen,
              canonical: true,
              isCurrentSnapshot: currentSnapshot,
              batchInbox: batch.inbox,
            );
          }
          if (currentSnapshot()) {
            _pendingPresentation.clear();
            onConnect(scope, gen);
          }
        }).whenComplete(() {
          if (identical(_flight, job)) _flight = null;
        });
    return _flight = job;
  }
}
