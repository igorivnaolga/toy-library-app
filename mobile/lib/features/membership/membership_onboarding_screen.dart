import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_client.dart";
import "../../core/auth_store.dart";

/// First login: pick a membership tier (stored on `profiles` via backend).
class MembershipOnboardingScreen extends StatefulWidget {
  const MembershipOnboardingScreen({super.key});

  @override
  State<MembershipOnboardingScreen> createState() =>
      _MembershipOnboardingScreenState();
}

class _MembershipOnboardingScreenState
    extends State<MembershipOnboardingScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String tier) async {
    final backend = context.read<BackendClient>();
    final auth = context.read<AuthStore>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await backend.patchJson("/api/v1/auth/me/membership", {
        "membership_tier": tier,
      });
      await auth.refreshProfile(silent: true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose membership"),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => context.read<AuthStore>().signOut(),
            child: const Text("Sign out"),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Pick how you would like to take part. You can change fees or "
            "renewals later; this step only records your tier.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          _TierCard(
            title: "Casual",
            subtitle: "Browse and borrow with a standard member account.",
            onTap: _busy ? null : () => _choose("casual"),
          ),
          const SizedBox(height: 12),
          _TierCard(
            title: "Non-duty member",
            subtitle: "Member without volunteer shifts.",
            onTap: _busy ? null : () => _choose("non_duty"),
          ),
          const SizedBox(height: 12),
          _TierCard(
            title: "Duty volunteer (pending)",
            subtitle:
                "You intend to take volunteer shifts. An admin will confirm "
                "before volunteer tools unlock.",
            onTap: _busy ? null : () => _choose("duty"),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
