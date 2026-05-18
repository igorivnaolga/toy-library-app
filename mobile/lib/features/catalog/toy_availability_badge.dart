import "package:flutter/material.dart";

/// Compact label for the backend `ToyOut.availability` code.
class ToyAvailabilityBadge extends StatelessWidget {
  const ToyAvailabilityBadge({
    super.key,
    required this.availability,
  });

  final String availability;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    final (label, background, foreground) = switch (availability) {
      "available" => (
          "Available",
          const Color(0xFFC8E6C9),
          const Color(0xFF2E7D32),
        ),
      "on_loan" => (
          "On loan",
          const Color(0xFFFFE0B2),
          const Color(0xFFE65100),
        ),
      "reserved" => (
          "Reserved",
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
      "unavailable" => (
          "Unavailable",
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      _ => (
          "Unknown",
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
        ),
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: style?.copyWith(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
