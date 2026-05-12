import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

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
  static const List<(String?, String)> _ageRangeFilters = [
    (null, "All"),
    ("12-36mths", "12-36 mths"),
    ("18 mths +", "18 mths +"),
    ("1-5yrs", "1-5 yrs"),
    ("2-5 years", "2-5 years"),
    ("3-5yrs", "3-5 yrs"),
    ("3 years +", "3 years +"),
    ("5 years +", "5 years +"),
  ];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogController>().loadInitial();
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
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<CatalogController>().setSearchQuery(value);
    });
  }

  String _selectedLabel(List<(String?, String)> options, String? value) {
    for (final option in options) {
      if (option.$1 == value) return option.$2;
    }
    return value == null || value.isEmpty ? "All" : value;
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
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              decoration: const InputDecoration(
                hintText: "Search toys…",
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
                filled: true,
              ),
              onChanged: _scheduleSearch,
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
                      children: [
                        _filterButton(
                          label: c.categoryFilterLabel ?? "Category",
                          onPressed: c.loading
                              ? null
                              : () {
                                  final options = <(String?, String)>[
                                    (null, "All"),
                                    ...c.categories
                                        .map((cat) => (cat.label, cat.label)),
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
                        const SizedBox(width: 6),
                        _filterButton(
                          label:
                              "Age ${_selectedLabel(_ageRangeFilters, c.ageRangeFilter)}",
                          onPressed: c.loading
                              ? null
                              : () {
                                  _showFilterSheet(
                                    context: context,
                                    title: "Choose age range",
                                    options: _ageRangeFilters,
                                    selectedValue: c.ageRangeFilter,
                                    onSelected: context
                                        .read<CatalogController>()
                                        .setAgeRangeFilter,
                                  );
                                },
                        ),
                        const SizedBox(width: 6),
                        _filterButton(
                          label:
                              "Status ${_selectedLabel(_statusFilters, c.availabilityFilter)}",
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
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text("Showing ${c.toys.length} of ${c.total}",
                    style: Theme.of(context).textTheme.bodySmall),
              );
            },
          ),
        ],
      ),
    );
  }
}
