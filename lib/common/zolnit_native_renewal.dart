import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constant.dart' show packageName;

abstract interface class ZolnitRenewalJournal {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

typedef ZolnitNativeRenewalCall =
    Future<Object?> Function(String method, Map<String, Object?>? arguments);

class ZolnitNativeRenewalSnapshot {
  const ZolnitNativeRenewalSnapshot({
    this.sessionEpoch,
    this.ownerId,
    this.ownsRenewal = false,
    this.ready = false,
    this.state = 'unavailable',
  });

  final int? sessionEpoch;
  final int? ownerId;
  final bool ownsRenewal;
  final bool ready;
  final String state;
}

class _Scope {
  const _Scope(this.epoch, this.owner, this.fingerprint, this.logoutPending);
  final int epoch;
  final int owner;
  final String fingerprint;
  final bool logoutPending;

  Map<String, Object> toJson() => {
    'epoch': epoch,
    'owner': owner,
    'fingerprint': fingerprint,
    'logout_pending': logoutPending,
  };

  static _Scope parse(String value) {
    final data = jsonDecode(value);
    if (data
        case {
          'epoch': final int epoch,
          'owner': final int owner,
          'fingerprint': final String fingerprint,
          'logout_pending': final bool pending,
        }
        when epoch > 0 &&
            owner > 0 &&
            RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
      return _Scope(epoch, owner, fingerprint, pending);
    }
    throw const FormatException('Invalid native renewal journal');
  }
}

class ZolnitNativeRenewalClient extends ChangeNotifier {
  ZolnitNativeRenewalClient({
    required ZolnitRenewalJournal journal,
    ZolnitNativeRenewalCall? call,
  }) : _journal = journal,
       _call = call ?? _invoke;

  static const _channel = MethodChannel('$packageName/service');
  final ZolnitRenewalJournal _journal;
  final ZolnitNativeRenewalCall _call;
  Future<void> _tail = Future.value();
  int _revision = 0;
  bool _disposed = false;
  var _snapshot = const ZolnitNativeRenewalSnapshot();

  ZolnitNativeRenewalSnapshot get snapshot => _snapshot;

  static Future<Object?> _invoke(
    String method,
    Map<String, Object?>? arguments,
  ) => _channel.invokeMethod<Object?>(method, arguments);

  static String _fingerprint(String authorization) =>
      sha256.convert(utf8.encode(authorization)).toString();

  Future<bool> allowsRestoration(String authorization) async {
    final text = await _journal.read();
    if (text == null) return true;
    final scope = _Scope.parse(text);
    return !scope.logoutPending ||
        scope.fingerprint != _fingerprint(authorization);
  }

  Future<ZolnitNativeRenewalSnapshot> configure({
    required String accountId,
    required int accountGeneration,
    required String authorization,
    required String distribution,
  }) {
    if (accountId.isEmpty ||
        accountGeneration <= 0 ||
        authorization.length > 16384 ||
        !RegExp(r'^Bearer [A-Za-z0-9._~+/=|-]+$').hasMatch(authorization) ||
        !const {'direct', 'apple-app-store'}.contains(distribution)) {
      return Future.error(StateError('Invalid native renewal binding'));
    }
    final revision = ++_revision;
    return _serialize(() async {
      if (revision != _revision || _disposed) return _snapshot;
      final result = await _call('configureClientBundleRenewal', {
        'accountId': accountId,
        'accountGeneration': accountGeneration,
        'authorization': authorization,
        'distribution': distribution,
      });
      if (result is! Map) {
        throw StateError('Native renewal returned an invalid receipt');
      }
      if (result['supported'] == false) {
        _set(const ZolnitNativeRenewalSnapshot(state: 'unavailable'));
        return _snapshot;
      }
      final epoch = result['sessionEpoch'];
      final owner = result['ownerId'];
      if (epoch is! int || epoch <= 0 || owner is! int || owner <= 0) {
        throw StateError('Native renewal did not bind a session');
      }
      final scope = _Scope(
        epoch,
        owner,
        _fingerprint(authorization),
        revision != _revision,
      );
      await _journal.write(jsonEncode(scope.toJson()));
      if (revision != _revision) {
        await _retire(scope);
        return _snapshot;
      }
      _set(_from(result));
      return _snapshot;
    });
  }

  Future<void> logout() {
    _revision++;
    _set(const ZolnitNativeRenewalSnapshot(state: 'revoking'));
    return _serialize(() async {
      final text = await _journal.read();
      if (text != null) {
        final scope = _Scope.parse(text);
        await _journal.write(
          jsonEncode(
            _Scope(scope.epoch, scope.owner, scope.fingerprint, true).toJson(),
          ),
        );
        await _retire(scope);
      }
      _set(const ZolnitNativeRenewalSnapshot(state: 'logged_out'));
    });
  }

  Future<void> poll() => _serialize(() async {
    final text = await _journal.read();
    if (text == null) return;
    final scope = _Scope.parse(text);
    if (scope.logoutPending) return;
    final result = await _call(
      'clientBundleRenewalStatus',
      null,
    ).timeout(const Duration(seconds: 3));
    if (result is! Map) return;
    if (result['sessionEpoch'] != scope.epoch) return;
    final state = result['state'];
    if (state == 'logged_out') {
      await _journal.write(
        jsonEncode(
          _Scope(scope.epoch, scope.owner, scope.fingerprint, true).toJson(),
        ),
      );
      _set(
        ZolnitNativeRenewalSnapshot(
          sessionEpoch: scope.epoch,
          ownerId: scope.owner,
          state: 'logged_out',
        ),
      );
      return;
    }
    if (result['ownerId'] is! int || (result['ownerId'] as int) < scope.owner) {
      return;
    }
    _set(_from(result));
  });

  Future<void> _retire(_Scope scope) async {
    final result = await _call('logoutClientBundleRenewal', {
      'sessionEpoch': scope.epoch,
    });
    if (result != true) {
      throw StateError('Native renewal cleanup was not acknowledged');
    }
    await _journal.clear();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  ZolnitNativeRenewalSnapshot _from(Map<dynamic, dynamic> value) =>
      ZolnitNativeRenewalSnapshot(
        sessionEpoch: value['sessionEpoch'] as int?,
        ownerId: value['ownerId'] as int?,
        ownsRenewal: value['ownsRenewal'] == true,
        ready: value['ready'] == true,
        state: value['state'] is String
            ? value['state'] as String
            : 'unavailable',
      );

  void _set(ZolnitNativeRenewalSnapshot value) {
    _snapshot = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
