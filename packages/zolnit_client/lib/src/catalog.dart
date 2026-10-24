import 'dart:convert';

import 'api.dart' show Json;
import 'parse.dart';

final _tag = RegExp(r'<[^>]*>');
final _lineBreak = RegExp(
  r'<\s*(?:br\s*/?|/?(?:p|div|ul|ol|li|h[1-6])(?:\s[^>]*)?)\s*>',
  caseSensitive: false,
);
final _listMarker = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+');
final _classed = RegExp(
  r'<(p|span|ul)\b[^>]*?\bclass\s*=\s*"([^"]*)"[^>]*>(.*?)</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _inlineEdge = RegExp(
  r'(</(?:strong|span|b|em)>)\s*(?=<)',
  caseSensitive: false,
);

String _decode(String text) => text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

String _clip(String line, int limit) =>
    line.length <= limit ? line : '${line.substring(0, limit - 1)}…';

/// Splits rich-text or markdown panel content into short plain lines.
List<String> plainLines(
  Object? content, {
  int maxLines = 8,
  int maxLength = 60,
}) {
  if (content is List) {
    return plainLines(
      content.whereType<String>().join('\n'),
      maxLines: maxLines,
      maxLength: maxLength,
    );
  }
  if (content is! String) return const [];
  var source = content.trim();
  if (source.startsWith('[')) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) source = decoded.whereType<String>().join('\n');
    } on FormatException {
      // Plain text that merely starts with a bracket.
    }
  }
  source = source.replaceAll(_lineBreak, '\n');
  final lines = <String>[];
  for (final raw in _decode(
    source.replaceAll(_tag, ''),
  ).split(RegExp(r'\r?\n'))) {
    final line = raw.replaceFirst(_listMarker, '').trim();
    if (line.isNotEmpty) lines.add(_clip(line, maxLength));
    if (lines.length == maxLines) break;
  }
  return lines;
}

class _Region {
  const _Region(this.name, this.code, this.aliases);

  final String name;
  final String code;
  final List<String> aliases;
}

const _regions = <_Region>[
  _Region('香港', 'HK', ['hong kong', 'hongkong', 'hk', 'hkg']),
  _Region('台湾', 'TW', ['taiwan', 'tw', 'tpe', '台灣', '台北']),
  _Region('日本', 'JP', ['japan', 'jp', 'tokyo', 'osaka', '东京', '大阪']),
  _Region('新加坡', 'SG', ['singapore', 'sg', 'sgp', '狮城']),
  _Region('美国', 'US', ['united states', 'usa', 'us', 'america', '洛杉矶', '圣何塞']),
  _Region('韩国', 'KR', ['korea', 'kr', 'seoul', '首尔']),
  _Region('英国', 'GB', ['united kingdom', 'uk', 'gb', 'london', '伦敦']),
  _Region('德国', 'DE', ['germany', 'de', 'frankfurt', '法兰克福']),
  _Region('法国', 'FR', ['france', 'fr', 'paris', '巴黎']),
  _Region('加拿大', 'CA', ['canada', 'ca']),
  _Region('澳大利亚', 'AU', ['australia', 'au', '澳洲']),
  _Region('马来西亚', 'MY', ['malaysia', 'my']),
  _Region('泰国', 'TH', ['thailand', 'th']),
  _Region('越南', 'VN', ['vietnam', 'vn']),
  _Region('印度', 'IN', ['india']),
  _Region('俄罗斯', 'RU', ['russia', 'ru']),
  _Region('土耳其', 'TR', ['turkey', 'tr']),
  _Region('巴西', 'BR', ['brazil', 'br']),
  _Region('荷兰', 'NL', ['netherlands', 'nl']),
  _Region('澳门', 'MO', ['macau', 'macao', 'mo']),
  _Region('菲律宾', 'PH', ['philippines', 'ph']),
  _Region('印度尼西亚', 'ID', ['indonesia', 'id', '印尼']),
  _Region('阿根廷', 'AR', ['argentina', 'ar']),
  _Region('阿联酋', 'AE', ['united arab emirates', 'uae', 'ae', 'dubai', '迪拜']),
  _Region('尼日利亚', 'NG', ['nigeria', 'ng']),
  _Region('中国', 'CN', ['china', 'cn', '国内']),
];

String flagEmoji(String code) => String.fromCharCodes(
  code.toUpperCase().codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
);

bool _isIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

final _cjk = RegExp(r'[\u3400-\u9fff]');

_Region? _matchRegion(String name) {
  final lower = name.toLowerCase();
  final tokens = lower
      .split(RegExp(r'[^a-z0-9\u3400-\u9fff]+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isNotEmpty) {
    final first = tokens.first;
    for (final region in _regions) {
      if (first == region.code.toLowerCase() ||
          first == region.name ||
          region.aliases.contains(first)) {
        return region;
      }
    }
  }
  for (final region in _regions) {
    if (name.contains(region.name)) return region;
    for (final alias in region.aliases) {
      final found = _cjk.hasMatch(alias)
          ? name.contains(alias)
          : RegExp(
              '(^|[^a-z0-9])${RegExp.escape(alias)}(\$|[^a-z0-9])',
            ).hasMatch(lower);
      if (found) return region;
    }
  }
  return null;
}

class ZolnitNode {
  const ZolnitNode({
    required this.id,
    required this.name,
    required this.title,
    required this.region,
    this.countryCode,
    this.coreProxyName,
    this.rateKnown = true,
    this.rate = 1,
    this.tags = const [],
    this.online,
  });

  factory ZolnitNode.fromJson(Json json) {
    final raw = textOrNull(json['name']) ?? '';
    var title = raw;
    String? code;
    final runes = raw.runes.toList();
    if (runes.length >= 2 && _isIndicator(runes[0]) && _isIndicator(runes[1])) {
      code = String.fromCharCodes([
        runes[0] - 0x1F1E6 + 0x41,
        runes[1] - 0x1F1E6 + 0x41,
      ]);
      title = String.fromCharCodes(
        runes.skip(2),
      ).replaceFirst(RegExp(r'^[\s·|\-_/]+'), '').trim();
    }
    final match = code == null
        ? _matchRegion(raw)
        : _regions.where((region) => region.code == code).firstOrNull;
    final fallback = raw
        .split(RegExp(r'\s*[·|\-_/]\s*|\s+'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => raw);
    final id = json['id'];
    return ZolnitNode(
      id: id is int || id is String ? '$id' : raw,
      name: raw,
      title: title.isEmpty ? raw : title,
      region: match?.name ?? code ?? fallback,
      countryCode: code ?? match?.code,
      rate: decimalOrNull(json['rate']) ?? 1,
      tags: textList(json['tags']),
      online: flagOrNull(json['is_online']),
    );
  }

  final String id;
  final String name;
  final String? coreProxyName;
  String get proxyName => coreProxyName ?? name;
  final bool rateKnown;
  final String title;
  final String region;
  final String? countryCode;
  final double rate;
  final List<String> tags;
  final bool? online;

  String? get flag => countryCode == null ? null : flagEmoji(countryCode!);

  /// 1, 0.5 or 1.25, without a trailing ".0".
  String get rateText {
    final text = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2);
    return text.contains('.') ? text.replaceFirst(RegExp(r'0+$'), '') : text;
  }
}

const _periodMonths = <String, int>{
  'month_price': 1,
  'quarter_price': 3,
  'half_year_price': 6,
  'year_price': 12,
  'two_year_price': 24,
  'three_year_price': 36,
};

const _priceKeys = [
  'month_price',
  'quarter_price',
  'half_year_price',
  'year_price',
  'two_year_price',
  'three_year_price',
  'onetime_price',
  'reset_price',
];

/// Plan quotas are entered in GB, but older panels stored KB or bytes.
double? _planGigabytes(double? value) {
  if (value == null || value <= 0) return null;
  if (value < 1e6) return value;
  if (value < 1e9) return value / 1048576;
  return value / 1073741824;
}

Map<String, String> _planBlocks(String html) {
  final blocks = <String, String>{};
  for (final match in _classed.allMatches(html)) {
    for (final token in match.group(2)!.split(RegExp(r'\s+'))) {
      if (token.startsWith('zn-plan-')) {
        blocks.putIfAbsent(token, () => match.group(3)!);
      }
    }
  }
  return blocks;
}

String? _joined(Iterable<String> lines, [String separator = ' ']) {
  final text = lines.join(separator);
  return text.isEmpty ? null : text;
}

class ZolnitPlan {
  const ZolnitPlan({
    required this.id,
    required this.name,
    this.contentLines = const [],
    this.badge,
    this.tagline,
    this.allowance,
    this.features = const [],
    this.note,
    this.transferGb,
    this.deviceLimit,
    this.speedLimitMbps,
    this.prices = const {},
  });

  factory ZolnitPlan.fromJson(Json json) {
    final prices = <String, int>{};
    for (final key in _priceKeys) {
      final value = wholeOrNull(json[key]);
      if (value != null && value >= 0) prices[key] = value;
    }
    final content = json['content'];
    final blocks = content is String
        ? _planBlocks(content)
        : const <String, String>{};
    String? first(String key) =>
        plainLines(blocks[key], maxLines: 1, maxLength: 80).firstOrNull;
    final metric = plainLines(
      blocks['zn-plan-metric']?.replaceAllMapped(
        _inlineEdge,
        (match) => '${match[1]} ',
      ),
      maxLines: 2,
    );
    return ZolnitPlan(
      id: wholeOrNull(json['id']),
      name: textOrNull(json['name']) ?? '',
      contentLines: plainLines(content),
      badge: first('zn-plan-badge'),
      tagline: first('zn-plan-scene'),
      allowance: metric.isEmpty
          ? null
          : _joined([...metric, ?first('zn-plan-metric-label')], ' · '),
      features: plainLines(blocks['zn-plan-features'], maxLines: 10),
      note: _joined(
        plainLines(blocks['zn-plan-note'], maxLines: 4, maxLength: 240),
      ),
      transferGb: _planGigabytes(decimalOrNull(json['transfer_enable'])),
      deviceLimit: positiveOrNull(wholeOrNull(json['device_limit'])),
      speedLimitMbps: positiveOrNull(wholeOrNull(json['speed_limit'])),
      prices: Map.unmodifiable(prices),
    );
  }

  final int? id;
  final String name;
  final List<String> contentLines;
  final String? badge;
  final String? tagline;
  final String? allowance;
  final List<String> features;
  final String? note;
  final double? transferGb;
  final int? deviceLimit;
  final int? speedLimitMbps;
  final Map<String, int> prices;

  /// Whole percent saved against paying monthly, or null when not cheaper.
  int? savingPercent(String priceKey) {
    final months = _periodMonths[priceKey];
    final month = prices['month_price'];
    final price = prices[priceKey];
    if (months == null ||
        months == 1 ||
        month == null ||
        month <= 0 ||
        price == null) {
      return null;
    }
    final full = month * months;
    final percent = (full - price) * 100 ~/ full;
    return percent > 0 ? percent : null;
  }
}

class ZolnitNotice {
  const ZolnitNotice({
    required this.id,
    required this.title,
    this.body = '',
    this.tags = const [],
    this.createdAt,
  });

  factory ZolnitNotice.fromJson(Json json) => ZolnitNotice(
    id: '${json['id'] ?? json['title'] ?? ''}',
    title: textOrNull(json['title']) ?? '',
    body: plainLines(json['content'], maxLines: 40, maxLength: 400).join('\n'),
    tags: textList(json['tags']),
    createdAt: secondsToDate(json['created_at']),
  );

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final DateTime? createdAt;
}

class ZolnitUsage {
  const ZolnitUsage({
    this.usedBytes,
    this.totalBytes,
    this.expiresAt,
    this.resetDay,
    this.deviceLimit,
    this.onlineDevices,
    this.planId,
    this.planName,
    this.email,
  });

  factory ZolnitUsage.fromSubscription(Json json) {
    final plan = json['plan'];
    int? count(Object? value) {
      final result = wholeOrNull(value);
      return result != null && result >= 0 ? result : null;
    }

    final uploaded = count(json['u']);
    final downloaded = count(json['d']);
    return ZolnitUsage(
      usedBytes: uploaded == null || downloaded == null
          ? null
          : uploaded + downloaded,
      totalBytes: count(json['transfer_enable']),
      expiresAt: secondsToDate(json['expired_at']),
      resetDay: wholeOrNull(json['reset_day']),
      deviceLimit:
          positiveOrNull(wholeOrNull(json['device_limit'])) ??
          (plan is Map
              ? positiveOrNull(wholeOrNull(plan['device_limit']))
              : null),
      onlineDevices: wholeOrNull(json['alive_ip']),
      planId: wholeOrNull(json['plan_id']),
      planName: plan is Map ? textOrNull(plan['name']) : null,
      email: textOrNull(json['email']),
    );
  }

  final int? usedBytes;
  final int? totalBytes;
  final DateTime? expiresAt;
  final int? resetDay;
  final int? deviceLimit;
  final int? onlineDevices;
  final int? planId;
  final String? planName;
  final String? email;

  int? get remainingBytes => switch ((totalBytes, usedBytes)) {
    (final int total, final int used) => total > used ? total - used : 0,
    _ => null,
  };

  double? get fraction => switch ((totalBytes, usedBytes)) {
    (final int total, final int used) =>
      total <= 0 ? 0 : (used / total).clamp(0.0, 1.0),
    _ => null,
  };

  bool get hasPlan => planId != null;

  /// Whole days until expiry rounded up, or null for a plan without an end.
  int? daysLeftAt(DateTime now) {
    final remaining = expiresAt?.difference(now.toUtc());
    if (remaining == null) return null;
    return remaining.isNegative ? 0 : (remaining.inSeconds / 86400).ceil();
  }
}

class ZolnitBytes {
  const ZolnitBytes(this.value, this.unit);

  final String value;
  final String unit;

  @override
  String toString() => unit.isEmpty ? value : '$value $unit';
}

ZolnitBytes formatBytes(num? bytes) {
  if (bytes == null || !bytes.isFinite || bytes < 0) {
    return const ZolnitBytes('—', '');
  }
  final size = bytes.toDouble();
  const tb = 1099511627776.0;
  const gb = 1073741824.0;
  const mb = 1048576.0;
  if (size >= tb) return ZolnitBytes((size / tb).toStringAsFixed(2), 'TB');
  if (size >= gb || size == 0) {
    return ZolnitBytes((size / gb).toStringAsFixed(2), 'GB');
  }
  return ZolnitBytes((size / mb).toStringAsFixed(2), 'MB');
}
