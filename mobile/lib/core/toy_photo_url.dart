import "api_base_url.dart";

/// Public HTTP URL for `GET /api/v1/toys/{toy_id}/photo` (same host as the JSON API).
String toyPhotoHttpUrl(String toyId) {
  final base = resolveApiBaseUrl();
  final id = Uri.encodeComponent(toyId);
  return "$base/api/v1/toys/$id/photo";
}
