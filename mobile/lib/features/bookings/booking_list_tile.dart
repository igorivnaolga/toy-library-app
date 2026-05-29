import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../catalog/toy_photo_tile.dart";
import "booking_models.dart";

/// Branded card for one booking in the list (matches catalog toy cards).
class BookingListTile extends StatelessWidget {
  const BookingListTile({
    super.key,
    required this.item,
    required this.loading,
    required this.onOpen,
    required this.onChangeDate,
    required this.onCancel,
  });

  final BookingItem item;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback? onChangeDate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitleStyle = context.listSubtitle;

    return Opacity(
      opacity: item.isCancelled ? 0.72 : 1,
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
                          style: context.cardTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.listSubtitle,
                          style: subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  if (!item.isPending) ...[
                    const SizedBox(width: 8),
                    BookingStatusChip(status: item.status),
                  ],
                ],
              ),
              if (item.isPending &&
                  (onChangeDate != null || onCancel != null)) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onChangeDate != null)
                      Expanded(
                        child: BrandChipButton(
                          label: "Change",
                          onPressed: loading ? null : onChangeDate,
                        ),
                      ),
                    if (onChangeDate != null && onCancel != null)
                      const SizedBox(width: 8),
                    if (onCancel != null)
                      Expanded(
                        child: BrandChipButton(
                          label: "Cancel",
                          variant: BrandChipButtonVariant.outlined,
                          onPressed: loading ? null : onCancel,
                        ),
                      ),
                  ],
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
