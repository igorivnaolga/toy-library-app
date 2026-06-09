import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "booking_models.dart";

/// Prominent pickup-date group header for the member bookings list.
class BookingPickupDateHeader extends StatelessWidget {
  const BookingPickupDateHeader({
    super.key,
    required this.group,
    this.showTotalRental = true,
  });

  final BookingPickupDateGroup group;
  final bool showTotalRental;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateLabel = group.pickupLabel?.trim().isNotEmpty == true
        ? group.pickupLabel!.trim()
        : formatDisplayDate(group.pickupDate);
    final totalLabel = formatRentalPriceCents(group.totalRentalCents);
    final toyCount = group.bookings.length;
    final toyLabel = toyCount == 1 ? "1 toy" : "$toyCount toys";

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kBrandYellow.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBrandYellow.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 22,
                  color: kBrandOnYellow.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pickup date", style: context.formSectionLabel),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: context.cardTitle.copyWith(fontSize: 17),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBrandYellow.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    toyLabel,
                    style: const TextStyle(
                      color: kBrandOnYellow,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            if (showTotalRental && totalLabel != null) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    "Total rental",
                    style: context.listSubtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    totalLabel,
                    style: context.cardTitle.copyWith(fontSize: 16),
                  ),
                ],
              ),
              if (group.unpricedBookingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    group.unpricedBookingCount == 1
                        ? "Excludes 1 toy without a listed price"
                        : "Excludes ${group.unpricedBookingCount} toys without listed prices",
                    style: context.listSubtitle.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
