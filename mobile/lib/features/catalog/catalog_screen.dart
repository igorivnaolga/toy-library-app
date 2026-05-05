import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "catalog_provider.dart";
import "toy_detail_screen.dart";
import "toy_photo_tile.dart";

/// Catalog: loads `GET /api/v1/categories` and paged `GET /api/v1/toys` via [CatalogController].
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Avoid Dropdown assertion if a stale filter label is not in the latest category list.
  String? _effectiveCategoryValue(CatalogController c) {
    final f = c.categoryFilterLabel;
    if (f == null) return null;
    final ok = c.categories.any((e) => e.label == f);
    return ok ? f : null;
  }

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
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Text("Category:"),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _effectiveCategoryValue(c),
                                hint: const Text("All"),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text("All"),
                                  ),
                                  ...c.categories.map(
                                    (cat) => DropdownMenuItem<String?>(
                                      value: cat.label,
                                      child: Text(cat.label, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ],
                                onChanged: c.loading
                                    ? null
                                    : (value) {
                                        context.read<CatalogController>().setCategoryFilter(value);
                                      },
                              ),
                            ),
                          ),
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
                            onPressed: () => context.read<CatalogController>().loadInitial(),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final showFooter = c.hasNext || (c.loading && c.toys.isNotEmpty);
                return RefreshIndicator(
                  onRefresh: () => context.read<CatalogController>().refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: c.toys.length + (showFooter ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < c.toys.length) {
                        final t = c.toys[index];
                        final parts = <String>[
                          if (t.category != null && t.category!.isNotEmpty) t.category!,
                          if (t.status != null && t.status!.isNotEmpty) t.status!,
                        ];
                        return ListTile(
                          leading: t.photoFile != null && t.photoFile!.isNotEmpty
                              ? ToyPhotoTile(toyId: t.toyId)
                              : CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.toys, color: Theme.of(context).colorScheme.outline),
                                ),
                          title: Text(t.name),
                          subtitle: parts.isEmpty ? null : Text(parts.join(" · ")),
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
                              onPressed: c.loading ? null : () => context.read<CatalogController>().loadMore(),
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
                child: Text("Showing ${c.toys.length} of ${c.total}", style: Theme.of(context).textTheme.bodySmall),
              );
            },
          ),
        ],
      ),
    );
  }
}
