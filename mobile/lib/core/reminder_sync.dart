import "dart:async";

import "package:flutter/widgets.dart";
import "package:provider/provider.dart";

import "../features/bookings/booking_models.dart";
import "../features/bookings/bookings_controller.dart";
import "../features/loans/loan_models.dart";
import "../features/loans/loans_controller.dart";
import "auth_store.dart";
import "reminder_notifications.dart";

/// Keeps device reminders aligned with bookings and active loans.
class ReminderSync {
  ReminderSync._();

  static bool remindersEnabled(AuthStore auth) {
    if (!auth.canBookToys) return false;
    return auth.contact.textRemindersConsent == true;
  }

  static Future<void> syncFromControllers(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthStore>();
    final bookings = context.read<BookingsController>().bookings;
    final loans = context
        .read<LoansController>()
        .myLoans
        .where((loan) => loan.isActive)
        .toList();
    await _sync(bookings: bookings, loans: loans, enabled: remindersEnabled(auth));
  }

  static Future<void> syncFromData({
    required List<BookingItem> bookings,
    required List<LoanItem> loans,
    required bool enabled,
  }) {
    return ReminderNotificationService.instance.syncMemberReminders(
      bookings: bookings,
      loans: loans.where((loan) => loan.isActive).toList(),
      enabled: enabled,
    );
  }

  static Future<void> clear() {
    return ReminderNotificationService.instance.cancelAll();
  }

  static Future<void> refreshForMember(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthStore>();
    if (!auth.canBookToys) {
      await clear();
      return;
    }

    await context.read<BookingsController>().loadBookings();
    if (!context.mounted) return;
    await context.read<LoansController>().loadMyLoans(activeOnly: true);
    if (!context.mounted) return;
    await syncFromControllers(context);
  }

  static Future<void> _sync({
    required List<BookingItem> bookings,
    required List<LoanItem> loans,
    required bool enabled,
  }) {
    return ReminderNotificationService.instance.syncMemberReminders(
      bookings: bookings,
      loans: loans,
      enabled: enabled,
    );
  }
}
