import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "payment_models.dart";

/// Member account balance shown on profile and membership screens.
class MemberBalanceCard extends StatelessWidget {
  const MemberBalanceCard({
    super.key,
    required this.balanceDueCents,
    this.payments = const [],
  });

  final int balanceDueCents;
  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = payments.where((p) => p.isPending).toList();

    return Material(
      color: balanceDueCents > 0
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: balanceDueCents > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    balanceDueCents > 0
                        ? "Balance owing: ${formatDueCents(balanceDueCents)}"
                        : "Nothing owing",
                    style: context.cardTitle,
                  ),
                ),
              ],
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Pending charges", style: context.groupLabel),
              const SizedBox(height: 6),
              ...pending.take(6).map(
                    (payment) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              payment.description ??
                                  "${payment.typeLabel} — ${payment.amountLabel}",
                              style: context.listSubtitle,
                            ),
                          ),
                          Text(
                            payment.amountLabel,
                            style: context.bodyText,
                          ),
                        ],
                      ),
                    ),
                  ),
              if (pending.length > 6)
                Text(
                  "+ ${pending.length - 6} more",
                  style: context.listSubtitle,
                ),
            ] else if (balanceDueCents == 0) ...[
              const SizedBox(height: 8),
              Text(
                "Membership and toy hire charges appear here when due.",
                style: context.listSubtitle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
