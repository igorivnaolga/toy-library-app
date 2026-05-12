import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "catalog_models.dart";

/// Holds catalog list state: categories, paged toys, filters, and load errors.
class CatalogController extends ChangeNotifier {
  CatalogController(this._client);

  final BackendClient _client;

  static const int _pageSize = 20;

  List<CategoryItem> categories = [];
  List<ToyItem> toys = [];
  bool loading = false;
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
    error = null;
    notifyListeners();
    try {
      await _loadCategories();
      await _fetchToyPage(reset: true);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> setSearchQuery(String value) async {
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
    if (!hasNext || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fetchToyPage(reset: false);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<ToyItem> fetchToy(String toyId) async {
    final json = await _client.getJson("/api/v1/toys/$toyId");
    return ToyItem.fromJson(json);
  }

  Future<void> _reloadToysOnly() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fetchToyPage(reset: true);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
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

  Future<void> _fetchToyPage({required bool reset}) async {
    if (reset) {
      _nextToyPage = 1;
      toys = [];
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
