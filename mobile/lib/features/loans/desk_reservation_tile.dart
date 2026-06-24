import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "../catalog/toy_photo_tile.dart";

/// Compact reservation row for the walk-in checkout member panel.
class DeskReservationTile extends StatelessWidget {
  const DeskReservationTile({
    super.key,
    required this.booking,
    required this.loading,
    this.allowEarlyCheckout = false,
    this.hidePickupLabel = false,
    this.onOpen,
    this.onCheckOut,
  });

  final BookingItem booking;
  final bool loading;
  final bool allowEarlyCheckout;
  final bool hidePickupLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onCheckOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = bookingReadyForDeskCheckout(
      booking,
      allowEarlyForAdmin: allowEarlyCheckout,
    );
    final statusLabel = bookingDeskStatusLabel(
      booking,
      allowEarlyForAdmin: allowEarlyCheckout,
    );

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToyPhotoTile(
                      toyId: booking.toyId,
                      photoFile: booking.photoFile,
                      size: 52,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.toyName ?? booking.toyId,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.cardTitle,
                          ),
                          if (booking.toyId.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.toyId,
                              style: context.listSubtitle,
                            ),
                          ],
                          if (!hidePickupLabel &&
                              booking.pickupLabel != null &&
                              booking.pickupLabel!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.pickupLabel!,
                              style: context.listSubtitle,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style: context.listSubtitle.copyWith(
                              color: ready
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: ready
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            BrandChipButton(
              label: "Check out",
              fixedWidth: 100,
              onPressed: ready && onCheckOut != null && !loading
                  ? onCheckOut
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
