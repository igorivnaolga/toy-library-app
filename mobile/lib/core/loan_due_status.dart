import "../features/duty/duty_session_models.dart";

DateTime loanDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime firstSessionOnOrAfter(DateTime dueDate) {
  var probe = loanDateOnly(dueDate);
  for (var i = 0; i < 366; i++) {
    if (LibrarySessionTimes.isSessionDay(probe)) {
      return probe;
    }
    probe = probe.add(const Duration(days: 1));
  }
  return probe;
}

DateTime loanReturnDeadline(DateTime dueDate) {
  final sessionDay = firstSessionOnOrAfter(dueDate);
  final times = LibrarySessionTimes.forDate(sessionDay);
  if (times == null) {
    return sessionDay.add(const Duration(days: 1));
  }
  final parts = times.end.split(":");
  return DateTime(
    sessionDay.year,
    sessionDay.month,
    sessionDay.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
}

bool isLoanOverdue(DateTime dueDate, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  return !clock.isBefore(loanReturnDeadline(dueDate));
}

bool isLoanDueToday(DateTime dueDate, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final sessionDay = firstSessionOnOrAfter(dueDate);
  if (loanDateOnly(sessionDay) != loanDateOnly(clock)) {
    return false;
  }
  return !isLoanOverdue(dueDate, now: clock);
}
