/// Admin panel DTOs from `/api/v1/admin/*`.
library;

import "../bookings/booking_models.dart";

class AdminNotifications {
  const AdminNotifications({
    required this.pendingVolunteerApprovals,
    required this.newMembersCount,
  });

  final int pendingVolunteerApprovals;
  final int newMembersCount;

  int get badgeCount => pendingVolunteerApprovals + newMembersCount;

  factory AdminNotifications.fromJson(Map<String, dynamic> json) {
    return AdminNotifications(
      pendingVolunteerApprovals:
          (json["pending_volunteer_approvals"] as num?)?.toInt() ?? 0,
      newMembersCount: (json["new_members_count"] as num?)?.toInt() ?? 0,
    );
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
