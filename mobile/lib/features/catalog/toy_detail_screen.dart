import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/toy_photo_url.dart";
import "catalog_models.dart";
import "catalog_provider.dart";
import "toy_availability_badge.dart";

/// Loads a single toy from `GET /api/v1/toys/{toy_id}`.
class ToyDetailScreen extends StatefulWidget {
  const ToyDetailScreen({super.key, required this.toyId});

  final String toyId;

  @override
  State<ToyDetailScreen> createState() => _ToyDetailScreenState();
}

class _ToyDetailScreenState extends State<ToyDetailScreen> {
  Future<ToyItem>? _future;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    setState(() {
      _future = context.read<CatalogController>().fetchToy(widget.toyId);
    });
  }

  void _retry() {
    setState(() {
      _future = context.read<CatalogController>().fetchToy(widget.toyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Toy details")),
      body: FutureBuilder<ToyItem>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final message = err is ApiException ? err.message : err.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }
          final t = snapshot.data!;
          final colors = Theme.of(context).colorScheme;
          final hasPhotoName = t.photoFile != null && t.photoFile!.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: hasPhotoName
                      ? Image.network(
                          toyPhotoHttpUrl(t.toyId),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: colors.surfaceContainerHighest,
                            child: Icon(Icons.toys,
                                size: 64, color: colors.outline),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                        )
                      : ColoredBox(
                          color: colors.surfaceContainerHighest,
                          child:
                              Icon(Icons.toys, size: 64, color: colors.outline),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(t.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ToyAvailabilityBadge(availability: t.availability),
              ),
              const SizedBox(height: 12),
              if (t.category != null) _line("Category", t.category!),
              if (t.ageRange != null) _line("Age range", t.ageRange!),
              if (t.status != null) _line("Status", t.status!),
              if (t.manufacturer != null && t.manufacturer!.isNotEmpty)
                _line("Manufacturer", t.manufacturer!),
              const SizedBox(height: 12),
              Text("Description",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(t.description?.isNotEmpty == true ? t.description! : "—"),
            ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
