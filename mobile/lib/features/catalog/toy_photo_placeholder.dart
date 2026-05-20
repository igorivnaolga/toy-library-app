import "package:flutter/material.dart";

/// Simple grey placeholder when a toy has no photo or the image fails to load.
class ToyPhotoPlaceholder extends StatelessWidget {
  const ToyPhotoPlaceholder({
    super.key,
    this.size = 56,
    this.borderRadius = 8,
    this.expand = false,
  });

  final double size;
  final double borderRadius;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconSize = expand ? 64.0 : size * 0.46;

    final content = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.toys,
          size: iconSize,
          color: colors.outline,
        ),
      ),
    );

    if (expand) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: content),
    );
  }
}
