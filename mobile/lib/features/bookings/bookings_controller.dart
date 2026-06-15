import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "booking_models.dart";

/// Loads and mutates bookings via `/api/v1/bookings`.
class BookingsController extends ChangeNotifier {
  BookingsController(this._client);

  final BackendClient _client;

  List<BookingItem> bookings = [];
  bool loading = false;
  String? error;

  Future<void> loadBookings() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final json = await _client.getJson("/api/v1/bookings/me");
      final raw = json["data"];
      if (raw is! List<dynamic>) {
        bookings = [];
      } else {
        bookings = raw
            .whereType<Map<String, dynamic>>()
            .map(BookingItem.fromJson)
            .toList();
        sortBookingsList(bookings);
      }
      error = null;
    } on ApiException catch (e) {
      error = _friendlyMessage(e);
      bookings = [];
    } catch (e) {
      error = e.toString();
      bookings = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<PickupDateOption>> loadPickupDates({String? toyId}) async {
    final query = <String, String>{};
    final id = toyId?.trim();
    if (id != null && id.isNotEmpty) {
      query["toy_id"] = id;
    }
    final json = await _client.getJson(
      "/api/v1/bookings/pickup-dates",
      query.isEmpty ? null : query,
    );
    final raw = json["data"];
    if (raw is! List<dynamic>) {
      return const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PickupDateOption.fromJson)
        .toList();
  }

  Future<BookingItem> createBooking(String toyId, DateTime pickupDate) async {
    final json = await _client.postJson("/api/v1/bookings", {
      "toy_id": toyId,
      "pickup_date": formatApiDate(pickupDate),
    });
    final item = BookingItem.fromJson(json);
    bookings = [item, ...bookings.where((b) => b.bookingId != item.bookingId)];
    sortBookingsList(bookings);
    notifyListeners();
    return item;
  }

  Future<BookingItem> rescheduleBooking(
    String bookingId,
    DateTime pickupDate,
  ) async {
    final json = await _client.patchJson(
      "/api/v1/bookings/$bookingId",
      {"pickup_date": formatApiDate(pickupDate)},
    );
    final item = BookingItem.fromJson(json);
    bookings = [
      for (final b in bookings)
        if (b.bookingId == item.bookingId) item else b,
    ];
    sortBookingsList(bookings);
    notifyListeners();
    return item;
  }

  Future<BookingItem> cancelBooking(String bookingId) async {
    final json = await _client.postJson(
      "/api/v1/bookings/$bookingId/cancel",
    );
    final item = BookingItem.fromJson(json);
    bookings = [
      for (final b in bookings)
        if (b.bookingId == item.bookingId) item else b,
    ];
    sortBookingsList(bookings);
    notifyListeners();
    return item;
  }

  /// Desk check-out: move reservations out of upcoming without a full reload.
  void markBookingsCompleted(Iterable<String> bookingIds) {
    final ids = bookingIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;

    var changed = false;
    bookings = [
      for (final booking in bookings)
        if (idSet.contains(booking.bookingId) && booking.isPending)
          () {
            changed = true;
            return booking.withStatus("completed");
          }()
        else
          booking,
    ];
    if (changed) {
      sortBookingsList(bookings);
      notifyListeners();
    }
  }

  /// Pending reservation for [toyId], if the member already booked this toy.
  BookingItem? pendingBookingForToy(String toyId) {
    for (final booking in bookings) {
      if (booking.toyId == toyId && booking.isPending) {
        return booking;
      }
    }
    return null;
  }

  String _friendlyMessage(ApiException e) {
    if (e.statusCode == 401) {
      return "Please sign in again to view your bookings.";
    }
    if (e.statusCode == 403) {
      return "Your account cannot make bookings yet.";
    }
    return e.message;
  }
}

String bookingActionErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 409) {
      return "This toy is not available to book right now.";
    }
    if (error.statusCode == 404) {
      return "Toy not found.";
    }
    if (error.statusCode == 403) {
      return "Sign in as a member to book toys.";
    }
    if (error.statusCode == 422) {
      return error.message;
    }
    return error.message;
  }
  return error.toString();
}
