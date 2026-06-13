import "../bookings/booking_models.dart";

/// Payment row from `/api/v1/payments/*`.
class PaymentItem {
  const PaymentItem({
    required this.paymentId,
    required this.paymentType,
    required this.amountCents,
    required this.status,
    this.description,
    this.paidAt,
    this.createdAt,
  });

  final String paymentId;
  final String paymentType;
  final int amountCents;
  final String status;
  final String? description;
  final DateTime? paidAt;
  final DateTime? createdAt;

  bool get isPending => status == "pending";
  bool get isCreditGrant =>
      paymentType == "top_up" || paymentType == "volunteer_credit";
  bool get isPaid =>
      status == "paid_cash" ||
      status == "paid_eftpos" ||
      status == "paid_bank" ||
      status == "paid_credit" ||
      status == "granted";

  String get amountLabel => formatRentalPriceCents(amountCents) ?? "";

  String get displayAmountLabel =>
      isCreditGrant && !isPending ? "+$amountLabel" : amountLabel;

  String get typeLabel {
    switch (paymentType) {
      case "membership":
        return "Membership";
      case "bond":
        return "Bond";
      case "rental":
        return "Rental";
      case "top_up":
        return "Top-up";
      case "volunteer_credit":
        return "Volunteer credit";
      default:
        return paymentType;
    }
  }

  String get statusLabel {
    switch (status) {
      case "pending":
        return "Pending";
      case "paid_cash":
        return "Paid (cash)";
      case "paid_eftpos":
        return "Paid (EFTPOS)";
      case "paid_bank":
        return "Paid (bank transfer)";
      case "paid_credit":
        return "Paid (account credit)";
      case "granted":
        return "Credit added";
      case "refunded":
        return "Refunded";
      case "cancelled":
        return "Cancelled";
      default:
        return status;
    }
  }

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      paymentId: json["payment_id"]?.toString() ?? "",
      paymentType: json["payment_type"]?.toString() ?? "",
      amountCents: (json["amount_cents"] as num?)?.toInt() ?? 0,
      status: json["status"]?.toString() ?? "pending",
      description: json["description"]?.toString(),
      paidAt: json["paid_at"] == null
          ? null
          : DateTime.tryParse(json["paid_at"].toString()),
      createdAt: json["created_at"] == null
          ? null
          : DateTime.tryParse(json["created_at"].toString()),
    );
  }
}

List<PaymentItem> parsePaymentList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(PaymentItem.fromJson)
      .toList();
}

String formatDueCents(int cents) => formatRentalPriceCents(cents) ?? "\$0.00";

/// Credit from account balance that can cover this checkout total.
int checkoutCreditAppliedCents(int creditCents, int checkoutTotalCents) {
  if (creditCents <= 0 || checkoutTotalCents <= 0) return 0;
  return creditCents < checkoutTotalCents ? creditCents : checkoutTotalCents;
}

int checkoutDueAfterCreditCents(int creditCents, int checkoutTotalCents) =>
    checkoutTotalCents -
    checkoutCreditAppliedCents(creditCents, checkoutTotalCents);

/// Account balance from `GET /api/v1/payments/users/{id}/balance-summary`.
class MemberBalanceSummary {
  const MemberBalanceSummary({
    required this.balanceDueCents,
    required this.creditBalanceCents,
  });

  final int balanceDueCents;
  final int creditBalanceCents;

  factory MemberBalanceSummary.fromJson(Map<String, dynamic> json) {
    return MemberBalanceSummary(
      balanceDueCents: (json["balance_due_cents"] as num?)?.toInt() ?? 0,
      creditBalanceCents: (json["credit_balance_cents"] as num?)?.toInt() ?? 0,
    );
  }
}

/// Parses a dollar amount field (e.g. "12.50" or "\$12") to cents.
int? parseDollarAmountToCents(String raw) {
  final normalized = raw.replaceAll("\$", "").trim();
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) return null;
  return (parsed * 100).round();
}

class PaymentDateGroup {
  const PaymentDateGroup({
    required this.date,
    required this.payments,
  });

  final DateTime date;
  final List<PaymentItem> payments;
}

DateTime? _paymentSortStamp(PaymentItem payment) =>
    payment.paidAt ?? payment.createdAt;

DateTime _paymentDayKey(DateTime stamp) =>
    DateTime(stamp.year, stamp.month, stamp.day);

List<PaymentDateGroup> groupPaymentsByDate(List<PaymentItem> payments) {
  final buckets = <DateTime, List<PaymentItem>>{};
  for (final payment in payments) {
    final stamp = _paymentSortStamp(payment);
    if (stamp == null) continue;
    final day = _paymentDayKey(stamp);
    buckets.putIfAbsent(day, () => []).add(payment);
  }

  for (final items in buckets.values) {
    items.sort((a, b) {
      if (a.isPending != b.isPending) {
        return a.isPending ? -1 : 1;
      }
      final aStamp = _paymentSortStamp(a);
      final bStamp = _paymentSortStamp(b);
      if (aStamp == null && bStamp == null) return 0;
      if (aStamp == null) return 1;
      if (bStamp == null) return -1;
      return bStamp.compareTo(aStamp);
    });
  }

  final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      PaymentDateGroup(date: day, payments: buckets[day]!),
  ];
}
