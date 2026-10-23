import 'api.dart' show ClientFailure, Json, XboardClient;
import 'parse.dart';

class ZolnitTrafficDay {
  const ZolnitTrafficDay({
    required this.day,
    required this.uploadBytes,
    required this.downloadBytes,
    this.rate = 1,
  });

  final DateTime day;
  final int uploadBytes;
  final int downloadBytes;
  final double rate;

  int get totalBytes => uploadBytes + downloadBytes;

  static ZolnitTrafficDay? fromJson(Json json) {
    final day = secondsToDate(json['record_at']);
    if (day == null) return null;
    final rate = decimalOrNull(json['server_rate']);
    return ZolnitTrafficDay(
      day: day,
      uploadBytes: nonNegativeInt(json['u']),
      downloadBytes: nonNegativeInt(json['d']),
      rate: rate != null && rate > 0 ? rate : 1,
    );
  }
}

class ZolnitTrafficClient {
  const ZolnitTrafficClient(this.api);

  final XboardClient api;

  Future<List<ZolnitTrafficDay>> log() async {
    final value = await api.traffic();
    if (value is! List) throw const ClientFailure('invalid_response');
    return [
      for (final entry in jsonList(value)) ?ZolnitTrafficDay.fromJson(entry),
    ]..sort((a, b) => b.day.compareTo(a.day));
  }
}
