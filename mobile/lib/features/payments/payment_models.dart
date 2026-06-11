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
  bool get isPaid =>
      status == "paid_cash" ||
      status == "paid_eftpos" ||
      status == "paid_bank";

  String get amountLabel => formatRentalPriceCents(amountCents) ?? "";

  String get typeLabel {
    switch (paymentType) {
      case "membership":
        return "Membership";
      case "bond":
        return "Bond";
      case "rental":
        return "Rental";
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
