import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "catalog_provider.dart";
import "toy_detail_screen.dart";
import "toy_availability_badge.dart";
import "toy_photo_tile.dart";

/// Catalog: loads `GET /api/v1/categories` and paged `GET /api/v1/toys` via [CatalogController].
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const List<(String?, String)> _statusFilters = [
    (null, "All"),
    ("available", "Available"),
    ("on_loan", "On loan"),
    ("reserved", "Reserved"),
    ("unavailable", "Unavailable"),
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogController>();
    _searchController.text = catalog.searchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      catalog.loadInitial();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      context.read<CatalogController>().setSearchQuery("");
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<CatalogController>().setSearchQuery(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    context.read<CatalogController>().setSearchQuery("");
  }

  Future<void> _clearSearchAndFilters(CatalogController c) async {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    await c.clearAllFilters();
  }

  String _selectedLabel(List<(String?, String)> options, String? value) {
    for (final option in options) {
      if (option.$1 == value) return option.$2;
    }
    return value == null || value.isEmpty ? "All" : value;
  }

  List<(String?, String)> _ageOptions(CatalogController c) {
    return [
      (null, "All"),
      ...c.ageRangeOptions.map((s) => (s, s)),
    ];
  }

  Future<void> _showFilterSheet({
    required BuildContext context,
    required String title,
    required List<(String?, String)> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final (value, label) in options)
                ListTile(
                  title: Text(label),
                  trailing: selectedValue == value
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelected(value);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterButton({
    required BuildContext context,
    required String label,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final background = isActive ? kBrandYellow : colors.primaryContainer;
    const foreground = kBrandOnYellow;
    return Material(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    color: foreground,
                    height: 1.1,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 22,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Toy catalog"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: kBrandOnYellow),
              cursorColor: kBrandOnYellow,
              decoration: InputDecoration(
                hintText: "Search toys…",
                hintStyle: TextStyle(
                  color: kBrandOnYellow.withValues(alpha: 0.55),
                ),
                prefixIcon: const Icon(Icons.search, color: kBrandOnYellow),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: kBrandOnYellow),
                        onPressed: _clearSearch,
                        tooltip: "Clear search",
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBrandOnYellow, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                _scheduleSearch(value);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Consumer<CatalogController>(
            builder: (context, c, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.error != null && c.toys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        c.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _filterButton(
                            context: context,
                            label: c.categoryFilterLabel == null
                                ? "Category All"
                                : c.categoryFilterLabel!,
                            isActive: c.categoryFilterLabel != null,
                            onPressed: c.loading
                                ? null
                                : () {
                                    final options = <(String?, String)>[
                                      (null, "All"),
                                      ...c.categories.map(
                                          (cat) => (cat.label, cat.label)),
                                    ];
                                    _showFilterSheet(
                                      context: context,
                                      title: "Choose category",
                                      options: options,
                                      selectedValue: c.categoryFilterLabel,
                                      onSelected: context
                                          .read<CatalogController>()
                                          .setCategoryFilter,
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _filterButton(
                            context: context,
                            label:
                                "Age ${_selectedLabel(_ageOptions(c), c.ageRangeFilter)}",
                            isActive: c.ageRangeFilter != null,
                            onPressed: c.loading
                                ? null
                                : () {
                                    _showFilterSheet(
                                      context: context,
                                      title: "Choose age range",
                                      options: _ageOptions(c),
                                      selectedValue: c.ageRangeFilter,
                                      onSelected: context
                                          .read<CatalogController>()
                                          .setAgeRangeFilter,
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _filterButton(
                            context: context,
                            label:
                                "Status ${_selectedLabel(_statusFilters, c.availabilityFilter)}",
                            isActive: c.availabilityFilter != null,
                            onPressed: c.loading
                                ? null
                                : () {
                                    _showFilterSheet(
                                      context: context,
                                      title: "Choose status",
                                      options: _statusFilters,
                                      selectedValue: c.availabilityFilter,
                                      onSelected: context
                                          .read<CatalogController>()
                                          .setAvailabilityFilter,
                                    );
                                  },
                          ),
                        ),
                        if (c.hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          _ClearFiltersButton(
                            onPressed: c.loading
                                ? null
                                : () => _clearSearchAndFilters(c),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: Consumer<CatalogController>(
              builder: (context, c, _) {
                if (c.loading && c.toys.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.error != null && c.toys.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                context.read<CatalogController>().loadInitial(),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final showFooter =
                    c.hasNext || (c.loading && c.toys.isNotEmpty);
                return RefreshIndicator(
                  onRefresh: () => context.read<CatalogController>().refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: c.toys.length + (showFooter ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < c.toys.length) {
                        final t = c.toys[index];
                        final parts = <String>[
                          if (t.category != null && t.category!.isNotEmpty)
                            t.category!,
                          if (t.status != null && t.status!.isNotEmpty)
                            t.status!,
                        ];
                        return ListTile(
                          leading:
                              t.photoFile != null && t.photoFile!.isNotEmpty
                                  ? ToyPhotoTile(toyId: t.toyId)
                                  : CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: Icon(Icons.toys,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                    ),
                          title: Text(t.name),
                          subtitle:
                              parts.isEmpty ? null : Text(parts.join(" · ")),
                          trailing: ToyAvailabilityBadge(
                              availability: t.availability),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ToyDetailScreen(toyId: t.toyId),
                              ),
                            );
                          },
                        );
                      }
                      if (c.loading && c.toys.isNotEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (c.hasNext) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: TextButton(
                              onPressed: c.loading
                                  ? null
                                  : () => context
                                      .read<CatalogController>()
                                      .loadMore(),
                              child: const Text("Load more"),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
          Consumer<CatalogController>(
            builder: (context, c, _) {
              if (c.toys.isEmpty) return const SizedBox.shrink();
              final q = c.searchQuery.trim();
              final summary = q.isEmpty
                  ? "Showing ${c.toys.length} of ${c.total}"
                  : "Showing ${c.toys.length} of ${c.total} · search “$q”";
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(summary,
                    style: Theme.of(context).textTheme.bodySmall),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact clear control beside filter chips (only shown when filters are active).
class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Clear search and filters",
      child: Material(
        color: kBrandYellow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_off, size: 18, color: kBrandOnYellow),
                SizedBox(width: 4),
                Text(
                  "Clear",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kBrandOnYellow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
