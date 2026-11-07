import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zolnit_client/zolnit_client.dart';

class ZolnitGiftPreferencesStore implements ZolnitGiftAttemptStore {
  ZolnitGiftPreferencesStore(Uri origin, String accountUuid)
    : _storageKey =
          'zolnit.gift.pending.v1.${sha256.convert(utf8.encode('${origin.origin}\u0000$accountUuid'))}';

  final String _storageKey;
  static final _tails = Expando<Future<void>>();

  Future<T> _ordered<T>(Future<T> Function() action) async {
    final prefs = await SharedPreferences.getInstance();
    final result = (_tails[prefs] ?? Future<void>.value()).then(
      (_) => action(),
    );
    _tails[prefs] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<Map<String, String>> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null) return {};
    if (raw.length > 65536) throw StateError('pending gift storage invalid');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw StateError('pending gift storage invalid');
    final items = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key as String) ||
          !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(entry.value as String)) {
        throw StateError('pending gift storage invalid');
      }
      items[entry.key as String] = entry.value as String;
    }
    return items;
  }

  @override
  Future<String?> read(String cardHash) =>
      _ordered(() async => (await _load())[cardHash]);

  @override
  Future<void> write(String cardHash, String requestId) => _ordered(() async {
    final data = await _load();
    if (data.length >= 128 && !data.containsKey(cardHash)) {
      throw StateError('pending gift storage full');
    }
    final existing = data[cardHash];
    if (existing != null && existing != requestId) {
      throw StateError('pending gift request exists');
    }
    data[cardHash] = requestId;
    if (!await (await SharedPreferences.getInstance()).setString(
      _storageKey,
      jsonEncode(data),
    )) {
      throw StateError('pending gift storage unavailable');
    }
  });

  @override
  Future<void> remove(String cardHash, String requestId) => _ordered(() async {
    final data = await _load();
    if (data[cardHash] != requestId) return;
    data.remove(cardHash);
    final prefs = await SharedPreferences.getInstance();
    final ok = data.isEmpty
        ? await prefs.remove(_storageKey)
        : await prefs.setString(_storageKey, jsonEncode(data));
    if (!ok) throw StateError('pending gift storage unavailable');
  });
}
