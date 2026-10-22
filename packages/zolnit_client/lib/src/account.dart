import 'api.dart' show ClientFailure, Json, XboardClient;
import 'parse.dart';

DateTime? _timestamp(Object? value) {
  if (value is String && wholeOrNull(value) == null) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed.toUtc();
  }
  return secondsToDate(value);
}

class ZolnitAccountInfo {
  const ZolnitAccountInfo({
    required this.email,
    this.balanceCents = 0,
    this.commissionBalanceCents = 0,
    this.planId,
    this.expiresAt,
    this.transferEnableBytes = 0,
    this.createdAt,
    this.lastLoginAt,
    this.banned = false,
    this.remindExpire = false,
    this.remindTraffic = false,
    this.discountPercent,
    this.commissionRatePercent,
    this.telegramLinked = false,
    this.avatarUrl,
  });

  final String email;
  final int balanceCents;
  final int commissionBalanceCents;
  final int? planId;
  final DateTime? expiresAt;
  final int transferEnableBytes;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool banned;
  final bool remindExpire;
  final bool remindTraffic;
  final int? discountPercent;
  final double? commissionRatePercent;
  final bool telegramLinked;
  final Uri? avatarUrl;

  static ZolnitAccountInfo? fromJson(Json json) {
    final email = textOrNull(json['email']);
    if (email == null) return null;
    final avatar = Uri.tryParse(textOrNull(json['avatar_url']) ?? '');
    return ZolnitAccountInfo(
      email: email,
      balanceCents: nonNegativeInt(json['balance']),
      commissionBalanceCents: nonNegativeInt(json['commission_balance']),
      planId: positiveOrNull(wholeOrNull(json['plan_id'])),
      expiresAt: secondsToDate(json['expired_at']),
      transferEnableBytes: nonNegativeInt(json['transfer_enable']),
      createdAt: secondsToDate(json['created_at']),
      lastLoginAt: secondsToDate(json['last_login_at']),
      banned: flagOrNull(json['banned']) ?? false,
      remindExpire: flagOrNull(json['remind_expire']) ?? false,
      remindTraffic: flagOrNull(json['remind_traffic']) ?? false,
      discountPercent: wholeOrNull(json['discount']),
      commissionRatePercent: decimalOrNull(json['commission_rate']),
      telegramLinked: (wholeOrNull(json['telegram_id']) ?? 0) > 0,
      avatarUrl:
          avatar != null && avatar.scheme == 'https' && avatar.host.isNotEmpty
          ? avatar
          : null,
    );
  }

  @override
  String toString() => 'ZolnitAccountInfo($email)';
}

class ZolnitDevice {
  const ZolnitDevice({
    required this.id,
    this.label,
    this.ip,
    this.lastUsedAt,
    this.createdAt,
  });

  final String id;
  final String? label;
  final String? ip;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  static ZolnitDevice? fromJson(Json json) {
    final raw = json['id'];
    final id = raw is int ? (raw > 0 ? '$raw' : null) : textOrNull(raw);
    if (id == null) return null;
    return ZolnitDevice(
      id: id,
      label: textOrNull(json['name']),
      ip: textOrNull(json['ip']),
      lastUsedAt: _timestamp(json['last_used_at']),
      createdAt: _timestamp(json['created_at']),
    );
  }

  @override
  String toString() => 'ZolnitDevice(${label ?? 'unnamed'})';
}

class ZolnitAccountClient {
  const ZolnitAccountClient(this.api);

  final XboardClient api;

  Future<ZolnitAccountInfo> info() async {
    final value = await api.account();
    final info = value is Json ? ZolnitAccountInfo.fromJson(value) : null;
    if (info == null) throw const ClientFailure('invalid_response');
    return info;
  }

  Future<List<ZolnitDevice>> devices() async {
    final value = await api.activeSessions();
    if (value is! List) throw const ClientFailure('invalid_response');
    return [for (final entry in jsonList(value)) ?ZolnitDevice.fromJson(entry)];
  }

  Future<void> removeDevice(String id) async {
    if (id.trim().isEmpty) throw const ClientFailure('invalid_device');
    if (await api.removeActiveSession(id) != true) {
      throw const ClientFailure('device_failed');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (oldPassword.isEmpty ||
        newPassword.runes.length < 8 ||
        newPassword == oldPassword) {
      throw const ClientFailure('invalid_password');
    }
    final done = await api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (done != true) throw const ClientFailure('password_failed');
  }

  Future<void> setReminders({bool? expiry, bool? traffic}) async {
    if (expiry == null && traffic == null) {
      throw const ClientFailure('invalid_reminders');
    }
    final done = await api.updateReminders(expiry: expiry, traffic: traffic);
    if (done != true) throw const ClientFailure('reminders_failed');
  }
}
