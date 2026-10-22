import 'api.dart' show ClientFailure, Json, XboardClient;
import 'parse.dart';

class ZolnitInviteCode {
  const ZolnitInviteCode({required this.code, this.pv = 0, this.createdAt});

  static ZolnitInviteCode? fromJson(Json json) {
    final code = textOrNull(json['code']);
    if (code == null) return null;
    return ZolnitInviteCode(
      code: code,
      pv: nonNegativeInt(json['pv']),
      createdAt: secondsToDate(json['created_at']),
    );
  }

  final String code;
  final int pv;
  final DateTime? createdAt;
}

class ZolnitInviteStats {
  const ZolnitInviteStats({
    required this.registeredCount,
    required this.confirmedCommissionCents,
    required this.pendingCommissionCents,
    required this.commissionRatePercent,
    required this.availableCommissionCents,
  });

  static ZolnitInviteStats? fromList(Object? value) {
    if (value is! List || value.length != 5) return null;
    final numbers = [for (final entry in value) wholeOrNull(entry)];
    if (numbers.contains(null)) return null;
    return ZolnitInviteStats(
      registeredCount: numbers[0]!,
      confirmedCommissionCents: numbers[1]!,
      pendingCommissionCents: numbers[2]!,
      commissionRatePercent: numbers[3]!,
      availableCommissionCents: numbers[4]!,
    );
  }

  final int registeredCount;
  final int confirmedCommissionCents;
  final int pendingCommissionCents;
  final int commissionRatePercent;
  final int availableCommissionCents;
}

class ZolnitInvite {
  const ZolnitInvite({required this.codes, this.stats});

  factory ZolnitInvite.fromJson(Json json) {
    final codes = json['codes'];
    if (codes is! List) throw const ClientFailure('invalid_response');
    return ZolnitInvite(
      codes: List.unmodifiable([
        for (final entry in jsonList(codes)) ?ZolnitInviteCode.fromJson(entry),
      ]),
      stats: ZolnitInviteStats.fromList(json['stat']),
    );
  }

  final List<ZolnitInviteCode> codes;
  final ZolnitInviteStats? stats;
}

class ZolnitCommissionEntry {
  const ZolnitCommissionEntry({
    required this.id,
    required this.orderAmountCents,
    required this.commissionCents,
    this.tradeNo,
    this.createdAt,
  });

  static ZolnitCommissionEntry? fromJson(Json json) {
    final id = positiveOrNull(wholeOrNull(json['id']));
    if (id == null) return null;
    return ZolnitCommissionEntry(
      id: id,
      orderAmountCents: nonNegativeInt(json['order_amount']),
      commissionCents: nonNegativeInt(json['get_amount']),
      tradeNo: textOrNull(json['trade_no']),
      createdAt: secondsToDate(json['created_at']),
    );
  }

  final int id;
  final int orderAmountCents;
  final int commissionCents;
  final String? tradeNo;
  final DateTime? createdAt;
}

class ZolnitCommissionPage {
  const ZolnitCommissionPage({required this.entries, required this.total});

  final List<ZolnitCommissionEntry> entries;
  final int total;
}

class ZolnitInviteClient {
  const ZolnitInviteClient(this.api);

  final XboardClient api;

  Future<ZolnitInvite> overview() async {
    final value = await api.invite();
    if (value is! Json) throw const ClientFailure('invalid_response');
    return ZolnitInvite.fromJson(value);
  }

  Future<void> createCode() async {
    if (await api.createInviteCode() != true) {
      throw const ClientFailure('invite_failed');
    }
  }

  Future<ZolnitCommissionPage> commissions({
    int page = 1,
    int pageSize = 10,
  }) async {
    if (page < 1 || pageSize < 10 || pageSize > 100) {
      throw const ClientFailure('invalid_page');
    }
    final value = await api.inviteDetails(page: page, pageSize: pageSize);
    final data = value['data'];
    if (data is! List) throw const ClientFailure('invalid_response');
    final total = wholeOrNull(value['total']);
    if (total == null || total < 0) {
      throw const ClientFailure('invalid_response');
    }
    return ZolnitCommissionPage(
      entries: List.unmodifiable([
        for (final json in jsonList(data))
          ?ZolnitCommissionEntry.fromJson(json),
      ]),
      total: total,
    );
  }
}

final _inviteCode = RegExp(r'^[A-Za-z0-9]{4,32}$');

Uri zolnitInviteLink(Uri origin, String code) {
  if (origin.scheme != 'https' ||
      origin.host.isEmpty ||
      origin.userInfo.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      !{'', '/'}.contains(origin.path)) {
    throw const ClientFailure('invalid_origin');
  }
  if (!_inviteCode.hasMatch(code)) {
    throw const ClientFailure('invalid_invite_code');
  }
  return Uri(
    scheme: 'https',
    host: origin.host,
    port: origin.hasPort ? origin.port : null,
    path: '/',
    fragment: '/register?code=$code',
  );
}
