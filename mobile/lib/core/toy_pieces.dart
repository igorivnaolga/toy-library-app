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
