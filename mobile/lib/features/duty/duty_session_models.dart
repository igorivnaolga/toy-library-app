import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";

/// Duty roster slot from `/api/v1/duty/sessions`.
class DutySessionItem {
  const DutySessionItem({
    required this.sessionId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.volunteerId,
    this.volunteerName,
  });

  final String sessionId;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;
  final String? volunteerId;
  final String? volunteerName;
  final DateTime createdAt;

  bool get isOpen => volunteerId == null || volunteerId!.isEmpty;

  factory DutySessionItem.fromJson(Map<String, dynamic> json) {
    final rawDate = json["session_date"]?.toString() ?? "";
    final parsedDate = parseApiDate(rawDate);
    if (parsedDate == null) {
      throw FormatException("Invalid session_date: $rawDate");
    }
    return DutySessionItem(
      sessionId: json["session_id"]?.toString() ?? "",
      sessionDate: parsedDate,
      startTime: json["start_time"]?.toString() ?? "",
      endTime: json["end_time"]?.toString() ?? "",
      volunteerId: json["volunteer_id"]?.toString(),
      volunteerName: json["volunteer_name"]?.toString(),
      createdAt: DateTime.parse(json["created_at"] as String),
    );
  }

  String get dateLabel => formatSessionDate(sessionDate);

  String get timeRangeLabel =>
      "${formatApiTime(startTime)} – ${formatApiTime(endTime)}";

  String statusLabel({required String? currentUserId}) {
    if (isOpen) return "Open slot";
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        volunteerId == currentUserId) {
      return "Your shift";
    }
    if (volunteerName != null && volunteerName!.isNotEmpty) {
      return volunteerName!;
    }
    return "Booked";
  }
}

class OnDutyStatus {
  const OnDutyStatus({required this.onDuty, this.session});

  final bool onDuty;
  final DutySessionItem? session;

  factory OnDutyStatus.fromJson(Map<String, dynamic> json) {
    final rawSession = json["session"];
    return OnDutyStatus(
      onDuty: json["on_duty"] == true,
      session: rawSession is Map<String, dynamic>
          ? DutySessionItem.fromJson(rawSession)
          : null,
    );
  }
}

/// Wed/Sat library session times (matches backend `library_sessions.py`).
class LibrarySessionTimes {
  const LibrarySessionTimes._();

  static ({String start, String end})? forDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.wednesday:
        return (start: "13:00:00", end: "14:30:00");
      case DateTime.saturday:
        return (start: "11:30:00", end: "14:00:00");
      default:
        return null;
    }
  }

  static bool isSessionDay(DateTime date) => forDate(date) != null;
}

const _weekdayNames = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];

const _monthNames = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

String formatSessionDate(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return "$weekday ${date.day} $month";
}

String formatApiTime(String raw) {
  final parts = raw.split(":");
  if (parts.length < 2) return raw;
  var hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final period = hour >= 12 ? "pm" : "am";
  if (hour > 12) hour -= 12;
  if (hour == 0) hour = 12;
  if (minute == 0) return "$hour $period";
  return "$hour:${minute.toString().padLeft(2, "0")} $period";
}

List<DutySessionItem> parseDutySessionList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return [];
  final items = raw
      .whereType<Map<String, dynamic>>()
      .map(DutySessionItem.fromJson)
      .toList();
  sortDutySessions(items);
  return items;
}

void sortDutySessions(List<DutySessionItem> items) {
  items.sort((a, b) {
    final dateOrder = a.sessionDate.compareTo(b.sessionDate);
    if (dateOrder != 0) return dateOrder;
    return a.startTime.compareTo(b.startTime);
  });
}

String dutyActionErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 403:
        return "You do not have permission for this duty action.";
      case 409:
        return "This duty slot is no longer available.";
      case 404:
        return "Duty session not found.";
      default:
        return error.message;
    }
  }
  return error.toString();
}
