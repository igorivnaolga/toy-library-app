import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../loans/loans_controller.dart";
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
    final colors = Theme.of(context).colorScheme;
    final category = toy.category?.trim();
    final isMyLoan = toy.availability == "on_loan" &&
        context.watch<LoansController>().activeLoanForToy(toy.toyId) != null;

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
              ToyPhotoTile(
                toyId: toy.toyId,
                photoFile: toy.photoFile,
                size: 80,
              ),
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
                    if (category != null && category.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        category,
                        style: context.listSubtitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ToyAvailabilityBadge(
                availability: toy.availability,
                isMyLoan: isMyLoan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
