import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

final zolnitRealtimeConnectorProvider = Provider<ZolnitRealtimeConnect?>(
  (_) => null,
);

final class ZolnitRealtimeInboxItem {
  const ZolnitRealtimeInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.popup,
    this.read = false,
  });
  final String id, title, body;
  final DateTime createdAt;
  final bool popup, read;
  ZolnitRealtimeInboxItem asRead() => ZolnitRealtimeInboxItem(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    popup: popup,
    read: true,
  );
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'popup': popup,
    'read': read,
  };
  static ZolnitRealtimeInboxItem? fromJson(dynamic j) {
    if (j is! Map ||
        j['id'] is! String ||
        j['title'] is! String ||
        j['body'] is! String ||
        j['createdAt'] is! int ||
        j['popup'] is! bool) {
      return null;
    }
    return ZolnitRealtimeInboxItem(
      id: j['id'],
      title: j['title'],
      body: j['body'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt']),
      popup: j['popup'],
      read: j['read'] == true,
    );
  }
}

final class ZolnitRealtimePreferencesStore implements ZolnitRealtimeStore {
  String _key(String scope) =>
      'zolnit.realtime.v1.${base64Url.encode(utf8.encode(scope))}';
  Future<void> _tail = Future.value();
  Future<T> _ordered<T>(Future<T> Function() job) {
    final next = _tail.then((_) => job());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<dynamic> _load(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.length > 524288) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _put(String key, Object data) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(data),
    )) {
      throw StateError('notification storage unavailable');
    }
  }

  @override
  Future<ZolnitRealtimeState> read(String scope) async {
    final j = await _load(_key(scope));
    final cursor = j is Map ? ZolnitRealtimeCursor.parse(j['cursor']) : null;
    if (cursor == null || j['dedup'] is! List) {
      return const ZolnitRealtimeState();
    }
    return ZolnitRealtimeState(
      cursor: cursor,
      dedup: (j['dedup'] as List).whereType<String>().take(256).toSet(),
    );
  }

  @override
  Future<void> write(String scope, ZolnitRealtimeState state) => _ordered(
    () => _put(_key(scope), {
      'cursor': state.cursor.toJson(),
      'dedup': state.dedup.toList(),
    }),
  );
  Future<List<ZolnitRealtimeInboxItem>> readInbox(String scope) async {
    final j = await _load('${_key(scope)}.inbox');
    if (j is! List) return [];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return j
        .map(ZolnitRealtimeInboxItem.fromJson)
        .whereType<ZolnitRealtimeInboxItem>()
        .where((e) => e.createdAt.isAfter(cutoff))
        .take(128)
        .toList();
  }

  Future<bool> appendInbox(String scope, ZolnitRealtimeInboxItem item) =>
      _ordered(() async {
        final list = await readInbox(scope);
        final i = list.indexWhere((e) => e.id == item.id);
        if (i >= 0) {
          if (!item.read || list[i].read) return false;
          list[i] = list[i].asRead();
        } else {
          list.add(item);
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        await _put(
          '${_key(scope)}.inbox',
          list.take(128).map((e) => e.toJson()).toList(),
        );
        return i < 0;
      });
}
