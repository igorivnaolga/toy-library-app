/// Advisory piece-count estimate from `POST /api/v1/desk/identify-pieces`.
class PieceEstimate {
  const PieceEstimate({
    required this.toyId,
    this.expectedTotal,
    this.estimatedCount,
    this.suggestedMissing,
    required this.confidence,
    required this.message,
  });

  final String toyId;
  final int? expectedTotal;
  final int? estimatedCount;
  final int? suggestedMissing;
  final double confidence;
  final String message;

  factory PieceEstimate.fromJson(Map<String, dynamic> json) {
    return PieceEstimate(
      toyId: json["toy_id"]?.toString() ?? "",
      expectedTotal: (json["expected_total"] as num?)?.toInt(),
      estimatedCount: (json["estimated_count"] as num?)?.toInt(),
      suggestedMissing: (json["suggested_missing"] as num?)?.toInt(),
      confidence: (json["confidence"] as num?)?.toDouble() ?? 0,
      message: json["message"]?.toString() ?? "",
    );
  }
}
