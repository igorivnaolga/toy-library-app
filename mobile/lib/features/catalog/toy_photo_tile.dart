import "package:flutter/material.dart";

import "../../core/toy_photo_url.dart";

/// Loads the toy thumbnail from the backend photo endpoint; shows a neutral placeholder on failure.
class ToyPhotoTile extends StatelessWidget {
  const ToyPhotoTile({super.key, required this.toyId, this.size = 56});

  final String toyId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = toyPhotoHttpUrl(toyId);
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.toys, color: colors.outline),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
