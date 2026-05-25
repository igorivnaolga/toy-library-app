import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "loan_models.dart";

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
      myLoansError = e.toString();
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
    try {
      final pendingJson = await _client.getJson("/api/v1/bookings/pending");
      final activeJson = await _client.getJson("/api/v1/loans/active");
      pendingCheckouts = _parseBookingList(pendingJson);
      activeLoans = _parseLoanList(activeJson);
      deskError = null;
    } on ApiException catch (e) {
      deskError = _friendlyDeskMessage(e);
      pendingCheckouts = [];
      activeLoans = [];
    } catch (e) {
      deskError = e.toString();
      pendingCheckouts = [];
      activeLoans = [];
    } finally {
      deskLoading = false;
      notifyListeners();
    }
  }

  Future<LoanItem> checkOutFromBooking(String bookingId) async {
    final json = await _client.postJson("/api/v1/loans/check-out/booking", {
      "booking_id": bookingId,
    });
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

  Future<LoanItem> checkIn(String loanId) async {
    final json = await _client.postJson("/api/v1/loans/$loanId/check-in");
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
    myLoans = [
      for (final item in myLoans)
        if (item.loanId == loan.loanId) loan else item,
    ];
    activeLoans = [
      for (final item in activeLoans)
        if (item.loanId == loan.loanId) loan else item,
    ];
    sortLoansList(myLoans);
    sortLoansList(activeLoans);
    notifyListeners();
    return loan;
  }

  List<LoanItem> _parseLoanList(Map<String, dynamic> json) {
    final raw = json["data"];
    if (raw is! List<dynamic>) {
      return [];
    }
    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(LoanItem.fromJson)
        .toList();
    sortLoansList(items);
    return items;
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
    if (e.statusCode == 401) {
      return "Please sign in again to view your loans.";
    }
    if (e.statusCode == 403) {
      return "Your account cannot view loans yet.";
    }
    return e.message;
  }

  String _friendlyDeskMessage(ApiException e) {
    if (e.statusCode == 401) {
      return "Please sign in again to use the volunteer desk.";
    }
    if (e.statusCode == 403) {
      return "Volunteer access is required for checkout and check-in.";
    }
    return e.message;
  }
}

String loanActionErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 409:
        return "This toy is not available for that action right now.";
      case 404:
        return "Loan or booking not found.";
      case 403:
        return "You do not have permission for this loan action.";
      case 422:
        return error.message;
      default:
        return error.message;
    }
  }
  return error.toString();
}
