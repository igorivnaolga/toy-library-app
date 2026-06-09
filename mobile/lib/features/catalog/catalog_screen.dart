import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/app_input_field.dart";
import "../../core/auth_store.dart";
import "../../core/search_field.dart";
import "../loans/loans_controller.dart";
import "catalog_provider.dart";
import "toy_catalog_list_tile.dart";
import "toy_detail_screen.dart";
import "toy_edit_sheet.dart";

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
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogController>();
    _searchController.text = catalog.searchQuery;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      catalog.loadInitial();
      if (context.read<AuthStore>().canBookToys) {
        context.read<LoansController>().loadMyLoans(activeOnly: true);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Prefetch well before the end so the next page is ready when the user arrives.
    final prefetchDistance =
        position.viewportDimension * 2.5 + 200;
    if (position.pixels >= position.maxScrollExtent - prefetchDistance) {
      context.read<CatalogController>().loadMore();
    }
  }

  void _prefetchIfListDoesNotFillScreen(CatalogController catalog) {
    if (!catalog.hasNext || catalog.loading || catalog.loadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) {
        catalog.loadMore();
      }
    });
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
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: kModalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final maxListHeight = MediaQuery.of(sheetContext).size.height * 0.55;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(
                  color: kBrandYellow,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: kBrandOnYellow.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      title,
                      style: sheetContext.modalTitleOnYellow,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final (value, label) = options[index];
                    final isSelected = selectedValue == value;
                    return ListTile(
                      tileColor: isSelected
                          ? kBrandYellow.withValues(alpha: 0.18)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(
                        label,
                        style: sheetContext.modalOptionTitle.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: kBrandOnYellow)
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onSelected(value);
                      },
                    );
                  },
                ),
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
    final background =
        isActive ? kBrandYellow : colors.surfaceContainerHighest;
    final foreground = kBrandOnYellow;
    return Material(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
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
                  style: context.filterChipLabel(active: isActive),
                ),
              ),
              Icon(
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

  Future<void> _addToy(BuildContext context) async {
    final created = await showToyCreateSheet(context);
    if (!context.mounted || created == null) return;
    await context.read<CatalogController>().refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Toy ${created.toyId} added."),
        action: SnackBarAction(
          label: "Open",
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ToyDetailScreen(toyId: created.toyId),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthStore>().isAdmin;

    return Scaffold(
      primary: false,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _addToy(context),
              backgroundColor: kBrandYellow,
              foregroundColor: kBrandOnYellow,
              icon: const Icon(Icons.add),
              label: const Text("Add toy"),
            )
          : null,
      body: Column(
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: searchInputDecoration(
              context,
              hintText: "Search toys…",
              suffixIcon: searchClearSuffix(
                context,
                visible: _searchController.text.isNotEmpty,
                onClear: _clearSearch,
              ),
            ),
            onChanged: (value) {
              setState(() {});
              _scheduleSearch(value);
            },
          ),
        ),
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
                _prefetchIfListDoesNotFillScreen(c);
                final showFooter = c.loadingMore;
                return RefreshIndicator(
                  onRefresh: () => context.read<CatalogController>().refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    itemCount: c.toys.length + (showFooter ? 1 : 0),
                    separatorBuilder: (context, index) {
                      if (index >= c.toys.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      if (index < c.toys.length) {
                        final t = c.toys[index];
                        return ToyCatalogListTile(
                          toy: t,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ToyDetailScreen(toyId: t.toyId),
                              ),
                            );
                          },
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
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
                child: Text(
                  summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.62),
                        fontWeight: FontWeight.w500,
                      ),
                ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list_off, size: 18, color: kBrandOnYellow),
                const SizedBox(width: 4),
                Text(
                  "Clear",
                  style: context.filterActionLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
