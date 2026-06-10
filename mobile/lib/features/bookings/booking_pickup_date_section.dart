import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "booking_models.dart";
import "booking_pickup_date_header.dart";

/// Groups a pickup-date header with its booking rows in one branded card.
class BookingPickupDateSection extends StatelessWidget {
  const BookingPickupDateSection({
    super.key,
    required this.group,
    required this.children,
    this.showTotalRental = true,
  });

  final BookingPickupDateGroup group;
  final List<Widget> children;
  final bool showTotalRental;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: kModalSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookingPickupDateHeader(
            group: group,
            showTotalRental: showTotalRental,
            embedded: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 17,
                      thickness: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
