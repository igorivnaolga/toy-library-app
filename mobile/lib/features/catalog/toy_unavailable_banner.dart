import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../loans/loan_models.dart";

/// Info callout when a toy cannot be booked from the detail action bar.
class ToyUnavailableBanner extends StatelessWidget {
  const ToyUnavailableBanner({
    super.key,
    required this.availability,
    this.myActiveLoan,
  });

  final String availability;
  final LoanItem? myActiveLoan;

  ({IconData icon, Color background, Color foreground, String message})
      get _content {
    switch (availability) {
      case "on_loan":
        final mine = myActiveLoan;
        if (mine != null) {
          final due = formatDisplayDate(mine.dueDate);
          final message = mine.isOverdue
              ? "You have this toy on loan. It was due $due — please return it soon."
              : "You have this toy on loan. Due back $due.";
          return (
            icon: Icons.assignment_outlined,
            background: kBrandYellow.withValues(alpha: 0.22),
            foreground: kBrandOnYellow,
            message: message,
          );
        }
        return (
          icon: Icons.sync,
          background: const Color(0xFFFFE0B2).withValues(alpha: 0.45),
          foreground: const Color(0xFFE65100),
          message: "This toy is on loan and can't be booked right now.",
        );
      case "reserved":
        return (
          icon: Icons.event_busy_outlined,
          background: kBrandYellow.withValues(alpha: 0.18),
          foreground: kBrandOnYellow,
          message: "This toy is reserved and can't be booked right now.",
        );
      case "unavailable":
        return (
          icon: Icons.block_outlined,
          background: const Color(0xFFFFEBEE),
          foreground: const Color(0xFFC62828),
          message: "This toy isn't available for booking right now.",
        );
      default:
        return (
          icon: Icons.info_outline,
          background: const Color(0xFFF5F5F5),
          foreground: kBrandOnYellow.withValues(alpha: 0.72),
          message: "This toy isn't available for booking right now.",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: content.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            content.icon,
            color: content.foreground.withValues(alpha: 0.9),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content.message,
              style: context.listSubtitle.copyWith(
                color: content.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral helper when the member must finish onboarding before booking.
class ToyBookingHintBanner extends StatelessWidget {
  const ToyBookingHintBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: colors.onSurface.withValues(alpha: 0.55),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.listSubtitle.copyWith(
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
