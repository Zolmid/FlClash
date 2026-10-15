import 'dart:io';

/// WinINet requires bracketed IPv6 hosts, without interface zone IDs.
List<String> windowsBypassList(List<String> bypassDomain) {
  final entries = <String>{};
  for (final domain in bypassDomain) {
    final entry = domain.trim();
    if (entry.isEmpty) continue;
    entries.add(_normalizeIPv6(entry));
  }
  return {...entries, '<local>'}.toList();
}

String _normalizeIPv6(String entry) {
  final prefixStart = entry.indexOf('/');
  var address = prefixStart < 0 ? entry : entry.substring(0, prefixStart);
  final prefix = prefixStart < 0 ? '' : entry.substring(prefixStart);
  if (address.startsWith('[') && address.endsWith(']')) {
    address = address.substring(1, address.length - 1);
  }
  final zoneStart = address.indexOf('%');
  final host = zoneStart < 0 ? address : address.substring(0, zoneStart);
  return InternetAddress.tryParse(host)?.type == InternetAddressType.IPv6
      ? '[$host]$prefix'
      : entry;
}
