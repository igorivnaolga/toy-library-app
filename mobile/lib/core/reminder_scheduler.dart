import "loan_due_status.dart";
import "../features/bookings/booking_models.dart" show BookingItem, formatDisplayDate;
import "../features/duty/duty_session_models.dart";
import "../features/loans/loan_models.dart" show LoanItem;

/// One scheduled local notification for a booking or loan reminder.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
}

const _bookingIdBase = 1000;
const _loanIdBase = 2000;
const _idSpread = 800;

/// Evening reminder the day before pickup, return, or an overdue return session.
const int eveReminderHour = 18;
const int eveReminderMinute = 0;

/// Morning reminder on due/pickup day.
const int pickupMorningHour = 9;
const int pickupMorningMinute = 0;

/// How far ahead to queue overdue session-eve alerts (matches booking horizon).
const int overdueReminderHorizonDays = 183;

int reminderStableId(String key, int base, int slot) {
  return base + (key.hashCode.abs() % _idSpread) + slot;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _atLocalTime(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

bool _isFuture(DateTime when, DateTime now) => when.isAfter(now);

String _toyLabel(String? name, String toyId) {
  final trimmed = name?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return toyId;
}

/// Build local notification schedule from pending bookings and active loans.
List<ScheduledReminder> buildMemberReminders({
  required List<BookingItem> bookings,
  required List<LoanItem> loans,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final reminders = <ScheduledReminder>[];

  for (final booking in bookings) {
    if (!booking.isPending) continue;
    final pickup = booking.pickupDate;
    if (pickup == null) continue;

    final pickupDay = _dateOnly(pickup);
    final toy = _toyLabel(booking.toyName, booking.toyId);
    final pickupText = booking.pickupLabel?.trim();
    final eveDay = pickupDay.subtract(const Duration(days: 1));

    final eveWhen = _atLocalTime(eveDay, eveReminderHour, eveReminderMinute);
    if (_isFuture(eveWhen, clock)) {
      reminders.add(
        ScheduledReminder(
          id: reminderStableId(booking.bookingId, _bookingIdBase, 0),
          title: "Toy pickup tomorrow",
          body: pickupText != null && pickupText.isNotEmpty
              ? "Pick up $toy ($pickupText)."
              : "Pick up $toy on ${formatDisplayDate(pickupDay)}.",
          when: eveWhen,
        ),
      );
    }

    final morningWhen =
        _atLocalTime(pickupDay, pickupMorningHour, pickupMorningMinute);
    if (_isFuture(morningWhen, clock)) {
      reminders.add(
        ScheduledReminder(
          id: reminderStableId(booking.bookingId, _bookingIdBase, 1),
          title: "Toy pickup today",
          body: pickupText != null && pickupText.isNotEmpty
              ? "Pick up $toy ($pickupText) at the library."
              : "Pick up $toy at the library today.",
          when: morningWhen,
        ),
      );
    }
  }

  for (final loan in loans) {
    if (!loan.isActive) continue;

    final dueDay = _dateOnly(loan.returnSessionDate);
    final toy = _toyLabel(loan.toyName, loan.toyId);
    final eveDay = dueDay.subtract(const Duration(days: 1));

    final returnEveWhen = _atLocalTime(eveDay, eveReminderHour, eveReminderMinute);
    if (_isFuture(returnEveWhen, clock)) {
      reminders.add(
        ScheduledReminder(
          id: reminderStableId(loan.loanId, _loanIdBase, 0),
          title: "Toy return tomorrow",
          body: "Return $toy on the next library session.",
          when: returnEveWhen,
        ),
      );
    }

    final dueMorningWhen =
        _atLocalTime(dueDay, pickupMorningHour, pickupMorningMinute);
    if (_isFuture(dueMorningWhen, clock)) {
      reminders.add(
        ScheduledReminder(
          id: reminderStableId(loan.loanId, _loanIdBase, 1),
          title: "Toy return due today",
          body: "Return $toy at the library today.",
          when: dueMorningWhen,
        ),
      );
    }

    if (isLoanOverdue(loan.dueDate, now: clock)) {
      final sessions = LibrarySessionTimes.upcomingSessionDays(
        from: clock,
        withinDays: overdueReminderHorizonDays,
      );
      var slot = 0;
      for (final sessionDay in sessions) {
        final eveDay = sessionDay.subtract(const Duration(days: 1));
        final eveWhen = _atLocalTime(eveDay, eveReminderHour, eveReminderMinute);
        if (!_isFuture(eveWhen, clock)) continue;
        reminders.add(
          ScheduledReminder(
            id: reminderStableId(loan.loanId, _loanIdBase, 10 + slot),
            title: "Toy overdue",
            body: "Return $toy at tomorrow's library session.",
            when: eveWhen,
          ),
        );
        slot++;
      }
    }
  }

  final byId = <int, ScheduledReminder>{};
  for (final reminder in reminders) {
    byId[reminder.id] = reminder;
  }
  return byId.values.toList();
}
