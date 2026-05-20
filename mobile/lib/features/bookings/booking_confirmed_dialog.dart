import "package:flutter/material.dart";

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
      final theme = Theme.of(ctx);
      return Dialog(
        backgroundColor: Colors.white,
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: kBrandOnYellow,
                      fontWeight: FontWeight.w700,
                    ),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: kBrandOnYellow,
                      fontWeight: FontWeight.w700,
                    ),
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
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: kBrandOnYellow.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                pickupLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: kBrandOnYellow,
                                  fontWeight: FontWeight.w700,
                                ),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kBrandOnYellow.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
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
