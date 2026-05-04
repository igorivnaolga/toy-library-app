/// Root widget for the Flutter application.
///
/// This is currently a minimal placeholder. Next steps typically:
/// - add routing (go_router) with role-based branches
/// - inject dependencies (ApiClient, AuthStore) via Provider/Riverpod/GetIt
import "package:flutter/material.dart";

class ToyLibraryApp extends StatelessWidget {
  const ToyLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `MaterialApp` provides Material theming + navigator + text direction, etc.
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("Toy Library App"),
        ),
      ),
    );
  }
}
