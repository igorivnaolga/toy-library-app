import "package:flutter/material.dart";

/// Placeholder for admin-only tools (inventory, check-in/out, audit log).
class AdminPlaceholder extends StatelessWidget {
  const AdminPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Admin panel (coming soon)"),
      ),
    );
  }
}
