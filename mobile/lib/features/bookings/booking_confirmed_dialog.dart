import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";

/// Branded confirmation dialog after a successful toy booking.
Future<void> showBookingConfirmedDialog(
  BuildContext context, {
  required String toyName,
  required String pickupLabel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        backgroundColor: kModalSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                color: kBrandYellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: kBrandOnYellow,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Booking confirmed",
                    style: ctx.modalTitleOnYellow,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    toyName,
                    style: ctx.modalOptionTitle,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kBrandYellow.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 22,
                          color: kBrandOnYellow.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pick up",
                                style: ctx.captionOnYellow.copyWith(
                                  color: kBrandOnYellow.withValues(alpha: 0.65),
                                ),
                              ),
                              Text(
                                pickupLabel,
                                style: ctx.modalOptionTitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "View your booking anytime under the Bookings tab.",
                    style: ctx.bodyOnYellow.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: BrandChipButton(
                label: "OK",
                large: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
