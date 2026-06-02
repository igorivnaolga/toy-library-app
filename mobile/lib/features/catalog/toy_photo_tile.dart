import "package:flutter/material.dart";

import "../../core/toy_photo_url.dart";
import "toy_photo_placeholder.dart";

/// Loads the toy thumbnail from the backend photo endpoint; shows a branded placeholder on failure.
class ToyPhotoTile extends StatefulWidget {
  const ToyPhotoTile({
    super.key,
    required this.toyId,
    this.size = 56,
    this.photoFile,
  });

  final String toyId;
  final double size;
  final String? photoFile;

  @override
  State<ToyPhotoTile> createState() => _ToyPhotoTileState();
}

class _ToyPhotoTileState extends State<ToyPhotoTile> {
  bool _loadFailed = false;

  /// Skip the photo endpoint when the catalog has no image filename.
  bool get _knownNoPhoto {
    final name = widget.photoFile?.trim();
    return name == null || name.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_knownNoPhoto || _loadFailed) {
      return ToyPhotoPlaceholder(size: widget.size);
    }

    final url = toyPhotoHttpUrl(widget.toyId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            if (!_loadFailed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loadFailed = true);
              });
            }
            return ToyPhotoPlaceholder(size: widget.size);
          },
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
