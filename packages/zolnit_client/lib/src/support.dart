import 'api.dart' show ClientFailure, Json, XboardClient;
import 'parse.dart';

enum ZolnitTicketLevel {
  low(0),
  medium(1),
  high(2);

  const ZolnitTicketLevel(this.code);

  final int code;

  static ZolnitTicketLevel fromCode(Object? value) {
    final code = wholeOrNull(value);
    for (final level in values) {
      if (level.code == code) return level;
    }
    return medium;
  }
}

class ZolnitTicket {
  const ZolnitTicket({
    required this.id,
    required this.subject,
    required this.level,
    required this.closed,
    this.replyStatus,
    this.createdAt,
    this.updatedAt,
  });

  static ZolnitTicket? fromJson(Json json) {
    final id = positiveOrNull(wholeOrNull(json['id']));
    if (id == null) return null;
    return ZolnitTicket(
      id: id,
      subject: textOrNull(json['subject']) ?? '',
      level: ZolnitTicketLevel.fromCode(json['level']),
      closed: wholeOrNull(json['status']) == 1,
      replyStatus: wholeOrNull(json['reply_status']),
      createdAt: secondsToDate(json['created_at']),
      updatedAt: secondsToDate(json['updated_at']),
    );
  }

  final int id;
  final String subject;
  final ZolnitTicketLevel level;
  final bool closed;
  final int? replyStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canReply => !closed;

  bool? get staffReplied => switch (replyStatus) {
    1 => true,
    0 => false,
    _ => null,
  };
}

class ZolnitTicketMessage {
  const ZolnitTicketMessage({
    required this.text,
    required this.fromUser,
    this.id,
    this.createdAt,
  });

  static ZolnitTicketMessage? fromJson(Json json) {
    final text = textOrNull(json['message']);
    if (text == null) return null;
    return ZolnitTicketMessage(
      id: positiveOrNull(wholeOrNull(json['id'])),
      text: text,
      fromUser: flagOrNull(json['is_me']) ?? false,
      createdAt: secondsToDate(json['created_at']),
    );
  }

  final int? id;
  final String text;
  final bool fromUser;
  final DateTime? createdAt;
}

class ZolnitTicketThread {
  const ZolnitTicketThread({required this.ticket, required this.messages});

  static ZolnitTicketThread fromJson(Json json) {
    final ticket = ZolnitTicket.fromJson(json);
    final raw = json['message'];
    if (ticket == null || raw is! List) {
      throw const ClientFailure('invalid_response');
    }
    final indexed = <(int, ZolnitTicketMessage)>[
      for (final (index, entry) in raw.indexed)
        if (jsonOrNull(entry) case final Json map)
          if (ZolnitTicketMessage.fromJson(map) case final message?)
            (index, message),
    ];
    indexed.sort((a, b) {
      final byTime = _compareTime(a.$2.createdAt, b.$2.createdAt);
      if (byTime != 0) return byTime;
      final byId = (a.$2.id ?? 0).compareTo(b.$2.id ?? 0);
      return byId != 0 ? byId : a.$1.compareTo(b.$1);
    });
    return ZolnitTicketThread(
      ticket: ticket,
      messages: List.unmodifiable([for (final entry in indexed) entry.$2]),
    );
  }

  static int _compareTime(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == b ? 0 : (a == null ? -1 : 1);
    }
    return a.compareTo(b);
  }

  final ZolnitTicket ticket;
  final List<ZolnitTicketMessage> messages;
}

class ZolnitSupportClient {
  const ZolnitSupportClient(this.api);

  final XboardClient api;

  Future<List<ZolnitTicket>> tickets() async {
    final value = await api.tickets();
    if (value is! List) throw const ClientFailure('invalid_response');
    return List.unmodifiable([
      for (final json in jsonList(value)) ?ZolnitTicket.fromJson(json),
    ]);
  }

  Future<ZolnitTicketThread> thread(int id) async {
    _requireId(id);
    final value = await api.tickets(id: id);
    if (value is! Json) throw const ClientFailure('invalid_response');
    return ZolnitTicketThread.fromJson(value);
  }

  Future<void> create({
    required String subject,
    required String message,
    ZolnitTicketLevel level = ZolnitTicketLevel.low,
  }) async {
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (cleanSubject.isEmpty || cleanMessage.isEmpty) {
      throw const ClientFailure('invalid_ticket');
    }
    _expectTrue(
      await api.createTicket(
        subject: cleanSubject,
        message: cleanMessage,
        level: level.code,
      ),
    );
  }

  Future<void> reply(int id, String message) async {
    _requireId(id);
    final clean = message.trim();
    if (clean.isEmpty) throw const ClientFailure('invalid_ticket');
    _expectTrue(await api.replyTicket(id, clean));
  }

  Future<void> close(int id) async {
    _requireId(id);
    _expectTrue(await api.closeTicket(id));
  }

  static void _requireId(int id) {
    if (id <= 0) throw const ClientFailure('invalid_ticket');
  }

  static void _expectTrue(Object? value) {
    if (value != true) throw const ClientFailure('ticket_failed');
  }
}
