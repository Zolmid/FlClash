import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'api.dart';
import 'routing_manifest.dart';

class ZolnitBundleOutbound {
  const ZolnitBundleOutbound({
    required this.id,
    required this.proxyName,
    required this.displayName,
  });

  final String id;
  final String proxyName;
  final String displayName;

  Json toJson() => Map<String, dynamic>.unmodifiable({
    'id': id,
    'proxy_name': proxyName,
    'display_name': displayName,
  });
}

class ZolnitClientBundle {
  const ZolnitClientBundle._({
    required this.accountId,
    required this.bundleId,
    required this.issuedAt,
    required this.expiresAt,
    required this.connectionSha256,
    required this.routingSha256,
    required this.document,
    required this.outbounds,
    required this.routingJson,
    required this.routingManifest,
    required this.exitIds,
  });

  final String accountId;
  final String bundleId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String connectionSha256;
  final String routingSha256;
  final String document;
  final List<ZolnitBundleOutbound> outbounds;
  final Json routingJson;
  final SmartRoutingManifest routingManifest;
  final Map<String, String> exitIds;

  static final _controls = RegExp(r'[\x00-\x1f\x7f]');
  static final _nodeId = RegExp(r'^[a-z][a-z0-9-]*:[1-9][0-9]*$');
  static final _exitId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$');
  static final _digest = RegExp(r'^[0-9a-f]{64}$');

  static ZolnitClientBundle parse(
    Json raw, {
    required DateTime now,
    String? expectedAccountId,
    bool allowExpired = false,
  }) {
    if (raw['schema_version'] is! int ||
        raw['schema_version'] != 1 ||
        !_safeText(raw['account_id']) ||
        !_safeText(raw['bundle_id'])) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final issuedAt = _timestamp(raw['issued_at']);
    final expiresAt = _timestamp(raw['expires_at']);
    final lifetime = (raw['expires_at'] as int) - (raw['issued_at'] as int);
    if (issuedAt.isAfter(now) || lifetime <= 0 || lifetime > 300) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final connection = raw['connection'];
    if (connection is! Map ||
        connection['engine'] != 'mihomo' ||
        connection['format'] != 'yaml' ||
        connection['sha256'] is! String ||
        !_matches(_digest, connection['sha256'] as String) ||
        connection['document'] is! String ||
        (connection['document'] as String).isEmpty) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final document = connection['document'] as String;
    final digest = connection['sha256'] as String;
    if (sha256.convert(utf8.encode(document)).toString() != digest) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final rawOutbounds = raw['outbounds'];
    if (rawOutbounds is! List ||
        rawOutbounds.isEmpty ||
        rawOutbounds.length > 4096) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final outbounds = <ZolnitBundleOutbound>[];
    final outboundNames = <String, String>{};
    final proxyNames = <String>{};
    for (final outbound in rawOutbounds) {
      if (outbound is! Map ||
          outbound['id'] is! String ||
          !_matches(_nodeId, outbound['id'] as String) ||
          !_safeText(outbound['display_name'])) {
        throw const ClientFailure('invalid_client_bundle');
      }
      final id = outbound['id'] as String;
      final proxyName = 'zn.node.${id.replaceFirst(':', '.')}';
      if (outbound['proxy_name'] != proxyName ||
          outboundNames.containsKey(id) ||
          !proxyNames.add(proxyName)) {
        throw const ClientFailure('invalid_client_bundle');
      }
      outboundNames[id] = proxyName;
      outbounds.add(
        ZolnitBundleOutbound(
          id: id,
          proxyName: proxyName,
          displayName: outbound['display_name'] as String,
        ),
      );
    }
    final routing = raw['routing'];
    if (routing is! Map ||
        routing['services'] is! List ||
        routing['nodes'] is! List) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final services = routing['services'] as List;
    final nodes = routing['nodes'] as List;
    if (services.isEmpty || services.length > 16 || nodes.length > 4096) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final groupNames = <String>{};
    for (final service in services) {
      if (service is! Map || service['id'] is! String) {
        throw const ClientFailure('invalid_client_bundle');
      }
      final group = 'zn.service.${service['id']}';
      if (service['group'] != group ||
          service['automatic'] != '$group.auto' ||
          service['manual'] != '$group.manual') {
        throw const ClientFailure('invalid_client_bundle');
      }
      groupNames.add(group);
    }
    final exitIds = <String, String>{};
    for (final node in nodes) {
      if (node is! Map ||
          node['id'] is! String ||
          !outboundNames.containsKey(node['id']) ||
          node['proxy_name'] != outboundNames[node['id']] ||
          node['exit_id'] is! String ||
          !_matches(_exitId, node['exit_id'] as String) ||
          exitIds.containsKey(node['id'])) {
        throw const ClientFailure('invalid_client_bundle');
      }
      exitIds[node['id'] as String] = node['exit_id'] as String;
    }
    final manifest = SmartRoutingManifest.parse(
      routing,
      proxyNames: proxyNames,
      groupNames: groupNames,
    );
    // The shared parser filters invalid nodes; a client bundle must lose none.
    if (manifest == null || manifest.nodes.length != nodes.length) {
      throw const ClientFailure('invalid_client_bundle');
    }
    final routingJson = _freeze(routing) as Json;
    if (expectedAccountId != null && raw['account_id'] != expectedAccountId) {
      throw const ClientFailure('client_bundle_binding_mismatch');
    }
    if (!allowExpired && !expiresAt.isAfter(now)) {
      throw const ClientFailure('client_bundle_expired');
    }
    return ZolnitClientBundle._(
      accountId: raw['account_id'] as String,
      bundleId: raw['bundle_id'] as String,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      connectionSha256: digest,
      routingSha256: sha256
          .convert(utf8.encode(jsonEncode(routingJson)))
          .toString(),
      document: document,
      outbounds: List.unmodifiable(outbounds),
      routingJson: routingJson,
      routingManifest: manifest,
      exitIds: Map.unmodifiable(exitIds),
    );
  }

  bool isFresh(DateTime now) =>
      !issuedAt.isAfter(now) && expiresAt.isAfter(now);

  Json toJson() => Map<String, dynamic>.unmodifiable({
    'schema_version': 1,
    'account_id': accountId,
    'bundle_id': bundleId,
    'issued_at': issuedAt.millisecondsSinceEpoch ~/ 1000,
    'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'connection': Map<String, dynamic>.unmodifiable({
      'engine': 'mihomo',
      'format': 'yaml',
      'sha256': connectionSha256,
      'document': document,
    }),
    'outbounds': List<Json>.unmodifiable(outbounds.map((o) => o.toJson())),
    'routing': routingJson,
  });

  static bool _matches(RegExp pattern, String value) =>
      pattern.firstMatch(value)?.group(0) == value;

  static bool _safeText(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 256 &&
      value.trim() == value &&
      !_controls.hasMatch(value);

  static DateTime _timestamp(Object? value) {
    if (value is! int || value < -8640000000000 || value > 8640000000000) {
      throw const ClientFailure('invalid_client_bundle');
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const ClientFailure('invalid_client_bundle');
        }
        result[entry.key as String] = _freeze(entry.value);
      }
      return Map<String, dynamic>.unmodifiable(result);
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    if (value == null ||
        value is String ||
        value is bool ||
        value is int ||
        (value is double && value.isFinite)) {
      return value;
    }
    throw const ClientFailure('invalid_client_bundle');
  }
}
