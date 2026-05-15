import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_client.dart";
import "../../core/auth_store.dart";

/// Admin tools: approve duty-tier users who are waiting for volunteer access.
class AdminPlaceholder extends StatefulWidget {
  const AdminPlaceholder({super.key});

  @override
  State<AdminPlaceholder> createState() => _AdminPlaceholderState();
}

class _AdminPlaceholderState extends State<AdminPlaceholder> {
  Future<List<Map<String, dynamic>>>? _load;

  Future<List<Map<String, dynamic>>> _fetchPending(BackendClient backend) async {
    final json = await backend.getJson("/api/v1/admin/pending-duty-volunteers");
    final raw = json["data"];
    if (raw is! List<dynamic>) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _approve(BackendClient backend, String userId) async {
    await backend.postJson(
      "/api/v1/admin/users/$userId/approve-volunteer",
    );
    if (!mounted) return;
    setState(() {
      _load = _fetchPending(backend);
    });
    await context.read<AuthStore>().refreshProfile(silent: true);
  }

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendClient>();
    _load = _fetchPending(backend);
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendClient>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _load = _fetchPending(backend));
          await _load;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    "Could not load pending volunteers:\n${snapshot.error}",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text("No duty-tier members waiting for approval.")),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final row = rows[i];
                final id = row["user_id"]?.toString() ?? "";
                final email = row["email"]?.toString() ?? "";
                final name = row["full_name"]?.toString() ?? "";
                return ListTile(
                  title: Text(email.isEmpty ? id : email),
                  subtitle: Text(name.isEmpty ? "—" : name),
                  trailing: FilledButton(
                    onPressed: id.isEmpty
                        ? null
                        : () async {
                            try {
                              await _approve(backend, id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                    child: const Text("Approve"),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
