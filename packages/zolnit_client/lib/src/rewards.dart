import 'dart:math';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'api.dart';

/// The rewards service uses the same account and generation as [XboardClient].
class ZolnitRewardsClient {
  const ZolnitRewardsClient(this.api);

  final XboardClient api;
  static const _base = '/api/v1/zolnit-rewards';

  Future<Json> _object(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    Map<String, String> headers = const {},
  }) async {
    final result = await api.request(
      '$_base$path',
      method: method,
      body: body,
      query: query,
      extraHeaders: headers,
    );
    if (result is! Json) throw const ClientFailure('invalid_response');
    return result;
  }

  Future<bool> giftCardsAvailable() async {
    try {
      final config = await _object('/config');
      return config['enabled'] == true && config['gift_card_enabled'] == true;
    } on ClientFailure catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<Json> check(String code) =>
      _object('/gift-card/check', method: 'POST', body: {'code': code});

  Future<Json> redeem(String code, String idempotencyKey) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(idempotencyKey)) {
      throw const ClientFailure('invalid_idempotency_key');
    }
    return _object(
      '/gift-card/redeem',
      method: 'POST',
      body: {'code': code},
      headers: {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<Json> history({int page = 1}) {
    if (page < 1) throw const ClientFailure('invalid_page');
    return _object('/gift-card/history', query: {'page': '$page'});
  }

  Future<Json> referralOffer({
    required int planId,
    required String period,
    required bool recurring,
  }) {
    if (planId < 1 ||
        !const {
          'monthly',
          'quarterly',
          'half_yearly',
          'yearly',
          'two_yearly',
          'three_yearly',
          'onetime',
        }.contains(period)) {
      throw const ClientFailure('invalid_offer');
    }
    return _object(
      '/referral-offer',
      query: {
        'plan_id': '$planId',
        'period': period,
        'recurring': recurring ? '1' : '0',
      },
    );
  }
}

abstract interface class ZolnitGiftAttemptStore {
  Future<String?> read(String cardHash);
  Future<void> write(String cardHash, String requestId);
  Future<void> remove(String cardHash, String requestId);
}

class ZolnitGiftCardAttempt {
  ZolnitGiftCardAttempt(this.client, {this.store})
    : _generation = client.api.generation;

  final ZolnitRewardsClient client;
  final ZolnitGiftAttemptStore? store;
  final int _generation;
  String _code = '';
  String _input = '';
  String? _key;
  String? _keyCode;
  int _revision = 0;
  bool _redeeming = false;
  bool _uncertain = false;
  Json? preview;
  Json? result;

  bool get canRetry =>
      _uncertain &&
      _key != null &&
      _keyCode == _code &&
      RegExp(r'^[A-Za-z0-9_-]{4,128}$').hasMatch(_input.trim());

  void _ensureCurrent(int revision) {
    if (_generation != client.api.generation || revision != _revision) {
      throw const ClientFailure('superseded');
    }
  }

  void edit(String code) {
    if (code == _input) return;
    _input = code;
    final trimmed = code.trim();
    final normalized = trimmed.toUpperCase();
    if (!_uncertain && normalized != _code) {
      _key = null;
      _keyCode = null;
    }
    _code = normalized;
    _revision++;
    preview = null;
    result = null;
  }

  void clear() {
    _input = '';
    _code = '';
    _key = null;
    _keyCode = null;
    _uncertain = false;
    preview = null;
    result = null;
    _revision++;
  }

  Future<Json> check() async {
    final revision = _revision;
    _ensureCurrent(revision);
    preview = null;
    if (!RegExp(r'^[A-Za-z0-9_-]{4,128}$').hasMatch(_input.trim())) {
      throw const ClientFailure('invalid_gift_code');
    }
    final value = await client.check(_code);
    _ensureCurrent(revision);
    if (value['can_redeem'] is! bool || value['template'] is! Json) {
      throw const ClientFailure('invalid_response');
    }
    preview = value;
    return value;
  }

  Future<void> recover() async {
    final revision = _revision;
    _ensureCurrent(revision);
    if (!RegExp(r'^[A-Za-z0-9_-]{4,128}$').hasMatch(_input.trim())) return;
    final saved = await store?.read(_hash(_code));
    _ensureCurrent(revision);
    if (saved != null && RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(saved)) {
      _key = saved;
      _keyCode = _code;
      _uncertain = true;
    }
  }

  Future<Json> redeem() async {
    final revision = _revision;
    _ensureCurrent(revision);
    if (_redeeming ||
        result != null ||
        (preview?['can_redeem'] != true && !canRetry)) {
      throw const ClientFailure('redemption_unavailable');
    }
    if (_keyCode != _code) {
      _key = _newKey();
      _keyCode = _code;
      _uncertain = false;
    }
    _key ??= _newKey();
    _redeeming = true;
    try {
      await store?.write(_hash(_code), _key!);
      _ensureCurrent(revision);
      final value = await client.redeem(_code, _key!);
      _ensureCurrent(revision);
      if (value['rewards'] is! Json) {
        throw const ClientFailure('invalid_response');
      }
      result = value;
      _uncertain = false;
      try {
        await store?.remove(_hash(_code), _key!);
      } catch (_) {
        // Keeping the same request ID permits safe recovery if clearing fails.
      }
      _ensureCurrent(revision);
      return value;
    } on ClientFailure catch (error) {
      if (_generation == client.api.generation &&
          revision == _revision &&
          (error.code == 'timeout' ||
              error.code == 'network' ||
              error.code == 'invalid_response' ||
              (error.statusCode ?? 0) >= 500)) {
        _uncertain = true;
      }
      rethrow;
    } finally {
      _redeeming = false;
    }
  }

  String _newKey() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  String _hash(String code) => sha256.convert(utf8.encode(code)).toString();
}
