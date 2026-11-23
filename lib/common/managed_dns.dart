import 'dart:io';

String? _domain(String raw) {
  var name = raw.toLowerCase().trim();
  if (name.startsWith('+.')) name = name.substring(2);
  if (name.endsWith('.')) name = name.substring(0, name.length - 1);
  if (name.length > 253 ||
      (!name.contains('.') && !{'lan', 'local', 'internal'}.contains(name))) {
    return null;
  }
  final labels = name.split('.');
  final valid = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  return labels.every(valid.hasMatch) ? name : null;
}

bool _privateResolver(String raw, String domain) {
  final value = raw.trim();
  if (value == 'system' || value == 'system://') {
    return [
      '.lan',
      '.local',
      '.internal',
      '.home.arpa',
    ].any((suffix) => domain == suffix.substring(1) || domain.endsWith(suffix));
  }
  var host = value;
  final port = RegExp(
    r'^(?:\[([^]]+)\]|([0-9.]+)):(\d{1,5})$',
  ).firstMatch(value);
  if (port != null) {
    final number = int.parse(port.group(3)!);
    if (number < 1 || number > 65535) return false;
    host = port.group(1) ?? port.group(2)!;
  }
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return bytes[0] & 0xfe == 0xfc;
}

bool _encryptedResolver(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'tls') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

bool _validResolvers(Object? value, {String? domain}) {
  final servers = value is List ? value : [value];
  return servers.isNotEmpty &&
      servers.every(
        (server) =>
            server is String &&
            (_encryptedResolver(server) ||
                (domain != null && _privateResolver(server, domain))),
      );
}

Map<String, dynamic> managedDnsMerge(
  Map<String, dynamic> source,
  Map<String, dynamic> overrides,
) {
  final nameservers = source['nameserver'];
  if (source['enable'] == false ||
      nameservers is! List ||
      !_validResolvers(nameservers)) {
    throw const FormatException('invalid_managed_dns');
  }
  for (final key in [
    'fallback',
    'default-nameserver',
    'direct-nameserver',
    'proxy-server-nameserver',
  ]) {
    final value = source[key];
    if (value != null &&
        !(value is List && value.isEmpty) &&
        !_validResolvers(value)) {
      throw const FormatException('invalid_managed_dns');
    }
  }
  final result = Map<String, dynamic>.from(source)..['enable'] = true;
  final original = source['nameserver-policy'];
  if (original != null && original is! Map) {
    throw const FormatException('invalid_managed_dns');
  }
  final policy = <String, dynamic>{
    if (original is Map) ...Map<String, dynamic>.from(original),
  };
  for (final key in ['nameserver-policy', 'proxy-server-nameserver-policy']) {
    final policies = source[key];
    if (policies == null) continue;
    if (policies is! Map) throw const FormatException('invalid_managed_dns');
    for (final entry in policies.entries) {
      final domain = entry.key is String ? _domain(entry.key as String) : null;
      if (!_validResolvers(entry.value, domain: domain)) {
        throw const FormatException('invalid_managed_dns');
      }
    }
  }
  final additions = overrides['nameserver-policy'];
  if (additions is Map) {
    for (final entry in additions.entries) {
      if (entry.key is! String) continue;
      if (policy.containsKey(entry.key)) continue;
      final name = _domain(entry.key as String);
      final servers = entry.value is List ? entry.value as List : [entry.value];
      if (name == null ||
          servers.isEmpty ||
          servers.any((v) => v is! String || !_privateResolver(v, name))) {
        continue;
      }
      if (policy.keys.any((key) {
        final signed = _domain(key);
        return signed == null ||
            name == signed ||
            name.endsWith('.$signed') ||
            signed.endsWith('.$name');
      })) {
        throw const FormatException('managed_dns_policy_conflict');
      }
      policy[entry.key as String] = entry.value;
    }
  }
  if (policy.isNotEmpty || original != null) {
    result['nameserver-policy'] = policy;
  }
  return result;
}
