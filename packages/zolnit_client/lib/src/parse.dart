import 'api.dart' show Json;

String? textOrNull(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int? wholeOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) {
    return value.isFinite && value == value.truncateToDouble()
        ? value.toInt()
        : null;
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? decimalOrNull(Object? value) {
  final number = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim())
      : null;
  return number?.isFinite == true ? number : null;
}

bool? flagOrNull(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' => true,
      '0' || 'false' => false,
      _ => null,
    };
  }
  return null;
}

List<String> textList(Object? value) {
  if (value is! List) return const [];
  return [for (final entry in value) ?textOrNull(entry)];
}

DateTime? secondsToDate(Object? value) {
  final seconds = wholeOrNull(value);
  if (seconds == null || seconds <= 0 || seconds > 253402300799) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

int? positiveOrNull(int? value) => value != null && value > 0 ? value : null;

int nonNegativeInt(Object? value) {
  final number = wholeOrNull(value) ?? 0;
  return number < 0 ? 0 : number;
}

Json? jsonOrNull(Object? value) => value is Json ? value : null;

List<Json> jsonList(Object? value) =>
    value is List ? [for (final entry in value) ?jsonOrNull(entry)] : const [];
