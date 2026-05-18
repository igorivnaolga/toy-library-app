import "package:flutter/material.dart";

import "../../core/app_theme.dart";

/// Dev-only visual check for brand colors — open from a debug entry or hot-restart route.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Toy Library"),
          actions: [
            TextButton(onPressed: () {}, child: const Text("Sign in")),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.toys), text: "Catalog"),
              Tab(icon: Icon(Icons.event_note), text: "Bookings"),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Brand palette", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _Swatch(color: kBrandYellow, label: "#FDC435"),
                const SizedBox(width: 12),
                _Swatch(color: kBrandOnYellow, label: "#1A1A1A"),
                const SizedBox(width: 12),
                _Swatch(color: scheme.primaryContainer, label: "container"),
              ],
            ),
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: "Search toys",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text("Available"),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text("3-5yrs"),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.toys, color: scheme.onPrimaryContainer),
                ),
                title: const Text("Robot"),
                subtitle: const Text("Books · 5+"),
                trailing: Chip(
                  label: const Text("Available"),
                  backgroundColor: scheme.primaryContainer,
                  labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () {}, child: const Text("Sign in")),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () {}, child: const Text("Create account")),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
