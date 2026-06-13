import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "../payments/payment_models.dart";
import "../loans/loan_models.dart";
import "admin_models.dart";
import "admin_statistics_models.dart";

/// Loads admin panel data from `/api/v1/admin/*`.
class AdminController extends ChangeNotifier {
  AdminController(this._client);

  final BackendClient _client;

  AdminNotifications? notifications;
  List<PendingVolunteer> pendingVolunteers = [];
  List<AdminMember> recentMembers = [];
  List<BookingItem> bookings = [];
  List<AdminMember> members = [];

  StatsOverview? statsOverview;
  StatsBreakdown? statsBreakdown;
  StatsCatalog? statsCatalog;
  ToyPopularity? toyPopularity;
  int _breakdownRequestId = 0;

  bool notificationsLoading = false;
  bool pendingLoading = false;
  bool recentMembersLoading = false;
  bool bookingsLoading = false;
  bool membersLoading = false;
  bool statsLoading = false;
  bool statsBreakdownLoading = false;

  String? notificationsError;
  String? pendingError;
  String? recentMembersError;
  String? bookingsError;
  String? membersError;
  String? statsError;

  Map<String, String> _statsQuery({
    required String period,
    DateTime? sessionDate,
    int? year,
    int? month,
    String? groupBy,
  }) {
    final query = <String, String>{"period": period};
    if (period == "session" && sessionDate != null) {
      query["session_date"] = formatApiDate(sessionDate);
    }
    if (period == "month") {
      if (year != null) query["year"] = "$year";
      if (month != null) query["month"] = "$month";
    }
    if (period == "year" && year != null) {
      query["year"] = "$year";
    }
    if (groupBy != null && groupBy.isNotEmpty) query["group_by"] = groupBy;
    return query;
  }

  Future<void> loadStatsOverview({
    required String period,
    DateTime? sessionDate,
    int? year,
    int? month,
  }) async {
    statsLoading = true;
    statsError = null;
    notifyListeners();
    try {
      final json = await _client.getJson(
        "/api/v1/admin/stats/overview",
        _statsQuery(
          period: period,
          sessionDate: sessionDate,
          year: year,
          month: month,
        ),
      );
      statsOverview = StatsOverview.fromJson(json);
      statsError = null;
    } catch (e) {
      statsError = e.toString();
    } finally {
      statsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStatsBreakdown({
    required String period,
    DateTime? sessionDate,
    int? year,
    int? month,
    String groupBy = "category",
  }) async {
    final requestId = ++_breakdownRequestId;
    statsBreakdownLoading = true;
    notifyListeners();
    try {
      final json = await _client.getJson(
        "/api/v1/admin/stats/loans/breakdown",
        _statsQuery(
          period: period,
          sessionDate: sessionDate,
          year: year,
          month: month,
          groupBy: groupBy,
        ),
      );
      if (requestId != _breakdownRequestId) return;
      statsBreakdown = StatsBreakdown.fromJson(json);
      statsError = null;
    } catch (e) {
      if (requestId != _breakdownRequestId) return;
      statsBreakdown = null;
      statsError ??= e.toString();
    } finally {
      if (requestId == _breakdownRequestId) {
        statsBreakdownLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadStatsCatalog() async {
    try {
      final json = await _client.getJson("/api/v1/admin/stats/catalog");
      statsCatalog = StatsCatalog.fromJson(json);
      notifyListeners();
    } catch (e) {
      statsCatalog = null;
      statsError ??= e.toString();
      notifyListeners();
    }
  }

  Future<void> loadToyPopularity({
    required String period,
    DateTime? sessionDate,
    int? year,
    int? month,
  }) async {
    try {
      final json = await _client.getJson(
        "/api/v1/admin/stats/toys/popularity",
        _statsQuery(
          period: period,
          sessionDate: sessionDate,
          year: year,
          month: month,
        ),
      );
      toyPopularity = ToyPopularity.fromJson(json);
      notifyListeners();
    } catch (e) {
      toyPopularity = null;
      statsError ??= e.toString();
      notifyListeners();
    }
  }

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

  Future<List<LoanItem>> loadMemberLoans(String userId) async {
    final json = await _client.getJson("/api/v1/admin/users/$userId/loans");
    return parseLoanList(json);
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

  Future<PaymentItem> recordMemberTopUp(
    String userId, {
    required int amountCents,
    required String method,
  }) async {
    final json = await _client.postJson(
      "/api/v1/payments/users/$userId/top-up",
      {"amount_cents": amountCents, "method": method},
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
