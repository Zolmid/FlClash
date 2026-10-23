import 'api.dart' show ClientFailure, Json, XboardClient;
import 'parse.dart';

enum ZolnitOrderStatus {
  pending(0),
  processing(1),
  cancelled(2),
  completed(3),
  discounted(4),
  unknown(-1);

  const ZolnitOrderStatus(this.code);

  final int code;

  static ZolnitOrderStatus fromCode(int? code) => values.firstWhere(
    (status) => status.code == code && status != unknown,
    orElse: () => unknown,
  );
}

const _periodMonths = <String, int>{
  'month_price': 1,
  'monthly': 1,
  'quarter_price': 3,
  'quarterly': 3,
  'half_year_price': 6,
  'half_yearly': 6,
  'year_price': 12,
  'yearly': 12,
  'two_year_price': 24,
  'two_yearly': 24,
  'three_year_price': 36,
  'three_yearly': 36,
};

class ZolnitOrder {
  const ZolnitOrder({
    required this.tradeNo,
    required this.status,
    this.planId,
    this.planName,
    this.period,
    this.type,
    this.totalCents = 0,
    this.balanceCents = 0,
    this.discountCents = 0,
    this.handlingCents = 0,
    this.surplusCents = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String tradeNo;
  final ZolnitOrderStatus status;
  final int? planId;
  final String? planName;
  final String? period;
  final int? type;
  final int totalCents;
  final int balanceCents;
  final int discountCents;
  final int handlingCents;
  final int surplusCents;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPayable => status == ZolnitOrderStatus.pending;
  bool get isCompleted => status == ZolnitOrderStatus.completed;
  int? get months => _periodMonths[period];

  static ZolnitOrder? fromJson(Json json) {
    final tradeNo = textOrNull(json['trade_no']);
    if (tradeNo == null) return null;
    final plan = jsonOrNull(json['plan']);
    return ZolnitOrder(
      tradeNo: tradeNo,
      status: ZolnitOrderStatus.fromCode(wholeOrNull(json['status'])),
      planId: positiveOrNull(
        wholeOrNull(json['plan_id']) ?? wholeOrNull(plan?['id']),
      ),
      planName: textOrNull(plan?['name']),
      period: textOrNull(json['period']),
      type: wholeOrNull(json['type']),
      totalCents: nonNegativeInt(json['total_amount']),
      balanceCents: nonNegativeInt(json['balance_amount']),
      discountCents: nonNegativeInt(json['discount_amount']),
      handlingCents: nonNegativeInt(json['handling_amount']),
      surplusCents: nonNegativeInt(json['surplus_amount']),
      createdAt: secondsToDate(json['created_at']),
      updatedAt: secondsToDate(json['updated_at']),
    );
  }

  @override
  String toString() => 'ZolnitOrder($tradeNo, ${status.name})';
}

class ZolnitPaymentMethod {
  const ZolnitPaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    this.iconUrl,
    this.handlingFeeFixedCents = 0,
    this.handlingFeePercent = 0,
  });

  final int id;
  final String name;
  final String payment;
  final Uri? iconUrl;
  final int handlingFeeFixedCents;
  final double handlingFeePercent;

  static ZolnitPaymentMethod? fromJson(Json json) {
    final id = wholeOrNull(json['id']);
    if (id == null || id <= 0) return null;
    final icon = Uri.tryParse(textOrNull(json['icon']) ?? '');
    final percent = decimalOrNull(json['handling_fee_percent']) ?? 0;
    return ZolnitPaymentMethod(
      id: id,
      name: textOrNull(json['name']) ?? '',
      payment: textOrNull(json['payment']) ?? '',
      iconUrl: icon != null && icon.scheme == 'https' && icon.host.isNotEmpty
          ? icon
          : null,
      handlingFeeFixedCents: nonNegativeInt(json['handling_fee_fixed']),
      handlingFeePercent: percent < 0 ? 0 : percent,
    );
  }
}

final _tradeNo = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

class ZolnitOrdersClient {
  const ZolnitOrdersClient(this.api);

  final XboardClient api;

  Future<List<ZolnitOrder>> orders() async {
    final value = await api.orders();
    if (value is! List) throw const ClientFailure('invalid_response');
    return [for (final entry in jsonList(value)) ?ZolnitOrder.fromJson(entry)];
  }

  Future<ZolnitOrder> order(String tradeNo) async {
    if (!_tradeNo.hasMatch(tradeNo)) {
      throw const ClientFailure('invalid_trade_no');
    }
    final value = await api.order(tradeNo);
    final order = value is Json ? ZolnitOrder.fromJson(value) : null;
    if (order == null || order.tradeNo != tradeNo) {
      throw const ClientFailure('invalid_response');
    }
    return order;
  }

  Future<List<ZolnitPaymentMethod>> paymentMethods() async {
    final value = await api.paymentMethods();
    if (value is! List) throw const ClientFailure('invalid_response');
    return [
      for (final entry in jsonList(value)) ?ZolnitPaymentMethod.fromJson(entry),
    ];
  }
}
