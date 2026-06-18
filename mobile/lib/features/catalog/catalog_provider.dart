import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../../core/user_friendly_error.dart";
import "../../core/toy_pieces.dart";
import "catalog_models.dart";

/// Holds catalog list state: categories, paged toys, filters, and load errors.
class CatalogController extends ChangeNotifier {
  CatalogController(this._client);

  final BackendClient _client;

  static const int _pageSize = 20;

  List<CategoryItem> categories = [];
  List<String> ageRangeOptions = [];
  List<String> manufacturerOptions = [];
  List<ToyItem> toys = [];
  bool loading = false;
  bool loadingMore = false;
  String? error;
  String searchQuery = "";
  String? categoryFilterLabel;
  String? ageRangeFilter;
  String? availabilityFilter;
  bool hasNext = false;
  int total = 0;

  int _nextToyPage = 1;

  Future<void> loadInitial() async {
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      await _loadCategories();
      await _loadToysMeta();
      await _fetchToyPage(reset: true);
      error = null;
    } on ApiException catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  /// Loads category / meta lists for admin toy forms without reloading toys.
  Future<void> loadFormOptions() async {
    try {
      await _loadCategories();
      await _loadToysMeta();
      _fillFormOptionsFromLoadedToys();
      error = null;
    } on ApiException catch (e) {
      _fillFormOptionsFromLoadedToys();
      error = e.message;
    } catch (e) {
      _fillFormOptionsFromLoadedToys();
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } finally {
      notifyListeners();
    }
  }

  void _fillFormOptionsFromLoadedToys() {
    if (ageRangeOptions.isEmpty) {
      ageRangeOptions = _distinctSorted(
        toys.map((toy) => toy.ageRange).whereType<String>(),
      );
    }
    if (manufacturerOptions.isEmpty) {
      manufacturerOptions = _distinctSorted(
        toys.map((toy) => toy.manufacturer).whereType<String>(),
      );
    }
  }

  List<String> _distinctSorted(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) out.add(value);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Future<CategoryItem> updateCategoryLabel({
    required String code,
    required String label,
  }) async {
    final oldLabel = categories
        .where((item) => item.code == code)
        .map((item) => item.label)
        .firstOrNull;
    final json = await _client.patchJson(
      "/api/v1/admin/categories/${Uri.encodeComponent(code)}",
      {"label": label.trim()},
    );
    final updated = CategoryItem.fromJson(json);
    categories = [
      for (final item in categories)
        if (item.code == updated.code) updated else item,
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (oldLabel != null) {
      final oldKey = oldLabel.trim().toLowerCase();
      toys = [
        for (final toy in toys)
          if (toy.category?.trim().toLowerCase() == oldKey)
            ToyItem(
              toyId: toy.toyId,
              name: toy.name,
              category: updated.label,
              ageRange: toy.ageRange,
              status: toy.status,
              availability: toy.availability,
              manufacturer: toy.manufacturer,
              description: toy.description,
              photoFile: toy.photoFile,
              totalPieces: toy.totalPieces,
              missingPieces: toy.missingPieces,
              missingPiecesDetail: toy.missingPiecesDetail,
              rentalPriceCents: toy.rentalPriceCents,
              pieceLines: toy.pieceLines,
            )
          else
            toy,
      ];
    }
    notifyListeners();
    return updated;
  }

  CategoryItem? categoryMatchingLabel(String? label) {
    final needle = label?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return null;
    for (final category in categories) {
      if (category.label.trim().toLowerCase() == needle) {
        return category;
      }
    }
    return null;
  }

  ToyItem? toyWithExactName(String name, {String? excludeToyId}) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final toy in toys) {
      if (excludeToyId != null && toy.toyId == excludeToyId) continue;
      if (toy.name.trim().toLowerCase() == key) return toy;
    }
    return null;
  }

  Future<ToyItem?> findToyByExactName(
    String name, {
    String? excludeToyId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final local = toyWithExactName(trimmed, excludeToyId: excludeToyId);
    if (local != null) return local;

    final json = await _client.getJson("/api/v1/toys", {
      "q": trimmed,
      "page": "1",
      "limit": "50",
    });
    final data = json["data"] as List<dynamic>? ?? [];
    final key = trimmed.toLowerCase();
    for (final raw in data) {
      final toy = ToyItem.fromJson(raw as Map<String, dynamic>);
      if (excludeToyId != null && toy.toyId == excludeToyId) continue;
      if (toy.name.trim().toLowerCase() == key) return toy;
    }
    return null;
  }

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      (categoryFilterLabel != null && categoryFilterLabel!.isNotEmpty) ||
      (ageRangeFilter != null && ageRangeFilter!.isNotEmpty) ||
      (availabilityFilter != null && availabilityFilter!.isNotEmpty);

  Future<void> clearAllFilters() async {
    searchQuery = "";
    categoryFilterLabel = null;
    ageRangeFilter = null;
    availabilityFilter = null;
    await _reloadToysOnly();
  }

  Future<void> setSearchQuery(String value) async {
    final next = value.trim();
    if (next == searchQuery.trim()) return;
    searchQuery = value;
    await _reloadToysOnly();
  }

  Future<void> setCategoryFilter(String? label) async {
    categoryFilterLabel = label;
    await _reloadToysOnly();
  }

  Future<void> setAgeRangeFilter(String? value) async {
    ageRangeFilter = value;
    await _reloadToysOnly();
  }

  Future<void> setAvailabilityFilter(String? value) async {
    availabilityFilter = value;
    await _reloadToysOnly();
  }

  Future<void> loadMore() async {
    if (!hasNext || loading || loadingMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      await _fetchToyPage(reset: false);
      error = null;
    } on ApiException catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<ToyItem> fetchToy(String toyId) async {
    final json = await _client.getJson("/api/v1/toys/$toyId");
    return ToyItem.fromJson(json);
  }

  ToyItem? cachedToy(String toyId) {
    for (final item in toys) {
      if (item.toyId == toyId) {
        return item;
      }
    }
    return null;
  }

  /// Updates one cached toy after a booking change without reloading the list.
  Future<void> updateToyInCatalog(String toyId) async {
    try {
      final updated = await fetchToy(toyId);
      final index = toys.indexWhere((item) => item.toyId == toyId);
      if (index < 0) return;
      toys = [
        for (var i = 0; i < toys.length; i++)
          if (i == index) updated else toys[i],
      ];
      notifyListeners();
    } catch (_) {
      // Leave the cached row as-is; the next pull-to-refresh will reconcile.
    }
  }

  Future<ToyItem> updateToyPieces(
    String toyId, {
    required List<ToyPieceLine> pieceLines,
  }) async {
    final body = {
      "piece_lines": pieceLines.map((line) => line.toJson()).toList(),
    };
    final json = await _client.patchJson("/api/v1/toys/$toyId/pieces", body);
    return ToyItem.fromJson(json);
  }

  Future<ToyItem> uploadToyPhoto(String toyId, String filePath) async {
    final json = await _client.postMultipartImage(
      "/api/v1/admin/toys/$toyId/photo",
      fileField: "image",
      filePath: filePath,
    );
    return ToyItem.fromJson(json);
  }

  Future<ToyItem> createToy({
    required String name,
    String? category,
    String? ageRange,
    String? status,
    String? manufacturer,
    String? description,
    int? totalPieces,
    int? missingPieces,
    int? rentalPriceCents,
  }) async {
    final body = <String, dynamic>{
      "name": name,
      if (category != null && category.isNotEmpty) "category": category,
      if (ageRange != null && ageRange.isNotEmpty) "age_range": ageRange,
      if (status != null && status.isNotEmpty) "status": status,
      if (manufacturer != null && manufacturer.isNotEmpty)
        "manufacturer": manufacturer,
      if (description != null && description.isNotEmpty)
        "description": description,
      if (totalPieces != null) "total_pieces": totalPieces,
      if (missingPieces != null) "missing_pieces": missingPieces,
      if (rentalPriceCents != null) "rental_price_cents": rentalPriceCents,
    };
    final json = await _client.postJson("/api/v1/admin/toys", body);
    final created = ToyItem.fromJson(json);
    toys = [created, ...toys];
    total += 1;
    notifyListeners();
    return created;
  }

  Future<ToyItem> updateToy(
    String toyId, {
    required String name,
    String? category,
    String? ageRange,
    String? status,
    String? manufacturer,
    String? description,
    int? totalPieces,
    int? missingPieces,
    int? rentalPriceCents,
  }) async {
    final body = <String, dynamic>{
      "name": name,
      if (category != null) "category": category,
      if (ageRange != null) "age_range": ageRange,
      if (status != null) "status": status,
      if (manufacturer != null) "manufacturer": manufacturer,
      if (description != null) "description": description,
      if (totalPieces != null) "total_pieces": totalPieces,
      if (missingPieces != null) "missing_pieces": missingPieces,
      if (rentalPriceCents != null) "rental_price_cents": rentalPriceCents,
    };
    final json =
        await _client.patchJson("/api/v1/admin/toys/$toyId", body);
    final updated = ToyItem.fromJson(json);
    toys = [
      for (final item in toys)
        if (item.toyId == toyId) updated else item,
    ];
    notifyListeners();
    return updated;
  }

  Future<void> deleteToy(String toyId, {bool notify = true}) async {
    await _client.deleteJson(
      "/api/v1/admin/toys/${Uri.encodeComponent(toyId)}",
    );
    toys = toys.where((item) => item.toyId != toyId).toList();
    if (total > 0) {
      total -= 1;
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _reloadToysOnly() async {
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      await _fetchToyPage(reset: true);
      error = null;
    } on ApiException catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } catch (e) {
      error = friendlyErrorMessage(
        e,
        fallback: "Couldn't load the catalog. Pull down to refresh.",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    final json = await _client.getJson("/api/v1/categories");
    final raw = json["data"] as List<dynamic>? ?? [];
    categories = raw
        .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
        .where((c) => c.label.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<void> _loadToysMeta() async {
    final json = await _client.getJson("/api/v1/toys/meta");
    final ageRaw = json["age_ranges"] as List<dynamic>? ?? [];
    ageRangeOptions =
        ageRaw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    final manufacturerRaw = json["manufacturers"] as List<dynamic>? ?? [];
    manufacturerOptions = manufacturerRaw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _fetchToyPage({required bool reset}) async {
    if (reset) {
      _nextToyPage = 1;
    }
    final query = <String, String>{
      "page": "$_nextToyPage",
      "limit": "$_pageSize",
    };
    final q = searchQuery.trim();
    if (q.isNotEmpty) {
      query["q"] = q;
    }
    final cat = categoryFilterLabel?.trim();
    if (cat != null && cat.isNotEmpty) {
      query["category"] = cat;
    }
    final ageRange = ageRangeFilter?.trim();
    if (ageRange != null && ageRange.isNotEmpty) {
      query["age_range"] = ageRange;
    }
    final availability = availabilityFilter?.trim();
    if (availability != null && availability.isNotEmpty) {
      query["availability"] = availability;
    }

    final json = await _client.getJson("/api/v1/toys", query);
    final data = json["data"] as List<dynamic>? ?? [];
    final meta =
        ToysListMeta.fromJson(json["meta"] as Map<String, dynamic>? ?? {});
    final batch =
        data.map((e) => ToyItem.fromJson(e as Map<String, dynamic>)).toList();
    toys = reset ? batch : [...toys, ...batch];
    hasNext = meta.hasNext;
    total = meta.total;
    if (meta.hasNext) {
      _nextToyPage = meta.page + 1;
    }
  }
}
