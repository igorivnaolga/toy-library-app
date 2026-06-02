import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

import "../../core/app_text_styles.dart";
import "contact_links.dart";
import "library_info_copy.dart";

/// Whether the native Google Maps embed is available on this platform.
bool get libraryMapEmbedSupported {
  if (kIsWeb) return true;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

/// Embedded Google Map for the library location on the Contact tab.
///
/// On Windows/macOS/Linux (and other unsupported targets), shows a tappable
/// placeholder that opens Google Maps externally — avoids a runtime crash when
/// the map plugin has no platform implementation.
const _libraryPosition = LatLng(
  LibraryInfoCopy.locationLat,
  LibraryInfoCopy.locationLng,
);

class LibraryLocationMap extends StatelessWidget {
  const LibraryLocationMap({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: libraryMapEmbedSupported
            ? const _EmbeddedGoogleMap()
            : const _MapOpenExternallyPlaceholder(),
      ),
    );
  }
}

class _EmbeddedGoogleMap extends StatefulWidget {
  const _EmbeddedGoogleMap();

  static const _markerId = MarkerId("library");

  @override
  State<_EmbeddedGoogleMap> createState() => _EmbeddedGoogleMapState();
}

class _EmbeddedGoogleMapState extends State<_EmbeddedGoogleMap> {
  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _libraryPosition,
        zoom: 16,
      ),
      onMapCreated: (_) {},
      markers: {
        const Marker(
          markerId: _EmbeddedGoogleMap._markerId,
          position: _libraryPosition,
          infoWindow: InfoWindow(
            title: LibraryInfoCopy.libraryName,
            snippet: LibraryInfoCopy.locationAddressLine2,
          ),
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
    );
  }
}

class _MapOpenExternallyPlaceholder extends StatelessWidget {
  const _MapOpenExternallyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      child: InkWell(
        onTap: openLibraryInGoogleMaps,
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
    );
  }
}
