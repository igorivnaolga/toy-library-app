/// Admin panel DTOs from `/api/v1/admin/*`.
library;

import "../bookings/booking_models.dart";
import "../profile/kid_profile.dart";

class AdminNotifications {
  const AdminNotifications({
    required this.pendingVolunteerApprovals,
    required this.pendingDutyConfirmations,
    required this.newMembersCount,
  });

  final int pendingVolunteerApprovals;
  final int pendingDutyConfirmations;
  final int newMembersCount;

  int get badgeCount => pendingVolunteerApprovals + newMembersCount;

  factory AdminNotifications.fromJson(Map<String, dynamic> json) {
    return AdminNotifications(
      pendingVolunteerApprovals:
          (json["pending_volunteer_approvals"] as num?)?.toInt() ?? 0,
      pendingDutyConfirmations:
          (json["pending_duty_confirmations"] as num?)?.toInt() ?? 0,
      newMembersCount: (json["new_members_count"] as num?)?.toInt() ?? 0,
    );
  }
}

class TodaysDutyShift {
  const TodaysDutyShift({
    required this.sessionId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.volunteerName,
    this.volunteerEmail,
  });

  final String sessionId;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;
  final String? volunteerName;
  final String? volunteerEmail;

  factory TodaysDutyShift.fromJson(Map<String, dynamic> json) {
    final rawDate = json["session_date"]?.toString() ?? "";
    final parsedDate = DateTime.tryParse(rawDate) ??
        DateTime.parse("${rawDate}T00:00:00");
    return TodaysDutyShift(
      sessionId: json["session_id"]?.toString() ?? "",
      sessionDate: parsedDate,
      startTime: json["start_time"]?.toString() ?? "",
      endTime: json["end_time"]?.toString() ?? "",
      volunteerName: json["volunteer_name"]?.toString(),
      volunteerEmail: json["volunteer_email"]?.toString(),
    );
  }

  String get volunteerDisplayName {
    final name = volunteerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = volunteerEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return "Volunteer";
  }

  String get timeRangeLabel {
    String fmt(String raw) {
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

    return "${fmt(startTime)} – ${fmt(endTime)}";
  }
}

class PendingVolunteer {
  const PendingVolunteer({
    required this.userId,
    required this.email,
    required this.fullName,
  });

  final String userId;
  final String email;
  final String fullName;

  factory PendingVolunteer.fromJson(Map<String, dynamic> json) {
    return PendingVolunteer(
      userId: json["user_id"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
    );
  }

  String get displayName =>
      fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : userId);
}

class AdminMember {
  const AdminMember({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.membershipTier,
    this.volunteerConfirmed = false,
    this.membershipStartedAt,
    this.membershipEndsAt,
  });

  final String userId;
  final String email;
  final String fullName;
  final String role;
  final String? membershipTier;
  final bool volunteerConfirmed;
  final DateTime? membershipStartedAt;
  final DateTime? membershipEndsAt;

  factory AdminMember.fromJson(Map<String, dynamic> json) {
    return AdminMember(
      userId: json["user_id"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
      role: json["role"]?.toString() ?? "member",
      membershipTier: json["membership_tier"]?.toString(),
      volunteerConfirmed: json["volunteer_confirmed"] == true,
      membershipStartedAt: json["membership_started_at"] == null
          ? null
          : DateTime.tryParse(json["membership_started_at"].toString()),
      membershipEndsAt: json["membership_ends_at"] == null
          ? null
          : DateTime.tryParse(json["membership_ends_at"].toString()),
    );
  }

  String get displayName =>
      fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : userId);
}

class AdminMemberDetail extends AdminMember {
  const AdminMemberDetail({
    required super.userId,
    required super.email,
    required super.fullName,
    required super.role,
    super.membershipTier,
    super.volunteerConfirmed = false,
    super.membershipStartedAt,
    super.membershipEndsAt,
    this.kids = const [],
    this.avatarPath,
    this.adminNotes,
  });

  final List<KidProfile> kids;
  final String? avatarPath;
  final String? adminNotes;

  factory AdminMemberDetail.fromJson(Map<String, dynamic> json) {
    return AdminMemberDetail(
      userId: json["user_id"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
      role: json["role"]?.toString() ?? "member",
      membershipTier: json["membership_tier"]?.toString(),
      volunteerConfirmed: json["volunteer_confirmed"] == true,
      membershipStartedAt: json["membership_started_at"] == null
          ? null
          : DateTime.tryParse(json["membership_started_at"].toString()),
      membershipEndsAt: json["membership_ends_at"] == null
          ? null
          : DateTime.tryParse(json["membership_ends_at"].toString()),
      kids: parseKidsList(json["kids"]),
      avatarPath: json["avatar_path"]?.toString(),
      adminNotes: json["admin_notes"]?.toString(),
    );
  }
}

List<BookingItem> parseAdminBookingList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return [];
  final items = raw
      .whereType<Map<String, dynamic>>()
      .map(BookingItem.fromJson)
      .toList();
  sortBookingsList(items);
  return items;
}

List<AdminMember> parseAdminMemberList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(AdminMember.fromJson)
      .toList();
}

String formatAdminDate(DateTime? value) {
  if (value == null) return "—";
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
  return "${value.day} ${months[value.month - 1]} ${value.year}";
}
