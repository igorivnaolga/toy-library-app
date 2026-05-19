/// Booking row from `GET /api/v1/bookings/me` and `POST /api/v1/bookings`.
class BookingItem {
  const BookingItem({
    required this.bookingId,
    required this.userId,
    required this.toyId,
    required this.status,
    required this.createdAt,
    this.toyName,
    this.cancelledAt,
  });

  final String bookingId;
  final String userId;
  final String toyId;
  final String? toyName;
  final String status;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  bool get isPending => status.toLowerCase() == "pending";
  bool get isCancelled => status.toLowerCase() == "cancelled";
  bool get isCompleted => status.toLowerCase() == "completed";

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      bookingId: json["booking_id"]?.toString() ?? "",
      userId: json["user_id"]?.toString() ?? "",
      toyId: json["toy_id"]?.toString() ?? "",
      toyName: json["toy_name"]?.toString(),
      status: json["status"]?.toString() ?? "unknown",
      createdAt: DateTime.parse(json["created_at"] as String),
      cancelledAt: json["cancelled_at"] == null
          ? null
          : DateTime.tryParse(json["cancelled_at"].toString()),
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case "pending":
        return "Pending";
      case "cancelled":
        return "Cancelled";
      case "completed":
        return "Completed";
      default:
        return status;
    }
  }
}

int _bookingStatusRank(String status) {
  switch (status.toLowerCase()) {
    case "pending":
      return 0;
    case "completed":
      return 1;
    case "cancelled":
      return 2;
    default:
      return 3;
  }
}

/// Pending first, then completed, cancelled last; newest first within each group.
void sortBookingsList(List<BookingItem> items) {
  items.sort((a, b) {
    final statusOrder =
        _bookingStatusRank(a.status).compareTo(_bookingStatusRank(b.status));
    if (statusOrder != 0) {
      return statusOrder;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
}
