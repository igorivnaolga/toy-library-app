library;

import "../../core/toy_pieces.dart";

class CategoryItem {
  const CategoryItem({
    required this.code,
    required this.label,
    this.maxRenewals,
    this.reservable,
    this.toyCountCurrent,
    this.toyCountTotal,
    this.pct,
  });

  final String code;
  final String label;
  final int? maxRenewals;
  final bool? reservable;
  final int? toyCountCurrent;
  final int? toyCountTotal;
  final String? pct;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      code: json["code"] as String? ?? "",
      label: json["label"] as String? ?? "",
      maxRenewals: (json["max_renewals"] as num?)?.toInt(),
      reservable: json["reservable"] as bool?,
      toyCountCurrent: (json["toy_count_current"] as num?)?.toInt(),
      toyCountTotal: (json["toy_count_total"] as num?)?.toInt(),
      pct: json["pct"] as String?,
    );
  }
}

class ToyItem {
  const ToyItem({
    required this.toyId,
    required this.name,
    this.category,
    this.ageRange,
    this.status,
    this.availability = "unknown",
    this.manufacturer,
    this.description,
    this.photoFile,
    this.totalPieces,
    this.missingPieces,
    this.missingPiecesDetail,
    this.rentalPriceCents,
    this.pieceLines = const [],
    this.reservedByName,
    this.reservedByEmail,
    this.reservationPickupLabel,
    this.onLoanToName,
    this.onLoanToEmail,
    this.loanDueLabel,
    this.queueOpensLabel,
  });

  final String toyId;
  final String name;
  final String? category;
  final String? ageRange;
  final String? status;
  final String availability;
  final String? manufacturer;
  final String? description;
  final String? photoFile;
  final int? totalPieces;
  final int? missingPieces;
  final String? missingPiecesDetail;
  final int? rentalPriceCents;
  final List<ToyPieceLine> pieceLines;
  final String? reservedByName;
  final String? reservedByEmail;
  final String? reservationPickupLabel;
  final String? onLoanToName;
  final String? onLoanToEmail;
  final String? loanDueLabel;
  final String? queueOpensLabel;

  bool get hasAdminHolderInfo =>
      (reservedByName != null && reservedByName!.isNotEmpty) ||
      (onLoanToName != null && onLoanToName!.isNotEmpty);

  String? get rentalPriceLabel {
    final cents = rentalPriceCents;
    if (cents == null) return null;
    return "\$${(cents / 100).toStringAsFixed(2)}";
  }

  String get piecesSummary => formatToyPiecesSummary(
        totalPieces: totalPieces,
        missingPieces: missingPieces,
      );

  factory ToyItem.fromJson(Map<String, dynamic> json) {
    return ToyItem(
      toyId: json["toy_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      category: json["category"] as String?,
      ageRange: json["age_range"] as String?,
      status: json["status"] as String?,
      availability: json["availability"] as String? ?? "unknown",
      manufacturer: json["manufacturer"] as String?,
      description: json["description"] as String?,
      photoFile: json["photo_file"] as String?,
      totalPieces: (json["total_pieces"] as num?)?.toInt(),
      missingPieces: (json["missing_pieces"] as num?)?.toInt(),
      missingPiecesDetail: json["missing_pieces_detail"]?.toString(),
      rentalPriceCents: (json["rental_price_cents"] as num?)?.toInt(),
      pieceLines: parseToyPieceLines(json["piece_lines"]),
      reservedByName: json["reserved_by_name"]?.toString(),
      reservedByEmail: json["reserved_by_email"]?.toString(),
      reservationPickupLabel: json["reservation_pickup_label"]?.toString(),
      onLoanToName: json["on_loan_to_name"]?.toString(),
      onLoanToEmail: json["on_loan_to_email"]?.toString(),
      loanDueLabel: json["loan_due_label"]?.toString(),
      queueOpensLabel: json["queue_opens_label"]?.toString(),
    );
  }

  /// Lightweight row for instant detail navigation before the full fetch completes.
  factory ToyItem.preview({
    required String toyId,
    String? name,
    String? photoFile,
    String availability = "unknown",
    int? totalPieces,
    int? missingPieces,
  }) {
    final cleanedName = name?.trim();
    return ToyItem(
      toyId: toyId,
      name: cleanedName != null && cleanedName.isNotEmpty ? cleanedName : toyId,
      photoFile: photoFile,
      availability: availability,
      totalPieces: totalPieces,
      missingPieces: missingPieces,
    );
  }
}

class ToysListMeta {
  const ToysListMeta({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasNext,
  });

  final int page;
  final int limit;
  final int total;
  final bool hasNext;

  factory ToysListMeta.fromJson(Map<String, dynamic> json) {
    return ToysListMeta(
      page: (json["page"] as num?)?.toInt() ?? 1,
      limit: (json["limit"] as num?)?.toInt() ?? 20,
      total: (json["total"] as num?)?.toInt() ?? 0,
      hasNext: json["has_next"] as bool? ?? false,
    );
  }
}
