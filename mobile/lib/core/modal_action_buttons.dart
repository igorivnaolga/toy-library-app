import "package:flutter/material.dart";

import "app_theme.dart";

/// Shared height for side-by-side modal actions (Cancel + confirm).
const double kModalActionButtonHeight = 44;

/// Outlined + filled buttons with equal width in a modal footer row.
class ModalEqualWidthButtonRow extends StatelessWidget {
  const ModalEqualWidthButtonRow({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.spacing = 12,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onSecondary,
            style: brandOutlinedButtonStyle().copyWith(
              minimumSize: const WidgetStatePropertyAll(
                Size.fromHeight(kModalActionButtonHeight),
              ),
            ),
            child: Text(secondaryLabel),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: brandFilledButtonStyle(),
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}
