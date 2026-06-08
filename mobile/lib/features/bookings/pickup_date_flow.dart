import "package:flutter/material.dart";

import "booking_models.dart";
import "bookings_controller.dart";
import "pickup_date_picker_sheet.dart";

/// Loads Wed/Sat options and shows the pickup day picker sheet.
Future<PickupDateOption?> choosePickupDate(
  BuildContext context,
  BookingsController bookings, {
  String title = "Choose pickup day",
  String? toyId,
}) async {
  final options = await bookings.loadPickupDates(toyId: toyId);
  if (!context.mounted) return null;
  if (options.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No pickup days are available right now.")),
    );
    return null;
  }
  return showPickupDatePickerSheet(
    context,
    options: options,
    title: title,
  );
}
