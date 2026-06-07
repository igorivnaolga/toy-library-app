import "package:flutter/foundation.dart";

/// Resolves the FastAPI base URL (no trailing slash).
///
/// **Dev modes (pick one)**
/// 1. USB + `adb reverse` (recommended): `USE_ADB_REVERSE=true` — immune to LAN IP changes.
/// 2. Wi‑Fi: `API_BASE=http://<pc-lan-ip>:8000` — run `env/sync_api_base.sh` before building.
/// 3. Emulator: default `http://10.0.2.2:8000`, or mode 1 with `adb reverse`.
String resolveApiBaseUrl() {
  // USB dev wins over API_BASE so a stale IP in dev.json cannot break adb reverse installs.
  const useAdbReverse =
      bool.fromEnvironment("USE_ADB_REVERSE", defaultValue: false);

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      useAdbReverse) {
    return "http://127.0.0.1:8000";
  }

  const fromEnv = String.fromEnvironment("API_BASE", defaultValue: "");
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.replaceAll(RegExp(r"/+$"), "");
  }

  if (kIsWeb) {
    return "http://localhost:8000";
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return "http://10.0.2.2:8000";
    default:
      return "http://127.0.0.1:8000";
  }
}
