/// DTOs aligned with FastAPI `ToyOut` / `CategoryOut` (snake_case JSON keys).
library;

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
    this.manufacturer,
    this.description,
    this.photoFile,
  });

  final String toyId;
  final String name;
  final String? category;
  final String? ageRange;
  final String? status;
  final String? manufacturer;
  final String? description;
  final String? photoFile;

  factory ToyItem.fromJson(Map<String, dynamic> json) {
    return ToyItem(
      toyId: json["toy_id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      category: json["category"] as String?,
      ageRange: json["age_range"] as String?,
      status: json["status"] as String?,
      manufacturer: json["manufacturer"] as String?,
      description: json["description"] as String?,
      photoFile: json["photo_file"] as String?,
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
