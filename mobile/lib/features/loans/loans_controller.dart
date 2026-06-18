import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../../core/user_friendly_error.dart";
import "../bookings/booking_models.dart";
import "../payments/payment_models.dart";
import "../catalog/catalog_models.dart";
import "desk_member.dart";
import "loan_models.dart";
import "piece_estimate.dart";

/// Loads and mutates loans via `/api/v1/loans` and volunteer checkout queue.
class LoansController extends ChangeNotifier {
  LoansController(this._client);

  final BackendClient _client;

  List<LoanItem> myLoans = [];
  List<BookingItem> pendingCheckouts = [];
  List<LoanItem> activeLoans = [];

  bool myLoansLoading = false;
  bool deskLoading = false;
  String? myLoansError;
  String? deskError;

  /// Active loan for [toyId], if any (requires [loadMyLoans] with `activeOnly: true`).
  LoanItem? activeLoanForToy(String toyId) {
    for (final loan in myLoans) {
      if (loan.isActive && loan.toyId == toyId) return loan;
    }
    return null;
  }

  Future<void> loadMyLoans({bool activeOnly = false}) async {
    myLoansLoading = true;
    myLoansError = null;
    notifyListeners();
    try {
      final json = await _client.getJson(
        "/api/v1/loans/me",
        activeOnly ? {"active_only": "true"} : null,
      );
      myLoans = _parseLoanList(json);
      myLoansError = null;
    } on ApiException catch (e) {
      myLoansError = _friendlyMyLoansMessage(e);
      myLoans = [];
    } catch (e) {
      myLoansError = friendlyErrorMessage(
        e,
        fallback: "Couldn't load your loans. Pull down to refresh.",
      );
      myLoans = [];
    } finally {
      myLoansLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVolunteerDesk() async {
    deskLoading = true;
    deskError = null;
    notifyListeners();

    ApiException? activeError;

    await Future.wait([
      () async {
        try {
          final activeJson = await _client.getJson("/api/v1/loans/active");
          activeLoans = _parseLoanList(activeJson);
        } on ApiException catch (e) {
          activeError = e;
          activeLoans = [];
        } catch (e) {
          activeError = ApiException(
            friendlyErrorMessage(
              e,
              fallback: "Couldn't load the volunteer desk.",
            ),
          );
          activeLoans = [];
        }
      }(),
      () async {
        try {
          final pendingJson =
              await _client.getJson("/api/v1/bookings/pending");
          pendingCheckouts = _parseBookingList(pendingJson);
        } on ApiException {
          pendingCheckouts = [];
        } catch (_) {
          pendingCheckouts = [];
        }
      }(),
    ]);

    deskError =
        activeError == null ? null : _friendlyDeskMessage(activeError!);
    deskLoading = false;
    notifyListeners();
  }

  Future<MemberBalanceSummary> loadMemberBalanceSummary(String userId) async {
    final json = await _client.getJson(
      "/api/v1/payments/users/$userId/balance-summary",
    );
    return MemberBalanceSummary.fromJson(json);
  }

  Future<LoanItem> checkOutFromBooking(
    String bookingId, {
    String rentalPayment = "pending",
    String? paymentMethod,
  }) async {
    final body = <String, dynamic>{
      "booking_id": bookingId,
      "rental_payment": rentalPayment,
    };
    if (paymentMethod != null) {
      body["payment_method"] = paymentMethod;
    }
    final json = await _client.postJson("/api/v1/loans/check-out/booking", body);
    final loan = LoanItem.fromJson(json);
    pendingCheckouts =
        pendingCheckouts.where((b) => b.bookingId != bookingId).toList();
    activeLoans = [
      loan,
      ...activeLoans.where((l) => l.loanId != loan.loanId),
    ];
    sortLoansList(activeLoans);
    notifyListeners();
    return loan;
  }

  Future<LoanItem> checkOutWalkIn({
    required String userId,
    required String toyId,
    String rentalPayment = "pending",
    String? paymentMethod,
  }) async {
    final body = <String, dynamic>{
      "user_id": userId,
      "toy_id": toyId,
      "rental_payment": rentalPayment,
    };
    if (paymentMethod != null) {
      body["payment_method"] = paymentMethod;
    }
    final json = await _client.postJson("/api/v1/loans/check-out/walk-in", body);
    final loan = LoanItem.fromJson(json);
    activeLoans = [
      loan,
      ...activeLoans.where((l) => l.loanId != loan.loanId),
    ];
    sortLoansList(activeLoans);
    notifyListeners();
    return loan;
  }

  Future<DeskMember?> fetchDeskMember(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    final json = await _client.getJson("/api/v1/duty/members", {"q": trimmed});
    final members = parseDeskMemberList(json);
    for (final member in members) {
      if (member.userId == trimmed) return member;
    }
    return members.isNotEmpty ? members.first : null;
  }

  Future<List<DeskMember>> searchDeskMembers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final json = await _client.getJson("/api/v1/duty/members");
      return parseDeskMemberList(json);
    }
    final json = await _client.getJson("/api/v1/duty/members", {"q": trimmed});
    return parseDeskMemberList(json);
  }

  Future<List<BookingItem>> loadMemberPendingBookings(String userId) async {
    final json = await _client.getJson(
      "/api/v1/bookings/pending",
      {"user_id": userId},
    );
    return _parseBookingList(json);
  }

  Future<List<ToyItem>> searchDeskToys(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    final json = await _client.getJson("/api/v1/toys", {
      "q": trimmed,
      "availability": "available",
      "limit": "10",
      "page": "1",
    });
    final raw = json["data"];
    if (raw is! List<dynamic>) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ToyItem.fromJson)
        .toList();
  }

  Future<PieceEstimate> estimatePieces({
    required String toyId,
    required String imagePath,
  }) async {
    final json = await _client.postMultipartImage(
      "/api/v1/desk/identify-pieces",
      fileField: "image",
      filePath: imagePath,
      fields: {"toy_id": toyId},
      timeout: const Duration(seconds: 90),
    );
    return PieceEstimate.fromJson(json);
  }

  /// Fire-and-forget training from a volunteer-confirmed check-in photo.
  Future<void> learnFromPhoto({
    required String toyId,
    required List<int> imageBytes,
    required int confirmedPieceCount,
    bool isCompleteSet = false,
  }) async {
    await _client.postMultipartBytes(
      "/api/v1/desk/learn-from-photo",
      fileField: "image",
      bytes: imageBytes,
      fields: {
        "toy_id": toyId,
        "confirmed_piece_count": confirmedPieceCount.toString(),
        if (isCompleteSet) "is_complete_set": "true",
      },
      timeout: const Duration(seconds: 90),
    );
  }

  Future<LoanItem> checkIn(
    String loanId, {
    int? missingPieces,
    String? missingPiecesDetail,
  }) async {
    final body = <String, dynamic>{};
    if (missingPieces != null) {
      body["missing_pieces"] = missingPieces;
    }
    final detail = missingPiecesDetail?.trim();
    if (detail != null && detail.isNotEmpty) {
      body["missing_pieces_detail"] = detail;
    }
    final payload = body.isEmpty ? null : body;
    final json =
        await _client.postJson("/api/v1/loans/$loanId/check-in", payload);
    final loan = LoanItem.fromJson(json);
    activeLoans = activeLoans.where((l) => l.loanId != loanId).toList();
    myLoans = [
      for (final item in myLoans)
        if (item.loanId == loan.loanId) loan else item,
    ];
    sortLoansList(myLoans);
    notifyListeners();
    return loan;
  }

  Future<LoanItem> renewLoan(String loanId) async {
    final json = await _client.postJson("/api/v1/loans/$loanId/renew");
    final loan = LoanItem.fromJson(json);
    final exists = myLoans.any((item) => item.loanId == loan.loanId);
    myLoans = exists
        ? [
            for (final item in myLoans)
              if (item.loanId == loan.loanId) loan else item,
          ]
        : [...myLoans, loan];
    final deskExists = activeLoans.any((item) => item.loanId == loan.loanId);
    activeLoans = deskExists
        ? [
            for (final item in activeLoans)
              if (item.loanId == loan.loanId) loan else item,
          ]
        : [...activeLoans, loan];
    sortLoansList(myLoans);
    sortLoansList(activeLoans);
    notifyListeners();
    return loan;
  }

  List<LoanItem> _parseLoanList(Map<String, dynamic> json) {
    return parseLoanList(json);
  }

  List<BookingItem> _parseBookingList(Map<String, dynamic> json) {
    final raw = json["data"];
    if (raw is! List<dynamic>) {
      return [];
    }
    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
    sortBookingsList(items);
    return items;
  }

  String _friendlyMyLoansMessage(ApiException e) {
    return friendlyErrorMessage(
      e,
      fallback: "Couldn't load your loans. Pull down to refresh.",
      statusMessages: {
        401: "Please sign in again to view your loans.",
        403: "Your account cannot view loans yet.",
      },
    );
  }

  String _friendlyDeskMessage(ApiException e) {
    if (e.statusCode == 403) {
      final lower = e.message.toLowerCase();
      if (lower.contains("30 minutes") || lower.contains("duty desk opens")) {
        return e.message;
      }
    }
    return friendlyErrorMessage(
      e,
      fallback: "Couldn't load the volunteer desk. Pull down to refresh.",
      statusMessages: {
        401: "Please sign in again to use the volunteer desk.",
        403: "Book a duty shift from the duty roster (calendar icon), "
            "then return to the desk on your shift day.",
      },
    );
  }
}

String loanActionErrorMessage(Object error) {
  if (error is ApiException &&
      error.statusCode == 409 &&
      error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  if (error is ApiException && error.statusCode == 403) {
    final lower = error.message.toLowerCase();
    if (lower.contains("30 minutes") || lower.contains("duty desk opens")) {
      return error.message;
    }
  }
  return friendlyErrorMessage(
    error,
    fallback: "Couldn't complete that loan action. Please try again.",
    statusMessages: {
      403: "Book a duty shift on the Duty tab to use the volunteer desk.",
      404: "Loan or booking not found.",
    },
  );
}
