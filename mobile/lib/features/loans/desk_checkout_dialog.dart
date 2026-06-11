import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../payments/payment_models.dart";

/// One toy line on the volunteer checkout summary.
class DeskCheckoutLine {
  const DeskCheckoutLine({
    required this.toyId,
    required this.toyName,
    this.rentalPriceCents,
  });

  final String toyId;
  final String toyName;
  final int? rentalPriceCents;

  String get priceLabel {
    if (rentalPriceCents == null || rentalPriceCents! <= 0) {
      return "No charge";
    }
    return formatDueCents(rentalPriceCents!);
  }
}

class DeskCheckoutResult {
  const DeskCheckoutResult({
    required this.markPaid,
    this.paymentMethod,
  });

  final bool markPaid;
  final String? paymentMethod;

  String get rentalPayment => markPaid ? "paid" : "pending";
}

Future<DeskCheckoutResult?> showDeskCheckoutDialog(
  BuildContext context, {
  required String memberLabel,
  required List<DeskCheckoutLine> lines,
  int? memberBalanceDueCents,
}) {
  return showDialog<DeskCheckoutResult>(
    context: context,
    builder: (ctx) => _DeskCheckoutDialog(
      memberLabel: memberLabel,
      lines: lines,
      memberBalanceDueCents: memberBalanceDueCents,
    ),
  );
}

class _DeskCheckoutDialog extends StatefulWidget {
  const _DeskCheckoutDialog({
    required this.memberLabel,
    required this.lines,
    this.memberBalanceDueCents,
  });

  final String memberLabel;
  final List<DeskCheckoutLine> lines;
  final int? memberBalanceDueCents;

  @override
  State<_DeskCheckoutDialog> createState() => _DeskCheckoutDialogState();
}

class _DeskCheckoutDialogState extends State<_DeskCheckoutDialog> {
  bool _markPaid = false;
  String _method = "cash";

  int get _checkoutTotalCents => widget.lines.fold<int>(
        0,
        (sum, line) => sum + (line.rentalPriceCents ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLabel = _checkoutTotalCents > 0
        ? formatDueCents(_checkoutTotalCents)
        : "\$0.00";
    final existingBalance = widget.memberBalanceDueCents ?? 0;

    return AlertDialog(
      title: const Text("Check out"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.memberLabel, style: context.cardTitle),
            if (existingBalance > 0) ...[
              const SizedBox(height: 6),
              Text(
                "Current balance owing: ${formatDueCents(existingBalance)}",
                style: context.listSubtitle.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text("Toys", style: context.groupLabel),
            const SizedBox(height: 8),
            ...widget.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.toyName, style: context.bodyText),
                          Text(
                            line.toyId,
                            style: context.listSubtitle,
                          ),
                        ],
                      ),
                    ),
                    Text(line.priceLabel, style: context.bodyText),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Checkout total",
                    style: context.cardTitle,
                  ),
                ),
                Text(totalLabel, style: context.cardTitle),
              ],
            ),
            const SizedBox(height: 20),
            Text("Rental payment", style: context.groupLabel),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              value: false,
              groupValue: _markPaid,
              title: const Text("Pay later (add to balance)"),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _markPaid = value);
              },
            ),
            RadioListTile<bool>(
              value: true,
              groupValue: _markPaid,
              title: const Text("Paid now"),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _markPaid = value);
              },
            ),
            if (_markPaid) ...[
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "cash", label: Text("Cash")),
                  ButtonSegment(value: "eftpos", label: Text("EFTPOS")),
                  ButtonSegment(value: "bank", label: Text("Bank")),
                ],
                selected: {_method},
                onSelectionChanged: (selected) {
                  setState(() => _method = selected.first);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        BrandChipButton(
          label: "Confirm checkout",
          onPressed: () {
            Navigator.pop(
              context,
              DeskCheckoutResult(
                markPaid: _markPaid && _checkoutTotalCents > 0,
                paymentMethod: _markPaid && _checkoutTotalCents > 0
                    ? _method
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
