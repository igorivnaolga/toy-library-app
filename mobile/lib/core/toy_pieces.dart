/// Labels for toy set piece counts shown on cards and at check-in.
String formatToyPiecesSummary({
  int? totalPieces,
  int? missingPieces,
}) {
  if (totalPieces == null && missingPieces == null) {
    return "";
  }

  final parts = <String>[];
  if (totalPieces != null) {
    final label = totalPieces == 1 ? "piece" : "pieces";
    parts.add("$totalPieces $label");
  }
  if (missingPieces != null && missingPieces > 0) {
    parts.add("$missingPieces missing");
  }
  return parts.join(" · ");
}

bool hasToyPiecesInfo({int? totalPieces, int? missingPieces}) {
  return totalPieces != null || (missingPieces != null && missingPieces > 0);
}

/// One SETLS piece line returned for admin/volunteer toy detail.
class ToyPieceLine {
  const ToyPieceLine({
    required this.name,
    required this.quantity,
    this.missing = 0,
  });

  final String name;
  final int quantity;
  final int missing;

  factory ToyPieceLine.fromJson(Map<String, dynamic> json) {
    return ToyPieceLine(
      name: json["name"]?.toString() ?? "",
      quantity: (json["quantity"] as num?)?.toInt() ?? 0,
      missing: (json["missing"] as num?)?.toInt() ?? 0,
    );
  }

  bool get isMissing => missing > 0;

  String get displayLabel => "$quantity $name";

  String get missingBadgeLabel {
    if (missing <= 0) return "";
    if (missing >= quantity) return "Missing";
    return "$missing missing";
  }

  ToyPieceLine copyWith({
    String? name,
    int? quantity,
    int? missing,
  }) {
    return ToyPieceLine(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      missing: missing ?? this.missing,
    );
  }

  Map<String, dynamic> toJson() => {
        "name": name,
        "quantity": quantity,
        "missing": missing,
      };
}

List<ToyPieceLine> parseToyPieceLines(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => ToyPieceLine.fromJson(Map<String, dynamic>.from(item)))
      .where((line) => line.name.isNotEmpty && line.quantity > 0)
      .toList();
}
