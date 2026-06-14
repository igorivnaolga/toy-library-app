import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "payment_list_by_date.dart";
import "payment_models.dart";

/// Member account balance shown on profile and membership screens.
class MemberBalanceCard extends StatelessWidget {
  const MemberBalanceCard({
    super.key,
    required this.balanceDueCents,
    this.creditBalanceCents = 0,
    this.payments = const [],
    this.onHowToPay,
  });

  final int balanceDueCents;
  final int creditBalanceCents;
  final List<PaymentItem> payments;
  final VoidCallback? onHowToPay;

  bool get _showsHowToPay =>
      onHowToPay != null &&
      (balanceDueCents > 0 ||
          payments.any((payment) => payment.isPending));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingPayments = payments.where((p) => p.isPending).toList();
    final pendingCount = pendingPayments.length;

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
                        : creditBalanceCents > 0
                            ? "Account credit: ${formatDueCents(creditBalanceCents)}"
                            : "Nothing owing",
                    style: context.cardTitle,
                  ),
                ),
              ],
            ),
            if (pendingCount > 0 && balanceDueCents > 0) ...[
              const SizedBox(height: 8),
              Text(
                pendingCount == 1
                    ? "1 charge below"
                    : "$pendingCount charges below",
                style: context.listSubtitle,
              ),
            ],
            if (creditBalanceCents > 0 && balanceDueCents > 0) ...[
              const SizedBox(height: 8),
              Text(
                "Account credit: ${formatDueCents(creditBalanceCents)}",
                style: context.listSubtitle,
              ),
            ],
            if (_showsHowToPay) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: BrandChipButton(
                  label: "How to pay",
                  onPressed: onHowToPay,
                ),
              ),
            ],
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                pendingCount > 0 ? "Breakdown" : "Payments",
                style: context.groupLabel,
              ),
              const SizedBox(height: 6),
              PaymentsGroupedByDate(
                payments: pendingCount > 0 ? pendingPayments : payments,
                itemBuilder: (payment) => MemberPaymentRow(payment: payment),
              ),
            ] else if (balanceDueCents == 0 && creditBalanceCents == 0) ...[
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
