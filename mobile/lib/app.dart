/// Root widget for the Flutter application.
///
/// Wires [CatalogController] (via `provider`) and points the home route at [CatalogScreen].
/// Pass a fake [BackendClient] in tests with [ToyLibraryApp.backend].
library;

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "core/api_client.dart";
import "features/catalog/catalog_provider.dart";
import "features/catalog/catalog_screen.dart";

class ToyLibraryApp extends StatelessWidget {
  const ToyLibraryApp({super.key, this.backend});

  /// When null, a real [ApiClient] is created for the widget subtree.
  final BackendClient? backend;

  @override
  Widget build(BuildContext context) {
    final client = backend ?? ApiClient();
    return ChangeNotifierProvider(
      create: (_) => CatalogController(client),
      child: MaterialApp(
        title: "Toy Library",
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const CatalogScreen(),
      ),
    );
  }
}
