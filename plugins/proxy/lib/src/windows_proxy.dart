import 'dart:io';

/// WinINet rejects the whole list over one bare IPv6 literal or one entry
/// ending in `/`, so the system proxy is not set at all, and its `<local>`
/// token for single-label intranet hosts like `nas` has no cross-platform
/// pattern. Loopback needs no entry: WinINet never proxies it.
List<String> windowsBypassList(List<String> bypassDomain) {
  final entries = <String>{};
  for (final domain in bypassDomain) {
    final entry = domain.trim().replaceFirst(_trailingSlashes, '');
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

final _trailingSlashes = RegExp(r'/+$');
