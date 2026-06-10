import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../catalog/toy_id_badge.dart";
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
    this.inGroup = false,
  });

  final BookingItem item;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback? onChangeDate;
  final VoidCallback? onCancel;
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitleStyle = context.listSubtitle;
    final subtitle =
        item.isPending ? item.groupedListSubtitle : item.listSubtitle;

    final photoSize = inGroup ? 56.0 : 80.0;

    return Opacity(
      opacity: item.isCancelled ? 0.72 : 1,
      child: Material(
        color: inGroup ? colors.surface : colors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(inGroup ? 10 : 12),
          side: inGroup
              ? BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, inGroup ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToyPhotoTile(
                      toyId: item.toyId,
                      photoFile: item.photoFile,
                      size: photoSize,
                    ),
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
                          if (item.toyId.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ToyIdBadge(toyId: item.toyId),
                          ],
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: subtitleStyle.copyWith(
                                fontWeight: item.isPending
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                          ],
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
