import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../../core/api_client.dart";
import "../../core/user_friendly_error.dart";
import "../../core/auth_store.dart";
import "membership_tier_card.dart";
import "membership_tiers.dart";

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
      if (!mounted) return;
      if (!auth.membershipFeesPaid) {
        auth.markPostRegistrationWelcome();
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(
        () => _error = friendlyErrorMessage(
          e,
          fallback: "Couldn't save your membership choice. Please try again.",
        ),
      );
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
            style: context.bodyText,
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
          for (var i = 0; i < membershipTierOptions.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            MembershipTierCard(
              title: membershipTierOptions[i].title,
              subtitle: membershipTierOptions[i].subtitle,
              onTap: _busy ? null : () => _choose(membershipTierOptions[i].tier),
            ),
          ],
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: ToyLibraryLoadingIndicator()),
          ),
        ],
      ),
    );
  }
}
