import "package:flutter/material.dart";

import "../../core/app_theme.dart";

/// Pickup day callout for a pending booking on the toy detail screen.
class PickupDateBanner extends StatelessWidget {
  const PickupDateBanner({
    super.key,
    required this.pickupLabel,
  });

  final String pickupLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kBrandYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, color: kBrandOnYellow.withValues(alpha: 0.85), size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pick up",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: kBrandOnYellow.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                pickupLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: kBrandOnYellow,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
