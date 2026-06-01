import "../../core/toy_pieces.dart";
import "../bookings/booking_models.dart";

/// Loan row from `/api/v1/loans/me` and loan mutation endpoints.
class LoanItem {
  const LoanItem({
    required this.loanId,
    required this.userId,
    required this.toyId,
    required this.status,
    required this.checkedOutAt,
    required this.dueDate,
    required this.renewalCount,
    required this.isOverdue,
    this.toyName,
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
  final String? bookingId;
  final String status;
  final DateTime checkedOutAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final int renewalCount;
  final int? maxRenewals;
  final bool isOverdue;
  final int? renewalsRemaining;
  final String? memberName;
  final int? toyTotalPieces;
  final int? toyMissingPieces;

  bool get isActive => status.toLowerCase() == "active";
  bool get isReturned => status.toLowerCase() == "returned";

  bool get canRenew =>
      isActive && !isOverdue && (renewalsRemaining ?? 0) > 0;

  factory LoanItem.fromJson(Map<String, dynamic> json) {
    final due = parseApiDate(json["due_date"]);
    if (due == null) {
      throw FormatException("Invalid due_date: ${json["due_date"]}");
    }
    return LoanItem(
      loanId: json["loan_id"]?.toString() ?? "",
      userId: json["user_id"]?.toString() ?? "",
      toyId: json["toy_id"]?.toString() ?? "",
      toyName: json["toy_name"]?.toString(),
      bookingId: json["booking_id"]?.toString(),
      status: json["status"]?.toString() ?? "unknown",
      checkedOutAt: DateTime.parse(json["checked_out_at"] as String),
      dueDate: due,
      returnedAt: json["returned_at"] == null
          ? null
          : DateTime.tryParse(json["returned_at"].toString()),
      renewalCount: (json["renewal_count"] as num?)?.toInt() ?? 0,
      maxRenewals: (json["max_renewals"] as num?)?.toInt(),
      isOverdue: json["is_overdue"] == true,
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

  String get statusLabel {
    if (isOverdue && isActive) {
      return "Overdue";
    }
    switch (status.toLowerCase()) {
      case "active":
        return "On loan";
      case "returned":
        return "Returned";
      default:
        return status;
    }
  }

  String get listSubtitle {
    if (isReturned && returnedAt != null) {
      return "Returned ${formatDisplayDate(returnedAt!)}";
    }
    final parts = <String>["Due ${formatDisplayDate(dueDate)}"];
    if (isOverdue) {
      parts.add("Overdue");
    }
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
    return parts.join(" · ");
  }

  String get memberLabel {
    if (memberName != null && memberName!.isNotEmpty) {
      return memberName!;
    }
    return "Member";
  }

  String get deskSubtitle => "$memberLabel · $listSubtitle";
}

class LoanSections {
  const LoanSections({
    required this.active,
    required this.returned,
  });

  final List<LoanItem> active;
  final List<LoanItem> returned;
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
  sortLoansList(active);
  sortLoansList(returned);
  return LoanSections(active: active, returned: returned);
}

void sortLoansList(List<LoanItem> items) {
  items.sort((a, b) {
    if (a.isActive && b.isActive) {
      final overdueOrder = (b.isOverdue ? 1 : 0).compareTo(a.isOverdue ? 1 : 0);
      if (overdueOrder != 0) {
        return overdueOrder;
      }
      return a.dueDate.compareTo(b.dueDate);
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
