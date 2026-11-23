import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'owned_dns.dart';

class OwnedDnsSdkAdapter {
  OwnedDnsSdkAdapter({
    MethodChannel? channel,
    bool? diagnosticEnabled,
    bool? mobile,
  }) : _channel = channel ?? const MethodChannel('com.zolmid.zolnit/service'),
       _enabled = diagnosticEnabled ?? true,
       _mobile = mobile ?? (Platform.isAndroid || Platform.isIOS);

  final MethodChannel _channel;
  final bool _enabled;
  final bool _mobile;
  Set<String> _hosts = const {};
  int _generation = 0;

  DateTime? _expiresAt;
  bool get supported => _enabled && _mobile;

  Future<bool> configureDiagnostic({
    required Set<String> hosts,
    required String accountId,
    required String accessKeyId,
    required String accessKeySecret,
  }) async => false;

  Future<bool> configureLoopback({
    required Set<String> hosts,
    required int port,
    required String keyId,
    required String secret,
    required DateTime expiresAt,
  }) async {
    final generation = ++_generation;
    _hosts = const {};
    if (!supported ||
        hosts.isEmpty ||
        hosts.length > 256 ||
        hosts.any((host) => !validOwnedSdkHost(host)) ||
        port < 1 ||
        port > 65535 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(keyId) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(secret) ||
        !expiresAt.isAfter(DateTime.now()) ||
        expiresAt.difference(DateTime.now()) > const Duration(minutes: 5)) {
      return false;
    }
    try {
      final ready = await _channel
          .invokeMethod<bool>('configureOwnedDnsSdkLoopback', {
            'hosts': hosts.toList(),
            'port': port,
            'keyId': keyId,
            'secret': secret,
            'expiresAt': expiresAt.millisecondsSinceEpoch,
          })
          .timeout(const Duration(seconds: 3));
      if (ready != true || generation != _generation) return false;
      _hosts = Set.unmodifiable(hosts);
      _expiresAt = expiresAt;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<OwnedDnsAnswer?> lookup(String host) async {
    if (!supported ||
        !_hosts.contains(host) ||
        _expiresAt == null ||
        !DateTime.now().isBefore(_expiresAt!)) {
      return null;
    }
    final generation = _generation;
    try {
      final values = await _channel
          .invokeListMethod<String>('lookupOwnedDnsSdk', {'host': host})
          .timeout(const Duration(seconds: 3));
      if (generation != _generation || values == null || values.isEmpty) {
        return null;
      }
      return OwnedDnsAnswer(values, 0);
    } catch (_) {
      return null;
    }
  }

  Future<void> disable() async {
    _generation++;
    _hosts = const {};
    if (!_enabled || !_mobile) return;
    try {
      await _channel
          .invokeMethod<void>('disableOwnedDnsSdk')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

bool validOwnedSdkHost(String host) =>
    host.length <= 253 &&
    RegExp(r'^[a-z0-9]+(?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(host) &&
    host
        .split('.')
        .every(
          (label) =>
              label.isNotEmpty &&
              label.length <= 63 &&
              !label.startsWith('-') &&
              !label.endsWith('-'),
        ) &&
    (host == 'link.zolmid.com' || host.endsWith('.nodes.zolmid.com'));

final ownedDnsSdkAdapter = OwnedDnsSdkAdapter();
