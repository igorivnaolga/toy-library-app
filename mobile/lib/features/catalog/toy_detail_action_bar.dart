import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "../bookings/pickup_date_banner.dart";
import "catalog_models.dart";

/// Sticky bottom bar for book / manage booking actions on toy detail.
class ToyDetailActionBar extends StatelessWidget {
  const ToyDetailActionBar({
    super.key,
    required this.toy,
    required this.isLoggedIn,
    required this.canBookToys,
    required this.myBooking,
    required this.bookingInProgress,
    required this.cancellingInProgress,
    required this.reschedulingInProgress,
    required this.onSignIn,
    required this.onBook,
    required this.onChangePickupDate,
    required this.onCancelBooking,
  });

  final ToyItem toy;
  final bool isLoggedIn;
  final bool canBookToys;
  final BookingItem? myBooking;
  final bool bookingInProgress;
  final bool cancellingInProgress;
  final bool reschedulingInProgress;
  final VoidCallback onSignIn;
  final VoidCallback onBook;
  final VoidCallback onChangePickupDate;
  final VoidCallback onCancelBooking;

  bool get _isAvailable => toy.availability == "available";

  String get _unavailableMessage {
    switch (toy.availability) {
      case "on_loan":
        return "This toy is on loan and can't be booked right now.";
      case "reserved":
        return "This toy is reserved and can't be booked right now.";
      case "unavailable":
        return "This toy isn't available for booking right now.";
      default:
        return "This toy isn't available for booking right now.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isLoggedIn)
                BrandChipButton(
                  label: "Sign in to book",
                  large: true,
                  onPressed: onSignIn,
                )
              else if (!canBookToys)
                Text(
                  "Complete membership setup to book toys from the catalog.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kBrandOnYellow.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                )
              else ...[
                if (myBooking?.pickupLabel != null) ...[
                  PickupDateBanner(pickupLabel: myBooking!.pickupLabel!),
                  const SizedBox(height: 12),
                ],
                if (bookingInProgress)
                  BrandChipButton(
                    label: "Booking…",
                    large: true,
                    onPressed: null,
                  )
                else if (myBooking != null) ...[
                  BrandChipButton(
                    label: reschedulingInProgress
                        ? "Updating…"
                        : "Change pickup date",
                    large: true,
                    onPressed: reschedulingInProgress || cancellingInProgress
                        ? null
                        : onChangePickupDate,
                  ),
                  const SizedBox(height: 8),
                  BrandChipButton(
                    label: cancellingInProgress
                        ? "Cancelling…"
                        : "Cancel booking",
                    large: true,
                    variant: BrandChipButtonVariant.outlined,
                    onPressed: reschedulingInProgress || cancellingInProgress
                        ? null
                        : onCancelBooking,
                  ),
                ] else if (_isAvailable)
                  BrandChipButton(
                    label: "Book this toy",
                    large: true,
                    onPressed: onBook,
                  )
                else
                  Text(
                    _unavailableMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: kBrandOnYellow.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
