import "api_base_url.dart";

import "package:supabase_flutter/supabase_flutter.dart";

/// Public HTTP URL for `GET /api/v1/toys/{toy_id}/photo` (same host as the JSON API).
String toyPhotoHttpUrl(String toyId) {
  final base = resolveApiBaseUrl();
  final id = Uri.encodeComponent(toyId);
  return "$base/api/v1/toys/$id/photo";
}

/// Best URL for a catalog thumbnail: Supabase public storage when configured, else API.
String? toyPhotoUrl(String toyId, {String? photoFile}) {
  final name = photoFile?.trim();
  if (name == null || name.isEmpty) return null;
  if (name.startsWith("http://") || name.startsWith("https://")) {
    return name;
  }

  try {
    return Supabase.instance.client.storage
        .from("toy-photos")
        .getPublicUrl(name);
  } catch (_) {
    return toyPhotoHttpUrl(toyId);
  }
}
