/// Advisory piece-count estimate from `POST /api/v1/desk/identify-pieces`.
class PieceEstimate {
  const PieceEstimate({
    required this.toyId,
    this.expectedTotal,
    this.estimatedCount,
    this.suggestedMissing,
    required this.confidence,
    required this.message,
    this.catalogTotal,
    this.learnedTotal,
    this.learnSamples = 0,
    this.referenceSource,
    this.layoutSimilarity,
  });

  final String toyId;
  final int? expectedTotal;
  final int? estimatedCount;
  final int? suggestedMissing;
  final double confidence;
  final String message;
  final int? catalogTotal;
  final int? learnedTotal;
  final int learnSamples;
  final String? referenceSource;
  final double? layoutSimilarity;

  factory PieceEstimate.fromJson(Map<String, dynamic> json) {
    return PieceEstimate(
      toyId: json["toy_id"]?.toString() ?? "",
      expectedTotal: (json["expected_total"] as num?)?.toInt(),
      estimatedCount: (json["estimated_count"] as num?)?.toInt(),
      suggestedMissing: (json["suggested_missing"] as num?)?.toInt(),
      confidence: (json["confidence"] as num?)?.toDouble() ?? 0,
      message: json["message"]?.toString() ?? "",
      catalogTotal: (json["catalog_total"] as num?)?.toInt(),
      learnedTotal: (json["learned_total"] as num?)?.toInt(),
      learnSamples: (json["learn_samples"] as num?)?.toInt() ?? 0,
      referenceSource: json["reference_source"]?.toString(),
      layoutSimilarity: (json["layout_similarity"] as num?)?.toDouble(),
    );
  }
}
