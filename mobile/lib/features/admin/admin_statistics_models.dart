import "../payments/payment_models.dart";

class StatsOverview {
  const StatsOverview({
    required this.period,
    required this.periodLabel,
    required this.totalMembers,
    required this.newMembers,
    required this.bookings,
    required this.checkouts,
    required this.returns,
    required this.revenueCents,
    required this.revenueCashCents,
    required this.revenueEftposCents,
    required this.revenueBankCents,
    required this.pendingRevenueCents,
    required this.catalogToys,
  });

  final String period;
  final String periodLabel;
  final int totalMembers;
  final int newMembers;
  final int bookings;
  final int checkouts;
  final int returns;
  final int revenueCents;
  final int revenueCashCents;
  final int revenueEftposCents;
  final int revenueBankCents;
  final int pendingRevenueCents;
  final int catalogToys;

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    return StatsOverview(
      period: json["period"]?.toString() ?? "month",
      periodLabel: json["period_label"]?.toString() ?? "",
      totalMembers: _asInt(json["total_members"]),
      newMembers: _asInt(json["new_members"]),
      bookings: _asInt(json["bookings"]),
      checkouts: _asInt(json["checkouts"]),
      returns: _asInt(json["returns"]),
      revenueCents: _asInt(json["revenue_cents"]),
      revenueCashCents: _asInt(json["revenue_cash_cents"]),
      revenueEftposCents: _asInt(json["revenue_eftpos_cents"]),
      revenueBankCents: _asInt(json["revenue_bank_cents"]),
      pendingRevenueCents: _asInt(json["pending_revenue_cents"]),
      catalogToys: _asInt(json["catalog_toys"]),
    );
  }

  StatsOverview copyWith({int? pendingRevenueCents}) {
    return StatsOverview(
      period: period,
      periodLabel: periodLabel,
      totalMembers: totalMembers,
      newMembers: newMembers,
      bookings: bookings,
      checkouts: checkouts,
      returns: returns,
      revenueCents: revenueCents,
      revenueCashCents: revenueCashCents,
      revenueEftposCents: revenueEftposCents,
      revenueBankCents: revenueBankCents,
      pendingRevenueCents: pendingRevenueCents ?? this.pendingRevenueCents,
      catalogToys: catalogToys,
    );
  }
}

class StatsCountRow {
  const StatsCountRow({required this.label, required this.count});

  final String label;
  final int count;

  factory StatsCountRow.fromJson(Map<String, dynamic> json) {
    return StatsCountRow(
      label: json["label"]?.toString() ?? "",
      count: _asInt(json["count"]),
    );
  }
}

class StatsBreakdown {
  const StatsBreakdown({
    required this.periodLabel,
    required this.groupBy,
    required this.data,
  });

  final String periodLabel;
  final String groupBy;
  final List<StatsCountRow> data;

  factory StatsBreakdown.fromJson(Map<String, dynamic> json) {
    final raw = json["data"];
    return StatsBreakdown(
      periodLabel: json["period_label"]?.toString() ?? "",
      groupBy: json["group_by"]?.toString() ?? "category",
      data: raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(StatsCountRow.fromJson)
              .toList()
          : const [],
    );
  }
}

class StatsCatalog {
  const StatsCatalog({
    required this.byCategory,
    required this.byStatus,
  });

  final List<StatsCountRow> byCategory;
  final List<StatsCountRow> byStatus;

  factory StatsCatalog.fromJson(Map<String, dynamic> json) {
    List<StatsCountRow> parseList(String key) {
      final raw = json[key];
      if (raw is! List<dynamic>) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(StatsCountRow.fromJson)
          .toList();
    }

    return StatsCatalog(
      byCategory: parseList("by_category"),
      byStatus: parseList("by_status"),
    );
  }
}

class ToyPopularityRow {
  const ToyPopularityRow({
    required this.toyId,
    required this.name,
    required this.count,
  });

  final String toyId;
  final String name;
  final int count;

  factory ToyPopularityRow.fromJson(Map<String, dynamic> json) {
    return ToyPopularityRow(
      toyId: json["toy_id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      count: _asInt(json["count"]),
    );
  }
}

class ToyPopularity {
  const ToyPopularity({
    required this.periodLabel,
    required this.data,
  });

  final String periodLabel;
  final List<ToyPopularityRow> data;

  factory ToyPopularity.fromJson(Map<String, dynamic> json) {
    final raw = json["data"];
    return ToyPopularity(
      periodLabel: json["period_label"]?.toString() ?? "",
      data: raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(ToyPopularityRow.fromJson)
              .toList()
          : const [],
    );
  }
}

class StatsHeardAbout {
  const StatsHeardAbout({
    required this.periodLabel,
    required this.totalResponses,
    required this.data,
  });

  final String periodLabel;
  final int totalResponses;
  final List<StatsCountRow> data;

  factory StatsHeardAbout.fromJson(Map<String, dynamic> json) {
    final raw = json["data"];
    return StatsHeardAbout(
      periodLabel: json["period_label"]?.toString() ?? "",
      totalResponses: _asInt(json["total_responses"]),
      data: raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(StatsCountRow.fromJson)
              .toList()
          : const [],
    );
  }
}

class StatsPendingMember {
  const StatsPendingMember({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.pendingCents,
  });

  final String userId;
  final String email;
  final String fullName;
  final int pendingCents;

  String get displayName =>
      fullName.trim().isNotEmpty
          ? fullName.trim()
          : (email.trim().isNotEmpty ? email.trim() : userId);

  factory StatsPendingMember.fromJson(Map<String, dynamic> json) {
    return StatsPendingMember(
      userId: json["user_id"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
      pendingCents: _asInt(json["pending_cents"]),
    );
  }
}

class StatsPendingMembers {
  const StatsPendingMembers({
    required this.periodLabel,
    required this.totalPendingCents,
    required this.data,
  });

  final String periodLabel;
  final int totalPendingCents;
  final List<StatsPendingMember> data;

  factory StatsPendingMembers.fromJson(Map<String, dynamic> json) {
    final raw = json["data"];
    return StatsPendingMembers(
      periodLabel: json["period_label"]?.toString() ?? "",
      totalPendingCents: _asInt(json["total_pending_cents"]),
      data: raw is List<dynamic>
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(StatsPendingMember.fromJson)
              .toList()
          : const [],
    );
  }

  /// Amount to show in UI — sum of listed members so text matches each row.
  int get displayTotalCents {
    if (data.isEmpty) return 0;
    return data.fold<int>(0, (sum, row) => sum + row.pendingCents);
  }
}

String shortCategoryLabel(String label, {int maxLen = 14}) {
  final trimmed = label.trim();
  if (trimmed.length <= maxLen) return trimmed;
  final colon = trimmed.indexOf(":");
  if (colon > 0 && colon < maxLen) {
    return trimmed.substring(0, colon).trim();
  }
  return "${trimmed.substring(0, maxLen - 1)}…";
}

/// Compact x-axis label: category code before ":", else truncated name.
String chartAxisLabel(String label, {int maxLen = 9}) {
  final trimmed = label.trim();
  final colon = trimmed.indexOf(":");
  if (colon > 0) {
    final head = trimmed.substring(0, colon).trim();
    return head.length <= maxLen ? head : "${head.substring(0, maxLen - 1)}…";
  }
  return shortCategoryLabel(trimmed, maxLen: maxLen);
}

/// Display / type format for session dates (dd/mm/yyyy).
String formatSessionInputDate(DateTime date) {
  final d = date.day.toString().padLeft(2, "0");
  final m = date.month.toString().padLeft(2, "0");
  return "$d/$m/${date.year}";
}

/// Parse typed session date (dd/mm/yyyy).
DateTime? parseSessionDateInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final slash = trimmed.split("/");
  if (slash.length == 3) {
    final day = int.tryParse(slash[0].trim());
    final month = int.tryParse(slash[1].trim());
    var year = int.tryParse(slash[2].trim());
    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000;
      try {
        return DateTime(year, month, day);
      } on ArgumentError {
        return null;
      }
    }
  }
  return null;
}

String statsGroupByTitle(String groupBy) {
  switch (groupBy) {
    case "age":
      return "age range";
    case "manufacturer":
      return "maker";
    default:
      return "category";
  }
}

int niceChartMaxY(int maxCount) {
  if (maxCount <= 0) return 5;
  if (maxCount <= 5) return 5;
  if (maxCount <= 10) return 10;
  if (maxCount <= 25) return ((maxCount + 4) ~/ 5) * 5;
  if (maxCount <= 50) return ((maxCount + 9) ~/ 10) * 10;
  return ((maxCount + 19) ~/ 20) * 20;
}

int niceChartYInterval(int maxY) {
  if (maxY <= 10) return 2;
  if (maxY <= 25) return 5;
  if (maxY <= 50) return 10;
  return 20;
}

String formatRevenueCents(int cents) => formatDueCents(cents);

class RevenueBreakdownRow {
  const RevenueBreakdownRow({required this.label, required this.cents});

  final String label;
  final int cents;
}

List<RevenueBreakdownRow> revenueBreakdownRows(StatsOverview overview) {
  return [
    RevenueBreakdownRow(
      label: "Cash",
      cents: overview.revenueCashCents,
    ),
    RevenueBreakdownRow(
      label: "EFTPOS",
      cents: overview.revenueEftposCents,
    ),
    RevenueBreakdownRow(
      label: "Bank transfer",
      cents: overview.revenueBankCents,
    ),
  ];
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? "") ?? 0;
}
