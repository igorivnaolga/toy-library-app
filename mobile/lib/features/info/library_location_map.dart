import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "contact_links.dart";
import "library_info_copy.dart";

/// Tappable map preview on the Contact tab — opens Google Maps with the library address.
///
/// Uses an external maps link (not an embedded map tile) so it works without a
/// Google Maps API key in release builds.
class LibraryLocationMap extends StatelessWidget {
  const LibraryLocationMap({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: colors.surfaceContainerLow,
        child: InkWell(
          onTap: openLibraryInGoogleMaps,
          child: SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 40,
                    color: colors.primary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LibraryInfoCopy.libraryName,
                    style: context.cardTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LibraryInfoCopy.locationAddressLine2,
                    style: context.listSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LibraryInfoCopy.locationAddressHint,
                    style: context.listSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Tap to open in Google Maps",
                    style: context.listSubtitle.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
