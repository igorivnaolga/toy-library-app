import "package:url_launcher/url_launcher.dart";

import "library_info_copy.dart";

Future<void> openLibraryInGoogleMaps() {
  final uri = Uri.parse(
    "https://www.google.com/maps/search/?api=1"
    "&query=${LibraryInfoCopy.locationLat},${LibraryInfoCopy.locationLng}",
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchPhoneCall() {
  final uri = Uri(scheme: "tel", path: LibraryInfoCopy.coordinatorPhoneDial);
  return launchUrl(uri);
}

Future<void> launchCoordinatorEmail() {
  final uri = Uri(
    scheme: "mailto",
    path: LibraryInfoCopy.coordinatorEmail,
  );
  return launchUrl(uri);
}
