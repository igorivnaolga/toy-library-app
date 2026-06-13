import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../payments/payment_models.dart";
import "loans_controller.dart";

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
  String? memberUserId,
  int? memberBalanceDueCents,
  int? memberCreditBalanceCents,
}) {
  return showDialog<DeskCheckoutResult>(
    context: context,
    builder: (ctx) => _DeskCheckoutDialog(
      memberLabel: memberLabel,
      lines: lines,
      memberUserId: memberUserId,
      memberBalanceDueCents: memberBalanceDueCents,
      memberCreditBalanceCents: memberCreditBalanceCents,
    ),
  );
}

class _DeskCheckoutDialog extends StatefulWidget {
  const _DeskCheckoutDialog({
    required this.memberLabel,
    required this.lines,
    this.memberUserId,
    this.memberBalanceDueCents,
    this.memberCreditBalanceCents,
  });

  final String memberLabel;
  final List<DeskCheckoutLine> lines;
  final String? memberUserId;
  final int? memberBalanceDueCents;
  final int? memberCreditBalanceCents;

  @override
  State<_DeskCheckoutDialog> createState() => _DeskCheckoutDialogState();
}

class _DeskCheckoutDialogState extends State<_DeskCheckoutDialog> {
  bool _markPaid = false;
  String _method = "cash";
  bool _balanceLoading = false;
  int? _balanceDueCents;
  int? _creditBalanceCents;
  final GlobalKey _paymentMethodKey = GlobalKey();

  bool get _shouldFetchBalance =>
      widget.memberUserId != null &&
      widget.memberBalanceDueCents == null &&
      widget.memberCreditBalanceCents == null;

  @override
  void initState() {
    super.initState();
    _balanceDueCents = widget.memberBalanceDueCents;
    _creditBalanceCents = widget.memberCreditBalanceCents;
    if (_shouldFetchBalance) {
      _loadBalance();
    }
  }

  Future<void> _loadBalance() async {
    final userId = widget.memberUserId;
    if (userId == null) return;
    setState(() => _balanceLoading = true);
    try {
      final summary =
          await context.read<LoansController>().loadMemberBalanceSummary(userId);
      if (!mounted) return;
      setState(() {
        _balanceDueCents = summary.balanceDueCents;
        _creditBalanceCents = summary.creditBalanceCents;
        _balanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceLoading = false);
    }
  }

  int get _checkoutTotalCents => widget.lines.fold<int>(
        0,
        (sum, line) => sum + (line.rentalPriceCents ?? 0),
      );

  int get _creditCents => _creditBalanceCents ?? 0;

  int get _creditAppliedCents =>
      checkoutCreditAppliedCents(_creditCents, _checkoutTotalCents);

  int get _dueAfterCreditCents =>
      checkoutDueAfterCreditCents(_creditCents, _checkoutTotalCents);

  void _selectPaidNow() {
    setState(() => _markPaid = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _paymentMethodKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Widget _paymentMethodTile(String value, String label) {
    return RadioListTile<String>(
      value: value,
      groupValue: _method,
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: (selected) {
        if (selected == null) return;
        setState(() => _method = selected);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLabel = _checkoutTotalCents > 0
        ? formatDueCents(_checkoutTotalCents)
        : "\$0.00";
    final existingBalance = _balanceDueCents ?? 0;
    final dueLabel = formatDueCents(_dueAfterCreditCents);
    final creditAppliedLabel = formatDueCents(_creditAppliedCents);
    final balanceReady = !_balanceLoading || !_shouldFetchBalance;

    return AlertDialog(
      title: const Text("Check out"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(widget.memberLabel, style: context.cardTitle),
            if (_balanceLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (balanceReady) ...[
              if (_creditCents > 0) ...[
                const SizedBox(height: 6),
                Text(
                  "Account credit: ${formatDueCents(_creditCents)}",
                  style: context.listSubtitle.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (existingBalance > 0) ...[
                const SizedBox(height: 4),
                Text(
                  "Balance owing: ${formatDueCents(existingBalance)}",
                  style: context.listSubtitle.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
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
                  child: Text("Checkout total", style: context.bodyText),
                ),
                Text(totalLabel, style: context.bodyText),
              ],
            ),
            if (balanceReady && _creditAppliedCents > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Account credit applied",
                      style: context.listSubtitle.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    "-$creditAppliedLabel",
                    style: context.bodyText.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Due for these toys",
                    style: context.cardTitle,
                  ),
                ),
                Text(
                  balanceReady && _dueAfterCreditCents > 0
                      ? dueLabel
                      : balanceReady
                          ? "\$0.00"
                          : "…",
                  style: context.cardTitle.copyWith(
                    color: balanceReady && _dueAfterCreditCents > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (balanceReady &&
                _dueAfterCreditCents == 0 &&
                _checkoutTotalCents > 0 &&
                _creditAppliedCents > 0) ...[
              const SizedBox(height: 6),
              Text(
                "These toys are covered by account credit.",
                style: context.listSubtitle,
              ),
            ],
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
                _selectPaidNow();
              },
            ),
            if (_markPaid) ...[
              KeyedSubtree(
                key: _paymentMethodKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (_checkoutTotalCents > 0 &&
                        balanceReady &&
                        _dueAfterCreditCents == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Account credit covers this rental — no cash payment needed.",
                          style: context.listSubtitle.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    else ...[
                      Text("Payment method", style: context.groupLabel),
                      const SizedBox(height: 4),
                      _paymentMethodTile("cash", "Cash"),
                      _paymentMethodTile("eftpos", "EFTPOS"),
                      _paymentMethodTile("bank", "Bank transfer"),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
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
            final markPaid = _markPaid &&
                _checkoutTotalCents > 0 &&
                (!balanceReady || _dueAfterCreditCents > 0);
            Navigator.pop(
              context,
              DeskCheckoutResult(
                markPaid: markPaid,
                paymentMethod: markPaid ? _method : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
