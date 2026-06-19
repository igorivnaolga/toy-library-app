import "package:url_launcher/url_launcher.dart";

import "library_info_copy.dart";

Future<void> openLibraryInGoogleMaps() async {
  final query = Uri.encodeComponent(LibraryInfoCopy.locationMapsQuery);
  final mapsUri = Uri.parse(
    "https://www.google.com/maps/search/?api=1&query=$query",
  );
  if (await canLaunchUrl(mapsUri)) {
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    return;
  }

  final geoUri = Uri.parse(
    "geo:0,0?q=${Uri.encodeComponent(LibraryInfoCopy.locationMapsQuery)}",
  );
  await launchUrl(geoUri, mode: LaunchMode.externalApplication);
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
