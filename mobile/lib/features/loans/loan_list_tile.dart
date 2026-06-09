import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
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
    final colors = Theme.of(context).colorScheme;
    final subtitleStyle = context.listSubtitle;
    final subtitle = item.isActive ? item.groupedListSubtitle : item.listSubtitle;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ToyPhotoTile(
                  toyId: item.toyId,
                  photoFile: item.photoFile,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.toyName ?? item.toyId,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.cardTitle,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: subtitleStyle.copyWith(
                            color: item.isOverdue
                                ? colors.error
                                : subtitleStyle.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.canRenew && onRenew != null) ...[
                  const SizedBox(width: 8),
                  BrandChipButton(
                    label: "Renew",
                    variant: BrandChipButtonVariant.outlined,
                    fixedWidth: 100,
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
