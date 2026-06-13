/// Admin panel DTOs from `/api/v1/admin/*`.
library;

import "../bookings/booking_models.dart";
import "../profile/kid_profile.dart";
import "../loans/loan_models.dart";

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
    this.membershipDueCents = 0,
    this.membershipFeesPaid = true,
    this.balanceDueCents = 0,
    this.creditBalanceCents = 0,
    this.loans = const [],
  });

  final List<KidProfile> kids;
  final String? avatarPath;
  final String? adminNotes;
  final int membershipDueCents;
  final bool membershipFeesPaid;
  final int balanceDueCents;
  final int creditBalanceCents;
  final List<LoanItem> loans;

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
      membershipDueCents:
          (json["membership_due_cents"] as num?)?.toInt() ?? 0,
      membershipFeesPaid: json["membership_fees_paid"] != false,
      balanceDueCents: (json["balance_due_cents"] as num?)?.toInt() ?? 0,
      creditBalanceCents: (json["credit_balance_cents"] as num?)?.toInt() ?? 0,
      loans: parseLoanItemsList(json["loans"]),
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

class AdminBookingMemberSection {
  const AdminBookingMemberSection({
    required this.memberLabel,
    required this.memberEmail,
    required this.bookings,
  });

  final String memberLabel;
  final String? memberEmail;
  final List<BookingItem> bookings;

  int get toyCount => bookings.length;

  int? get totalRentalCents => totalRentalCentsForBookings(bookings);

  int get unpricedBookingCount => unpricedBookingCountForBookings(bookings);
}

class AdminBookingDateGroup {
  const AdminBookingDateGroup({
    required this.pickupDate,
    required this.pickupLabel,
    required this.members,
  });

  final DateTime pickupDate;
  final String? pickupLabel;
  final List<AdminBookingMemberSection> members;

  BookingPickupDateGroup get pickupSummary => BookingPickupDateGroup(
        pickupDate: pickupDate,
        pickupLabel: pickupLabel,
        bookings: members.expand((member) => member.bookings).toList(),
      );
}

class AdminBookingsGrouped {
  const AdminBookingsGrouped({
    required this.byPickupDate,
    required this.withoutPickupDate,
  });

  final List<AdminBookingDateGroup> byPickupDate;
  final List<AdminBookingMemberSection> withoutPickupDate;
}

AdminBookingsGrouped groupAdminBookingsByDateAndMember(List<BookingItem> items) {
  final withPickup = items.where((item) => item.pickupDate != null).toList();
  final withoutPickup =
      items.where((item) => item.pickupDate == null).toList();

  final byDay = <DateTime, List<BookingItem>>{};
  final labels = <DateTime, String?>{};
  for (final item in withPickup) {
    final day = calendarDay(item.pickupDate!);
    byDay.putIfAbsent(day, () => []).add(item);
    labels.putIfAbsent(day, () => item.pickupLabel);
  }

  final dateGroups = byDay.entries
      .map(
        (entry) => AdminBookingDateGroup(
          pickupDate: entry.key,
          pickupLabel: labels[entry.key],
          members: _memberSectionsForBookings(entry.value),
        ),
      )
      .toList()
    ..sort((a, b) => a.pickupDate.compareTo(b.pickupDate));

  return AdminBookingsGrouped(
    byPickupDate: dateGroups,
    withoutPickupDate: _memberSectionsForBookings(withoutPickup),
  );
}

List<AdminBookingMemberSection> _memberSectionsForBookings(
  List<BookingItem> items,
) {
  final byMember = <String, List<BookingItem>>{};
  for (final item in items) {
    final key = item.userId.isNotEmpty ? item.userId : item.memberLabel;
    byMember.putIfAbsent(key, () => []).add(item);
  }

  final sections = byMember.entries.map((entry) {
    final memberItems = List<BookingItem>.from(entry.value)
      ..sort(
        (a, b) => (a.toyName ?? a.toyId)
            .toLowerCase()
            .compareTo((b.toyName ?? b.toyId).toLowerCase()),
      );
    final first = memberItems.first;
    return AdminBookingMemberSection(
      memberLabel: first.memberLabel,
      memberEmail: first.memberEmail,
      bookings: memberItems,
    );
  }).toList();

  sections.sort(
    (a, b) =>
        a.memberLabel.toLowerCase().compareTo(b.memberLabel.toLowerCase()),
  );
  return sections;
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
