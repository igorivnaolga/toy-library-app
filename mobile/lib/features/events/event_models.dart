import "../../core/user_friendly_error.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_session_models.dart";

class EventSlotItem {
  const EventSlotItem({
    required this.slotId,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.audience,
    required this.bookedCount,
    required this.spotsLeft,
    required this.isFull,
    this.userBooked = false,
    this.bookings = const [],
  });

  final String slotId;
  final String startTime;
  final String endTime;
  final int capacity;
  final String audience;
  final int bookedCount;
  final int spotsLeft;
  final bool isFull;
  final bool userBooked;
  final List<EventBookingUser> bookings;

  factory EventSlotItem.fromJson(Map<String, dynamic> json) {
    final rawBookings = json["bookings"];
    return EventSlotItem(
      slotId: json["slot_id"]?.toString() ?? "",
      startTime: json["start_time"]?.toString() ?? "",
      endTime: json["end_time"]?.toString() ?? "",
      capacity: _asInt(json["capacity"]),
      audience: json["audience"]?.toString() ?? "member",
      bookedCount: _asInt(json["booked_count"]),
      spotsLeft: _asInt(json["spots_left"]),
      isFull: json["is_full"] == true,
      userBooked: json["user_booked"] == true,
      bookings: rawBookings is List<dynamic>
          ? rawBookings
              .whereType<Map<String, dynamic>>()
              .map(EventBookingUser.fromJson)
              .toList()
          : const [],
    );
  }

  String get timeRangeLabel =>
      "${formatApiTime(startTime)} – ${formatApiTime(endTime)}";

  String get audienceLabel =>
      audience == "volunteer" ? "Volunteer help" : "Member sign-up";

  bool get canBook => !isFull && !userBooked;
}

class EventBookingUser {
  const EventBookingUser({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String fullName;
  final String email;

  factory EventBookingUser.fromJson(Map<String, dynamic> json) {
    return EventBookingUser(
      userId: json["user_id"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
    );
  }

  String get displayName => visibleMemberName(fullName: fullName, email: email);
}

class LibraryEventItem {
  const LibraryEventItem({
    required this.eventId,
    required this.name,
    this.description,
    required this.eventDate,
    required this.endDate,
    required this.isPublished,
    required this.createdAt,
    required this.slots,
  });

  final String eventId;
  final String name;
  final String? description;
  final DateTime eventDate;
  final DateTime endDate;
  final bool isPublished;
  final DateTime createdAt;
  final List<EventSlotItem> slots;

  factory LibraryEventItem.fromJson(Map<String, dynamic> json) {
    final rawDate = json["event_date"]?.toString() ?? "";
    final parsedDate = parseApiDate(rawDate);
    if (parsedDate == null) {
      throw FormatException("Invalid event_date: $rawDate");
    }
    final rawEnd = json["end_date"]?.toString() ?? "";
    final parsedEnd = parseApiDate(rawEnd) ?? parsedDate;
    final rawSlots = json["slots"];
    return LibraryEventItem(
      eventId: json["event_id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      description: json["description"]?.toString(),
      eventDate: parsedDate,
      endDate: parsedEnd,
      isPublished: json["is_published"] != false,
      createdAt: DateTime.parse(json["created_at"] as String),
      slots: rawSlots is List<dynamic>
          ? rawSlots
              .whereType<Map<String, dynamic>>()
              .map(EventSlotItem.fromJson)
              .toList()
          : const [],
    );
  }

  String get dateLabel => formatEventDateRange(eventDate, endDate);

  bool get isPast =>
      calendarDay(endDate).isBefore(calendarDay(DateTime.now()));

  bool get spansMultipleDays =>
      calendarDay(eventDate) != calendarDay(endDate);
}

String formatEventDateRange(DateTime start, DateTime end) {
  final startDay = calendarDay(start);
  final endDay = calendarDay(end);
  if (startDay == endDay) return formatSessionDate(start);
  return "${formatSessionDate(start)} – ${formatSessionDate(end)}";
}

bool eventIncludesDay(LibraryEventItem event, DateTime day) {
  final target = calendarDay(day);
  final start = calendarDay(event.eventDate);
  final end = calendarDay(event.endDate);
  return !target.isBefore(start) && !target.isAfter(end);
}

class EventAvailability {
  const EventAvailability({
    required this.availableSlots,
    required this.bookableEvents,
  });

  final int availableSlots;
  final int bookableEvents;

  factory EventAvailability.fromJson(Map<String, dynamic> json) {
    return EventAvailability(
      availableSlots: _asInt(json["available_slots"]),
      bookableEvents: _asInt(json["bookable_events"]),
    );
  }

  bool get hasBookable => availableSlots > 0;
}

class ScheduleDates {
  const ScheduleDates({
    required this.dutyDates,
    required this.eventDates,
  });

  final List<DateTime> dutyDates;
  final List<DateTime> eventDates;

  factory ScheduleDates.fromJson(Map<String, dynamic> json) {
    List<DateTime> parseList(String key) {
      final raw = json[key];
      if (raw is! List<dynamic>) return const [];
      return raw
          .map((value) => parseApiDate(value?.toString() ?? ""))
          .whereType<DateTime>()
          .map(calendarDay)
          .toList();
    }

    return ScheduleDates(
      dutyDates: parseList("duty_dates"),
      eventDates: parseList("event_dates"),
    );
  }

  bool hasDutyOn(DateTime day) =>
      dutyDates.any((d) => calendarDay(d) == calendarDay(day));

  bool hasEventOn(DateTime day) =>
      eventDates.any((d) => calendarDay(d) == calendarDay(day));
}

List<LibraryEventItem> parseEventList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(LibraryEventItem.fromJson)
      .toList();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? "") ?? 0;
}

String eventActionErrorMessage(Object error) {
  return friendlyErrorMessage(
    error,
    fallback: "Couldn't complete that event action. Please try again.",
    statusMessages: {
      403: "You can't book this event slot.",
      409: "This slot is full or no longer available.",
      404: "Event not found.",
    },
  );
}

String eventLoadErrorMessage(Object error) {
  return friendlyErrorMessage(
    error,
    fallback: "Couldn't load library events. Pull down to refresh.",
  );
}
