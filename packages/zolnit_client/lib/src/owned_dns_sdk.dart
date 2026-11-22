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
       _enabled = diagnosticEnabled ?? false,
       _mobile = mobile ?? (Platform.isAndroid || Platform.isIOS);

  final MethodChannel _channel;
  final bool _enabled;
  final bool _mobile;
  Set<String> _hosts = const {};
  int _generation = 0;

  Future<bool> configureDiagnostic({
    required Set<String> hosts,
    required String accountId,
    required String accessKeyId,
    required String accessKeySecret,
  }) async {
    final generation = ++_generation;
    _hosts = const {};
    if (!_enabled ||
        !_mobile ||
        hosts.isEmpty ||
        hosts.length > 256 ||
        hosts.any((host) => !validOwnedSdkHost(host)) ||
        [accountId, accessKeyId, accessKeySecret].any(
          (value) =>
              value.isEmpty ||
              value.length > 512 ||
              RegExp(r'[^\x21-\x7e]').hasMatch(value),
        )) {
      return false;
    }
    try {
      final available = await _channel
          .invokeMethod<bool>('configureOwnedDnsSdkDiagnostic', {
            'hosts': hosts.toList(),
            'accountId': accountId,
            'accessKeyId': accessKeyId,
            'accessKeySecret': accessKeySecret,
          })
          .timeout(const Duration(seconds: 3));
      if (available != true || generation != _generation) return false;
      _hosts = Set.unmodifiable(hosts);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<OwnedDnsAnswer?> lookup(String host) async {
    if (!_enabled || !_mobile || !_hosts.contains(host)) return null;
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
