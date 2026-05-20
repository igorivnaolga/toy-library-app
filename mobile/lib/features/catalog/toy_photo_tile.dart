import "package:flutter/material.dart";

import "../../core/toy_photo_url.dart";
import "toy_photo_placeholder.dart";

/// Loads the toy thumbnail from the backend photo endpoint; shows a branded placeholder on failure.
class ToyPhotoTile extends StatelessWidget {
  const ToyPhotoTile({
    super.key,
    required this.toyId,
    this.size = 56,
    this.photoFile,
  });

  final String toyId;
  final double size;
  final String? photoFile;

  /// Known missing photo from catalog data (`""`). `null` means try the API (e.g. bookings).
  bool get _knownNoPhoto =>
      photoFile != null && photoFile!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_knownNoPhoto) {
      return ToyPhotoPlaceholder(size: size);
    }

    final url = toyPhotoHttpUrl(toyId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => ToyPhotoPlaceholder(size: size),
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
