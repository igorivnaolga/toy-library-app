import "package:flutter/widgets.dart";
import "package:provider/provider.dart";

import "../admin/admin_controller.dart";
import "../catalog/catalog_provider.dart";
import "booking_models.dart";
import "bookings_controller.dart";

/// Keeps member/admin booking lists in sync after a desk reservation check-out.
Future<void> syncAfterReservationCheckout(
  BuildContext context,
  Iterable<BookingItem> bookings,
) async {
  final items = bookings.toList();
  if (items.isEmpty) return;

  final bookingIds = items.map((booking) => booking.bookingId);
  context.read<BookingsController>().markBookingsCompleted(bookingIds);
  context.read<AdminController>().removeBookings(bookingIds);

  final catalog = context.read<CatalogController>();
  for (final booking in items) {
    await catalog.updateToyInCatalog(booking.toyId);
  }
}
