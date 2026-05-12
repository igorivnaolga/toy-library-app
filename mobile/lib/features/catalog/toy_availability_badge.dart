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
          colors.secondaryContainer,
          colors.onSecondaryContainer,
        ),
      "on_loan" => (
          "On loan",
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
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
