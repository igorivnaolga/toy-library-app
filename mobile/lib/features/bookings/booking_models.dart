/// Booking row from `GET /api/v1/bookings/me` and `POST /api/v1/bookings`.
class BookingItem {
  const BookingItem({
    required this.bookingId,
    required this.userId,
    required this.toyId,
    required this.status,
    required this.createdAt,
    this.toyName,
    this.photoFile,
    this.pickupDate,
    this.pickupLabel,
    this.cancelledAt,
    this.memberName,
    this.memberEmail,
    this.rentalPriceCents,
    this.memberBalanceDueCents = 0,
    this.memberCreditBalanceCents = 0,
  });

  final String bookingId;
  final String userId;
  final String toyId;
  final String? toyName;
  final String? photoFile;
  final String status;
  final DateTime? pickupDate;
  final String? pickupLabel;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final String? memberName;
  final String? memberEmail;
  final int? rentalPriceCents;
  final int memberBalanceDueCents;
  final int memberCreditBalanceCents;

  bool get isPending => status.toLowerCase() == "pending";
  bool get isCancelled => status.toLowerCase() == "cancelled";
  bool get isCompleted => status.toLowerCase() == "completed";

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      bookingId: json["booking_id"]?.toString() ?? "",
      userId: json["user_id"]?.toString() ?? "",
      toyId: json["toy_id"]?.toString() ?? "",
      toyName: json["toy_name"]?.toString(),
      photoFile: json["photo_file"]?.toString(),
      status: json["status"]?.toString() ?? "unknown",
      pickupDate: parseApiDate(json["pickup_date"]),
      pickupLabel: json["pickup_label"]?.toString(),
      createdAt: DateTime.parse(json["created_at"] as String),
      cancelledAt: json["cancelled_at"] == null
          ? null
          : DateTime.tryParse(json["cancelled_at"].toString()),
      memberName: json["member_name"]?.toString(),
      memberEmail: json["member_email"]?.toString(),
      rentalPriceCents: (json["rental_price_cents"] as num?)?.toInt(),
      memberBalanceDueCents:
          (json["member_balance_due_cents"] as num?)?.toInt() ?? 0,
      memberCreditBalanceCents:
          (json["member_credit_balance_cents"] as num?)?.toInt() ?? 0,
    );
  }

  String? get rentalPriceLabel => formatRentalPriceCents(rentalPriceCents);

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

  /// Subtitle when pickup date is shown in the section header.
  String get groupedListSubtitle {
    if (!isPending) {
      return statusLabel;
    }
    final price = rentalPriceLabel;
    if (price != null) {
      return "Hire charge $price";
    }
    return "";
  }

  String get memberLabel {
    if (memberName != null && memberName!.isNotEmpty) {
      return memberName!;
    }
    if (memberEmail != null && memberEmail!.isNotEmpty) {
      return memberEmail!;
    }
    return "Member";
  }

  /// Subtitle for volunteer desk booking rows.
  String get deskSubtitle => memberLabel;
}

/// Upcoming (pending) vs past (completed/cancelled) for the bookings screen.
class BookingSections {
  const BookingSections({
    required this.upcomingByPickupDate,
    required this.past,
  });

  final List<BookingPickupDateGroup> upcomingByPickupDate;
  final List<BookingItem> past;
}

class BookingPickupDateGroup {
  const BookingPickupDateGroup({
    required this.pickupDate,
    required this.pickupLabel,
    required this.bookings,
  });

  final DateTime pickupDate;
  final String? pickupLabel;
  final List<BookingItem> bookings;

  int? get totalRentalCents => totalRentalCentsForBookings(bookings);

  int get unpricedBookingCount => unpricedBookingCountForBookings(bookings);
}

int? totalRentalCentsForBookings(List<BookingItem> bookings) {
  var total = 0;
  var hasPrice = false;
  for (final booking in bookings) {
    final cents = booking.rentalPriceCents;
    if (cents == null) continue;
    total += cents;
    hasPrice = true;
  }
  return hasPrice ? total : null;
}

int unpricedBookingCountForBookings(List<BookingItem> bookings) =>
    bookings.where((booking) => booking.rentalPriceCents == null).length;

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
  sortBookingsList(past);
  return BookingSections(
    upcomingByPickupDate: groupBookingsByPickupDate(upcoming),
    past: past,
  );
}

List<BookingPickupDateGroup> groupBookingsByPickupDate(List<BookingItem> items) {
  final byDay = <DateTime, List<BookingItem>>{};
  final labels = <DateTime, String?>{};

  for (final item in items) {
    final pickup = item.pickupDate;
    if (pickup == null) continue;
    final day = calendarDay(pickup);
    byDay.putIfAbsent(day, () => []).add(item);
    labels.putIfAbsent(day, () => item.pickupLabel);
  }

  final groups = byDay.entries
      .map(
        (entry) => BookingPickupDateGroup(
          pickupDate: entry.key,
          pickupLabel: labels[entry.key],
          bookings: List<BookingItem>.from(entry.value)
            ..sort(
              (a, b) => (a.toyName ?? a.toyId)
                  .toLowerCase()
                  .compareTo((b.toyName ?? b.toyId).toLowerCase()),
            ),
        ),
      )
      .toList();

  groups.sort((a, b) => a.pickupDate.compareTo(b.pickupDate));
  return groups;
}

String formatDisplayDate(DateTime date) {
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return "${date.day} ${months[date.month - 1]} ${date.year}";
}

String? formatRentalPriceCents(int? cents) {
  if (cents == null) return null;
  return "\$${(cents / 100).toStringAsFixed(2)}";
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

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

List<BookingItem> deskTodayReservations(List<BookingItem> items) {
  final today = calendarDay(DateTime.now());
  return items
      .where(
        (item) =>
            item.pickupDate != null &&
            isSameCalendarDay(item.pickupDate!, today),
      )
      .toList();
}

List<BookingItem> deskEarlierReady(List<BookingItem> items) {
  final today = calendarDay(DateTime.now());
  return items
      .where(
        (item) =>
            item.pickupDate != null && item.pickupDate!.isBefore(today),
      )
      .toList();
}
