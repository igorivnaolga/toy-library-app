/// Booking row from `GET /api/v1/bookings/me` and `POST /api/v1/bookings`.
class BookingItem {
  const BookingItem({
    required this.bookingId,
    required this.userId,
    required this.toyId,
    required this.status,
    required this.createdAt,
    this.toyName,
    this.pickupDate,
    this.pickupLabel,
    this.cancelledAt,
  });

  final String bookingId;
  final String userId;
  final String toyId;
  final String? toyName;
  final String status;
  final DateTime? pickupDate;
  final String? pickupLabel;
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
      pickupDate: parseApiDate(json["pickup_date"]),
      pickupLabel: json["pickup_label"]?.toString(),
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

  /// Subtitle for the bookings list row.
  String get listSubtitle {
    if (isPending && pickupLabel != null && pickupLabel!.isNotEmpty) {
      return "Pick up $pickupLabel";
    }
    return statusLabel;
  }
}

/// Upcoming (pending) vs past (completed/cancelled) for the bookings screen.
class BookingSections {
  const BookingSections({
    required this.upcoming,
    required this.past,
  });

  final List<BookingItem> upcoming;
  final List<BookingItem> past;
}

BookingSections groupBookingsBySection(List<BookingItem> items) {
  final upcoming = <BookingItem>[];
  final past = <BookingItem>[];
  for (final item in items) {
    if (item.isPending) {
      upcoming.add(item);
    } else {
      past.add(item);
    }
  }
  return BookingSections(upcoming: upcoming, past: past);
}

/// Wed/Sat pickup option from `GET /api/v1/bookings/pickup-dates`.
class PickupDateOption {
  const PickupDateOption({
    required this.date,
    required this.label,
    required this.weekday,
  });

  final DateTime date;
  final String label;
  final String weekday;

  factory PickupDateOption.fromJson(Map<String, dynamic> json) {
    final rawDate = json["date"]?.toString() ?? "";
    final parsed = parseApiDate(rawDate);
    if (parsed == null) {
      throw FormatException("Invalid pickup date: $rawDate");
    }
    return PickupDateOption(
      date: parsed,
      label: json["label"]?.toString() ?? rawDate,
      weekday: json["weekday"]?.toString() ?? "",
    );
  }

  String get apiDate => formatApiDate(date);
}

DateTime? parseApiDate(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parts = text.split("-");
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatApiDate(DateTime date) {
  final y = date.year.toString().padLeft(4, "0");
  final m = date.month.toString().padLeft(2, "0");
  final d = date.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
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

/// Pending first (soonest pickup), then completed, cancelled last.
void sortBookingsList(List<BookingItem> items) {
  items.sort((a, b) {
    final statusOrder =
        _bookingStatusRank(a.status).compareTo(_bookingStatusRank(b.status));
    if (statusOrder != 0) {
      return statusOrder;
    }
    if (a.isPending && b.isPending) {
      final aPickup = a.pickupDate;
      final bPickup = b.pickupDate;
      if (aPickup != null && bPickup != null) {
        final pickupOrder = aPickup.compareTo(bPickup);
        if (pickupOrder != 0) {
          return pickupOrder;
        }
      }
    }
    return b.createdAt.compareTo(a.createdAt);
  });
}
