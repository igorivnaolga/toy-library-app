import "../../core/loan_due_status.dart";
import "../../core/toy_pieces.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_session_models.dart";

/// Loan row from `/api/v1/loans/me` and loan mutation endpoints.
class LoanItem {
  const LoanItem({
    required this.loanId,
    required this.userId,
    required this.toyId,
    required this.status,
    required this.checkedOutAt,
    required this.dueDate,
    required this.returnSessionDate,
    required this.renewalCount,
    required this.isOverdue,
    this.isDueToday = false,
    this.toyName,
    this.photoFile,
    this.bookingId,
    this.returnedAt,
    this.maxRenewals,
    this.renewalsRemaining,
    this.memberName,
    this.toyTotalPieces,
    this.toyMissingPieces,
  });

  final String loanId;
  final String userId;
  final String toyId;
  final String? toyName;
  final String? photoFile;
  final String? bookingId;
  final String status;
  final DateTime checkedOutAt;
  final DateTime dueDate;
  final DateTime returnSessionDate;
  final DateTime? returnedAt;
  final int renewalCount;
  final int? maxRenewals;
  final bool isOverdue;
  final bool isDueToday;
  final int? renewalsRemaining;
  final String? memberName;
  final int? toyTotalPieces;
  final int? toyMissingPieces;

  bool get isActive => status.toLowerCase() == "active";
  bool get isReturned => status.toLowerCase() == "returned";

  bool get effectiveIsOverdue =>
      isActive && (isOverdue || isLoanOverdue(dueDate));

  bool get effectiveIsDueToday =>
      isActive &&
      !effectiveIsOverdue &&
      (isDueToday || isLoanDueToday(dueDate));

  String get returnDateLabel => formatSessionDate(returnSessionDate);

  bool get canRenew =>
      isActive && !effectiveIsOverdue && (renewalsRemaining ?? 0) > 0;

  factory LoanItem.fromJson(Map<String, dynamic> json) {
    final due = parseApiDate(json["due_date"]);
    if (due == null) {
      throw FormatException("Invalid due_date: ${json["due_date"]}");
    }
    final returnSession =
        parseApiDate(json["return_session_date"]) ?? firstSessionOnOrAfter(due);
    return LoanItem(
      loanId: json["loan_id"]?.toString() ?? "",
      userId: json["user_id"]?.toString() ?? "",
      toyId: json["toy_id"]?.toString() ?? "",
      toyName: json["toy_name"]?.toString(),
      photoFile: json["photo_file"]?.toString(),
      bookingId: json["booking_id"]?.toString(),
      status: json["status"]?.toString() ?? "unknown",
      checkedOutAt: DateTime.parse(json["checked_out_at"] as String),
      dueDate: due,
      returnSessionDate: returnSession,
      returnedAt: json["returned_at"] == null
          ? null
          : DateTime.tryParse(json["returned_at"].toString()),
      renewalCount: (json["renewal_count"] as num?)?.toInt() ?? 0,
      maxRenewals: (json["max_renewals"] as num?)?.toInt(),
      isOverdue: json["is_overdue"] == true,
      isDueToday: json["is_due_today"] == true,
      renewalsRemaining: (json["renewals_remaining"] as num?)?.toInt(),
      memberName: json["member_name"]?.toString(),
      toyTotalPieces: (json["toy_total_pieces"] as num?)?.toInt(),
      toyMissingPieces: (json["toy_missing_pieces"] as num?)?.toInt(),
    );
  }

  String get piecesSummary => formatToyPiecesSummary(
        totalPieces: toyTotalPieces,
        missingPieces: toyMissingPieces,
      );

  String get listSubtitle {
    if (isReturned && returnedAt != null) {
      return "Returned ${formatDisplayDate(returnedAt!)}";
    }
    final parts = <String>[
      if (effectiveIsDueToday)
        "Due today"
      else
        "Due $returnDateLabel",
    ];
    if (effectiveIsOverdue) {
      parts.add("Overdue");
    }
    parts.addAll(_renewalSubtitleParts);
    return parts.join(" · ");
  }

  /// Subtitle for tiles inside a due-date group (due date is in the section header).
  String get groupedListSubtitle {
    if (isReturned && returnedAt != null) {
      return "Returned ${formatDisplayDate(returnedAt!)}";
    }
    return _renewalSubtitleParts.join(" · ");
  }

  List<String> get _renewalSubtitleParts {
    final parts = <String>[];
    if (renewalCount > 0) {
      parts.add(
        renewalCount == 1 ? "Renewed once" : "Renewed $renewalCount times",
      );
    }
    if (renewalsRemaining != null) {
      parts.add(
        renewalsRemaining! > 0
            ? "$renewalsRemaining renewals left"
            : "No renewals left",
      );
    }
    return parts;
  }

  String get memberLabel {
    if (memberName != null && memberName!.isNotEmpty) {
      return memberName!;
    }
    return "Member";
  }

  String get deskSubtitle => "$memberLabel · $listSubtitle";
}

List<LoanItem> parseLoanList(Map<String, dynamic> json) {
  return parseLoanItemsList(json["data"]);
}

List<LoanItem> parseLoanItemsList(Object? raw) {
  if (raw is! List) {
    return [];
  }
  final items = <LoanItem>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    try {
      items.add(LoanItem.fromJson(Map<String, dynamic>.from(entry)));
    } catch (_) {
      // Skip malformed rows from partial API responses.
    }
  }
  sortLoansList(items);
  return items;
}

class LoanSections {
  const LoanSections({
    required this.activeByDueDate,
    required this.returned,
  });

  final List<LoanDueDateGroup> activeByDueDate;
  final List<LoanItem> returned;
}

class LoanDueDateGroup {
  const LoanDueDateGroup({
    required this.dueDate,
    required this.loans,
  });

  final DateTime dueDate;
  final List<LoanItem> loans;

  bool get isOverdue => loans.any((loan) => loan.effectiveIsOverdue);

  bool get isDueToday =>
      !isOverdue && loans.any((loan) => loan.effectiveIsDueToday);
}

LoanSections groupLoansBySection(List<LoanItem> items) {
  final active = <LoanItem>[];
  final returned = <LoanItem>[];
  for (final item in items) {
    if (item.isActive) {
      active.add(item);
    } else {
      returned.add(item);
    }
  }
  sortLoansList(returned);
  return LoanSections(
    activeByDueDate: groupActiveLoansByDueDate(active),
    returned: returned,
  );
}

List<LoanDueDateGroup> groupActiveLoansByDueDate(List<LoanItem> active) {
  final byDay = <DateTime, List<LoanItem>>{};
  for (final item in active) {
    final day = _dateOnly(item.returnSessionDate);
    byDay.putIfAbsent(day, () => []).add(item);
  }

  final groups = byDay.entries
      .map(
        (entry) => LoanDueDateGroup(
          dueDate: entry.key,
          loans: List<LoanItem>.from(entry.value)
            ..sort(
              (a, b) => (a.toyName ?? a.toyId)
                  .toLowerCase()
                  .compareTo((b.toyName ?? b.toyId).toLowerCase()),
            ),
        ),
      )
      .toList();

  groups.sort((a, b) {
    if (a.isOverdue != b.isOverdue) {
      return a.isOverdue ? -1 : 1;
    }
    return a.dueDate.compareTo(b.dueDate);
  });
  return groups;
}

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

void sortLoansList(List<LoanItem> items) {
  items.sort((a, b) {
    if (a.isActive && b.isActive) {
      final overdueOrder =
          (b.effectiveIsOverdue ? 1 : 0).compareTo(a.effectiveIsOverdue ? 1 : 0);
      if (overdueOrder != 0) {
        return overdueOrder;
      }
      return a.returnSessionDate.compareTo(b.returnSessionDate);
    }
    final aTime = a.returnedAt ?? a.checkedOutAt;
    final bTime = b.returnedAt ?? b.checkedOutAt;
    return bTime.compareTo(aTime);
  });
}

String formatDisplayDate(DateTime date) {
  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return "${date.day} ${months[date.month - 1]} ${date.year}";
}

/// Desk check-in search: optionally member name, toy name, toy id, or loan id.
List<LoanItem> filterCheckInLoans(
  List<LoanItem> loans, {
  String query = "",
  String? memberUserId,
  DateTime? dueDate,
  bool includeMemberInSearch = true,
}) {
  var result = loans;
  final memberId = memberUserId?.trim();
  if (memberId != null && memberId.isNotEmpty) {
    result = result.where((loan) => loan.userId == memberId).toList();
  }
  if (dueDate != null) {
    final key = _dateOnly(dueDate);
    result = result
        .where((loan) => _dateOnly(loan.returnSessionDate) == key)
        .toList();
  }
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return result;
  return result.where((loan) {
    final toyName = (loan.toyName ?? "").toLowerCase();
    final matchesToy = toyName.contains(q) ||
        loan.toyId.toLowerCase().contains(q) ||
        loan.loanId.toLowerCase().contains(q);
    if (!includeMemberInSearch) return matchesToy;
    final member = (loan.memberName ?? "").toLowerCase();
    return matchesToy || member.contains(q);
  }).toList();
}
