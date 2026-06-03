import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "catalog_models.dart";
import "toy_availability_badge.dart";
import "toy_id_badge.dart";
import "toy_photo_tile.dart";

/// Branded row for one toy in the catalog list.
class ToyCatalogListTile extends StatelessWidget {
  const ToyCatalogListTile({
    super.key,
    required this.toy,
    required this.onTap,
  });

  final ToyItem toy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToyPhotoTile(toyId: toy.toyId, photoFile: toy.photoFile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toy.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.cardTitle,
                    ),
                    if (toy.toyId.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ToyIdBadge(toyId: toy.toyId),
                    ],
                    if (_hasSubtitle) ...[
                      const SizedBox(height: 4),
                      _CatalogSubtitle(
                        category: toy.category,
                        piecesSummary: toy.piecesSummary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ToyAvailabilityBadge(availability: toy.availability),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasSubtitle {
    final category = toy.category?.trim();
    return (category != null && category.isNotEmpty) ||
        toy.piecesSummary.isNotEmpty;
  }
}

class _CatalogSubtitle extends StatelessWidget {
  const _CatalogSubtitle({
    required this.category,
    required this.piecesSummary,
  });

  final String? category;
  final String piecesSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categoryLabel = category?.trim();
    final hasCategory =
        categoryLabel != null && categoryLabel.isNotEmpty;
    final hasPieces = piecesSummary.isNotEmpty;

    if (!hasCategory && !hasPieces) {
      return const SizedBox.shrink();
    }

    final mutedStyle = context.listSubtitle;
    final categoryStyle = mutedStyle.copyWith(fontWeight: FontWeight.w600);

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (hasCategory) Text(categoryLabel, style: categoryStyle),
        if (hasCategory && hasPieces)
          Text(
            "·",
            style: mutedStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.outline,
            ),
          ),
        if (hasPieces) Text(piecesSummary, style: mutedStyle),
      ],
    );
  }
}
