import "package:flutter/foundation.dart";

/// Resolves the FastAPI base URL (no trailing slash).
///
/// **Release builds** must pass an `https://` `API_BASE`
/// (`--dart-define-from-file=env/production.json`); otherwise this throws so a
/// misconfigured build fails loudly instead of calling an emulator address.
///
/// **Dev modes (pick one)**
/// 1. USB + `adb reverse` (recommended): `USE_ADB_REVERSE=true` — immune to LAN IP changes.
/// 2. Wi‑Fi: `API_BASE=http://<pc-lan-ip>:8000` — run `env/sync_api_base.sh` before building.
/// 3. Emulator: default `http://10.0.2.2:8000`, or mode 1 with `adb reverse`.
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment("API_BASE", defaultValue: "");
  return resolveApiBaseUrlFor(
    apiBase: fromEnv,
    useAdbReverse: const bool.fromEnvironment("USE_ADB_REVERSE", defaultValue: false),
    isRelease: kReleaseMode,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
}

/// Pure resolver behind [resolveApiBaseUrl] (separate so it can be unit tested).
@visibleForTesting
String resolveApiBaseUrlFor({
  required String apiBase,
  required bool useAdbReverse,
  required bool isRelease,
  required bool isWeb,
  required TargetPlatform platform,
}) {
  final trimmed = apiBase.trim().replaceAll(RegExp(r"/+$"), "");

  if (isRelease) {
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty || uri == null || uri.scheme != "https" || uri.host.isEmpty) {
      throw StateError(
        "Release build needs an https API_BASE "
        "(build with --dart-define-from-file=env/production.json).",
      );
    }
    return trimmed;
  }

  // USB dev wins over API_BASE so a stale IP in dev.json cannot break adb reverse installs.
  if (!isWeb && platform == TargetPlatform.android && useAdbReverse) {
    return "http://127.0.0.1:8000";
  }

  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  if (isWeb) {
    return "http://localhost:8000";
  }
  switch (platform) {
    case TargetPlatform.android:
      return "http://10.0.2.2:8000";
    default:
      return "http://127.0.0.1:8000";
  }
}
