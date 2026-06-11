import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "../payments/payment_models.dart";
import "admin_models.dart";

/// Loads admin panel data from `/api/v1/admin/*`.
class AdminController extends ChangeNotifier {
  AdminController(this._client);

  final BackendClient _client;

  AdminNotifications? notifications;
  List<PendingVolunteer> pendingVolunteers = [];
  List<AdminMember> recentMembers = [];
  List<BookingItem> bookings = [];
  List<AdminMember> members = [];

  bool notificationsLoading = false;
  bool pendingLoading = false;
  bool recentMembersLoading = false;
  bool bookingsLoading = false;
  bool membersLoading = false;

  String? notificationsError;
  String? pendingError;
  String? recentMembersError;
  String? bookingsError;
  String? membersError;

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      notificationsLoading = true;
      notifyListeners();
    }
    try {
      final json = await _client.getJson("/api/v1/admin/notifications");
      notifications = AdminNotifications.fromJson(json);
      notificationsError = null;
    } catch (e) {
      notificationsError = e.toString();
    } finally {
      notificationsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecentMembers() async {
    recentMembersLoading = true;
    recentMembersError = null;
    notifyListeners();
    try {
      final json = await _client.getJson("/api/v1/admin/recent-members");
      recentMembers = parseAdminMemberList(json);
      recentMembersError = null;
    } catch (e) {
      recentMembersError = e.toString();
      recentMembers = [];
    } finally {
      recentMembersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingVolunteers() async {
    pendingLoading = true;
    pendingError = null;
    notifyListeners();
    try {
      final json =
          await _client.getJson("/api/v1/admin/pending-duty-volunteers");
      final raw = json["data"];
      pendingVolunteers = raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(PendingVolunteer.fromJson)
              .toList()
          : [];
      pendingError = null;
    } catch (e) {
      pendingError = e.toString();
      pendingVolunteers = [];
    } finally {
      pendingLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveVolunteer(String userId) async {
    await _client.postJson("/api/v1/admin/users/$userId/approve-volunteer");
    pendingVolunteers =
        pendingVolunteers.where((v) => v.userId != userId).toList();
    await Future.wait([
      loadNotifications(silent: true),
      loadRecentMembers(),
    ]);
    notifyListeners();
  }

  Future<List<TodaysDutyShift>> loadTodaysDutyShifts() async {
    final json = await _client.getJson("/api/v1/admin/todays-duty-shifts");
    final raw = json["data"];
    if (raw is! List<dynamic>) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TodaysDutyShift.fromJson)
        .toList();
  }

  Future<void> confirmDutyShift(String sessionId) async {
    await _client.postJson("/api/v1/duty/sessions/$sessionId/confirm");
    await loadNotifications(silent: true);
    notifyListeners();
  }

  Future<void> loadBookings({
    DateTime? pickupFrom,
    DateTime? pickupTo,
    String? memberQuery,
  }) async {
    bookingsLoading = true;
    bookingsError = null;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (pickupFrom != null) {
        query["pickup_from"] = formatApiDate(pickupFrom);
      }
      if (pickupTo != null) {
        query["pickup_to"] = formatApiDate(pickupTo);
      }
      final q = memberQuery?.trim();
      if (q != null && q.isNotEmpty) {
        query["q"] = q;
      }
      final json = await _client.getJson("/api/v1/admin/bookings", query);
      bookings = parseAdminBookingList(json);
      bookingsError = null;
    } catch (e) {
      bookingsError = e.toString();
      bookings = [];
    } finally {
      bookingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMembers({
    String? membershipTier,
    DateTime? startedFrom,
    DateTime? startedTo,
    String? queryText,
  }) async {
    membersLoading = true;
    membersError = null;
    notifyListeners();
    try {
      final query = <String, String>{};
      if (membershipTier != null && membershipTier.isNotEmpty) {
        query["membership_tier"] = membershipTier;
      }
      if (startedFrom != null) {
        query["started_from"] = formatApiDate(startedFrom);
      }
      if (startedTo != null) {
        query["started_to"] = formatApiDate(startedTo);
      }
      final q = queryText?.trim();
      if (q != null && q.isNotEmpty) {
        query["q"] = q;
      }
      final json = await _client.getJson("/api/v1/admin/members", query);
      members = parseAdminMemberList(json);
      membersError = null;
    } catch (e) {
      membersError = e.toString();
      members = [];
    } finally {
      membersLoading = false;
      notifyListeners();
    }
  }

  Future<List<AdminMember>> searchMembers(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    final json = await _client.getJson("/api/v1/admin/members", {
      "q": trimmed,
      "limit": "20",
    });
    return parseAdminMemberList(json);
  }

  Future<AdminMemberDetail> loadMemberDetail(String userId) async {
    final json = await _client.getJson("/api/v1/admin/users/$userId");
    return AdminMemberDetail.fromJson(json);
  }

  Future<AdminMemberDetail> updateMemberMembership(
    String userId,
    String membershipTier,
  ) async {
    final json = await _client.patchJson(
      "/api/v1/admin/users/$userId/membership",
      {"membership_tier": membershipTier},
    );
    return AdminMemberDetail.fromJson(json);
  }

  Future<List<PaymentItem>> loadMemberPayments(String userId) async {
    final json = await _client.getJson("/api/v1/payments/users/$userId");
    return parsePaymentList(json);
  }

  Future<List<PaymentItem>> markMembershipPaid(
    String userId, {
    required String method,
  }) async {
    final json = await _client.postJson(
      "/api/v1/payments/users/$userId/mark-membership-paid",
      {"method": method},
    );
    return parsePaymentList(json);
  }

  Future<PaymentItem> markPaymentPaid(
    String paymentId, {
    required String method,
  }) async {
    final json = await _client.postJson(
      "/api/v1/payments/$paymentId/mark-paid",
      {"method": method},
    );
    return PaymentItem.fromJson(json);
  }

  Future<AdminMemberDetail> updateMemberProfile(
    String userId, {
    List<Map<String, dynamic>>? kids,
    String? adminNotes,
  }) async {
    final body = <String, dynamic>{};
    if (kids != null) body["kids"] = kids;
    if (adminNotes != null) body["admin_notes"] = adminNotes;
    final json = await _client.patchJson("/api/v1/admin/users/$userId", body);
    return AdminMemberDetail.fromJson(json);
  }
}

String adminActionErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return error.toString();
}
