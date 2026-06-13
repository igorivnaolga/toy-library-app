import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/app_text_styles.dart";
import "../info/library_info_copy.dart";
import "payment_models.dart";

/// How members can pay membership and rental fees (Phase 1: in person or bank transfer).
class PaymentInstructionsCard extends StatelessWidget {
  const PaymentInstructionsCard({
    super.key,
    this.amountDueCents,
    this.memberEmail,
    this.compact = false,
    this.showBookingHint = false,
  });

  final int? amountDueCents;
  final String? memberEmail;
  final bool compact;
  final bool showBookingHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueLabel = amountDueCents != null && amountDueCents! > 0
        ? formatDueCents(amountDueCents!)
        : null;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
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
                  Icons.account_balance_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    compact ? "Payment options" : "How to pay",
                    style: context.cardTitle,
                  ),
                ),
              ],
            ),
            if (dueLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                "Amount due: $dueLabel",
                style: context.bodyText.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              "At the library — cash or EFTPOS during opening hours.",
              style: context.bodyText,
            ),
            const SizedBox(height: 16),
            Text("Bank transfer", style: context.profileSecondary),
            const SizedBox(height: 8),
            _CopyableLine(
              label: "Account name",
              value: LibraryInfoCopy.bankAccountName,
            ),
            const SizedBox(height: 6),
            _CopyableLine(
              label: "Account number",
              value: LibraryInfoCopy.bankAccountNumber,
            ),
            if (memberEmail != null && memberEmail!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _CopyableLine(
                label: "Reference",
                value: memberEmail!.trim(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              LibraryInfoCopy.bankTransferReferenceHint,
              style: context.listSubtitle,
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Text(
                showBookingHint
                    ? "You can book toys now. Bank transfers are confirmed by "
                        "the coordinator — bring cash or EFTPOS payment to "
                        "your first visit if you prefer to pay at the library."
                    : "Bank transfers are confirmed by the coordinator — you can "
                        "book once payment is recorded in the app.",
                style: context.listSubtitle.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyableLine extends StatelessWidget {
  const _CopyableLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: "$label: ",
                  style: context.listSubtitle,
                ),
                TextSpan(
                  text: value,
                  style: context.bodyText.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: "Copy $label",
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Copied $label")),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined, size: 20),
        ),
      ],
    );
  }
}
