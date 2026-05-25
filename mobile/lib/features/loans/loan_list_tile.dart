import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";
import "../catalog/toy_photo_tile.dart";
import "loan_models.dart";

/// Branded card for one loan in the member list.
class LoanListTile extends StatelessWidget {
  const LoanListTile({
    super.key,
    required this.item,
    required this.loading,
    required this.onOpen,
    this.onRenew,
  });

  final LoanItem item;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.62),
      height: 1.25,
      fontWeight: FontWeight.w500,
    );

    return Opacity(
      opacity: item.isReturned ? 0.72 : 1,
      child: Material(
        color: colors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToyPhotoTile(toyId: item.toyId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.toyName ?? item.toyId,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kBrandOnYellow,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.listSubtitle,
                            style: subtitleStyle?.copyWith(
                              color: item.isOverdue
                                  ? colors.error
                                  : subtitleStyle.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LoanStatusChip(
                      label: item.statusLabel,
                      isOverdue: item.isOverdue && item.isActive,
                    ),
                  ],
                ),
                if (item.canRenew && onRenew != null) ...[
                  const SizedBox(height: 10),
                  BrandChipButton(
                    label: "Renew",
                    onPressed: loading ? null : onRenew,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoanStatusChip extends StatelessWidget {
  const LoanStatusChip({
    super.key,
    required this.label,
    this.isOverdue = false,
    this.width = kBookingsChipWidth,
  });

  final String label;
  final bool isOverdue;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = isOverdue
        ? (const Color(0xFFFFCDD2), const Color(0xFFC62828))
        : switch (label.toLowerCase()) {
            "on loan" => (kBrandYellow, kBrandOnYellow),
            "returned" => (
                const Color(0xFFC8E6C9),
                const Color(0xFF2E7D32),
              ),
            _ => (Colors.grey.shade300, kBrandOnYellow),
          };

    return SizedBox(
      width: width,
      height: 32,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
