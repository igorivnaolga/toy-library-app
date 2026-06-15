import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../auth/login_screen.dart";
import "../membership/membership_tier_card.dart";
import "../membership/membership_tiers.dart";
import "../payments/member_balance_card.dart";
import "../payments/payment_instructions_card.dart";
import "../profile/profile_labels.dart";
import "library_info_copy.dart";

/// Membership tiers and the signed-in member's current status.
class MembershipInfoScreen extends StatelessWidget {
  const MembershipInfoScreen({super.key, this.embedded = false});

  /// When true, shown as a main tab (no nested app bar).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthStore>();
    final membershipStatus = membershipSummaryLabel(
      role: auth.role,
      membershipTier: auth.membershipTier,
    );
    final currentTier = auth.isMember ? auth.membershipTier : null;

    final body = ListView(
      padding: embedded
          ? const EdgeInsets.fromLTRB(12, 8, 12, 32)
          : const EdgeInsets.all(20),
      children: [
        if (!auth.isGuest) ...[
          Material(
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.card_membership_outlined,
                    color: kBrandOnYellow.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your current membership",
                          style: context.profileSecondary.copyWith(
                            color: kBrandOnYellow,
                          ),
                        ),
                        if (auth.membershipTier == "duty" && auth.isMember) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Volunteer access pending approval",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kBrandOnYellow.withValues(alpha: 0.75),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _MembershipBadge(
                    label: membershipStatus,
                    style: membershipBadgeStyle(
                      label: membershipStatus,
                      tierForeground: membershipTierForeground(currentTier),
                      colors: theme.colorScheme,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!auth.isGuest) ...[
            MemberBalanceCard(
              balanceDueCents: auth.balanceDueCents,
              creditBalanceCents: auth.creditBalanceCents,
            ),
            const SizedBox(height: 12),
          ],
          if (!auth.membershipFeesPaid) ...[
            PaymentInstructionsCard(
              amountDueCents: auth.membershipDueCents,
              memberEmail: auth.email,
              showBookingHint: true,
            ),
            const SizedBox(height: 12),
          ],
        ],
        for (var i = 0; i < membershipTierOptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          MembershipTierCard(
            title: membershipTierCardTitle(
              membershipTierOptions[i],
              currentTier: currentTier,
              volunteerConfirmed: auth.volunteerConfirmed,
            ),
            subtitle: membershipTierOptions[i].subtitle,
            selected: !auth.isGuest && currentTier == membershipTierOptions[i].tier,
            onTap: () => _onTierTap(context, auth),
          ),
        ],
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text(LibraryInfoCopy.membershipTitle),
      ),
      body: body,
    );
  }

  static void _onTierTap(BuildContext context, AuthStore auth) {
    if (auth.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "To change membership type, please contact the library coordinator.",
        ),
      ),
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({
    required this.label,
    required this.style,
  });

  final String label;
  final MembershipBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: style.border,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
