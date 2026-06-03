import "package:flutter/material.dart";

/// Compact toy library number label (catalog cards and detail screen).
class ToyIdBadge extends StatelessWidget {
  const ToyIdBadge({
    super.key,
    required this.toyId,
    this.compact = true,
  });

  final String toyId;

  /// Small label on catalog rows; detail screen uses status-chip sizing.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final id = toyId.trim();
    if (id.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final chipStyle = Theme.of(context).textTheme.labelSmall;

    if (!compact) {
      return Chip(
        label: Text("ID $id"),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: chipStyle?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.onSurface.withValues(alpha: 0.72),
        ),
        backgroundColor: colors.surfaceContainerHighest,
        side: BorderSide.none,
        padding: EdgeInsets.zero,
      );
    }

    final labelStyle = chipStyle?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: colors.onSurface.withValues(alpha: 0.75),
      letterSpacing: 0.05,
      height: 1.0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text("ID $id", style: labelStyle),
    );
  }
}
