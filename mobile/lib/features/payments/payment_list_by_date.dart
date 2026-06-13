import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../duty/duty_session_models.dart";
import "payment_models.dart";

/// Payment rows grouped under a calendar date heading.
class PaymentsGroupedByDate extends StatelessWidget {
  const PaymentsGroupedByDate({
    super.key,
    required this.payments,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });

  final List<PaymentItem> payments;
  final Widget Function(PaymentItem payment) itemBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final groups = groupPaymentsByDate(payments);
    if (groups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < groups.length; g++) ...[
            if (g > 0) const SizedBox(height: 12),
            Text(
              formatSessionDate(groups[g].date),
              style: context.groupLabel,
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < groups[g].payments.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              itemBuilder(groups[g].payments[i]),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact payment row for member balance history.
class MemberPaymentRow extends StatelessWidget {
  const MemberPaymentRow({super.key, required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = payment.description ?? payment.typeLabel;
    final amountColor = payment.isCreditGrant && !payment.isPending
        ? theme.colorScheme.primary
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.listSubtitle),
                if (!payment.isCreditGrant || payment.isPending)
                  Text(
                    payment.statusLabel,
                    style: context.emptyState.copyWith(
                      color: payment.isPending
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            payment.displayAmountLabel,
            style: context.bodyText.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
