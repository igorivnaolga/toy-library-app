import "package:flutter_test/flutter_test.dart";
import "package:toy_library_mobile/core/reminder_scheduler.dart";
import "package:toy_library_mobile/features/bookings/booking_models.dart";
import "package:toy_library_mobile/features/loans/loan_models.dart";

void main() {
  test("schedules pickup and return reminders in the future", () {
    final now = DateTime(2026, 6, 1, 10);
    final reminders = buildMemberReminders(
      now: now,
      bookings: [
        BookingItem(
          bookingId: "b1",
          userId: "u1",
          toyId: "100",
          toyName: "Duplo set",
          status: "pending",
          pickupDate: DateTime(2026, 6, 4),
          pickupLabel: "Wed 4 Jun",
          createdAt: now,
        ),
      ],
      loans: [
        LoanItem(
          loanId: "l1",
          userId: "u1",
          toyId: "200",
          toyName: "Train",
          status: "active",
          checkedOutAt: now,
          dueDate: DateTime(2026, 6, 10),
          returnSessionDate: DateTime(2026, 6, 10),
          renewalCount: 0,
          isOverdue: false,
        ),
      ],
    );

    expect(reminders.length, greaterThanOrEqualTo(3));
    expect(
      reminders.any((item) => item.title.contains("pickup")),
      isTrue,
    );
    expect(
      reminders.any((item) => item.title.contains("return")),
      isTrue,
    );
    expect(reminders.every((item) => item.when.isAfter(now)), isTrue);
  });

  test("skips cancelled bookings and returned loans", () {
    final now = DateTime(2026, 6, 1, 10);
    final reminders = buildMemberReminders(
      now: now,
      bookings: [
        BookingItem(
          bookingId: "b1",
          userId: "u1",
          toyId: "100",
          status: "cancelled",
          pickupDate: DateTime(2026, 6, 4),
          createdAt: now,
        ),
      ],
      loans: [
        LoanItem(
          loanId: "l1",
          userId: "u1",
          toyId: "200",
          status: "returned",
          checkedOutAt: now,
          dueDate: DateTime(2026, 6, 10),
          returnSessionDate: DateTime(2026, 6, 10),
          renewalCount: 0,
          isOverdue: false,
        ),
      ],
    );

    expect(reminders, isEmpty);
  });
}
