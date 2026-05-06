import "package:flutter/foundation.dart";

/// Resolves the FastAPI base URL (no trailing slash).
///
/// **Overrides**
/// - Any platform: `--dart-define=API_BASE=http://192.168.1.10:8000` (physical phone on LAN).
/// - Android emulator only: if `10.0.2.2` hits "Network is unreachable" on Windows,
///   run `adb reverse tcp:8000 tcp:8000` and start with `--dart-define=USE_ADB_REVERSE=true`.
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment("API_BASE", defaultValue: "");
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.replaceAll(RegExp(r"/+$"), "");
  }

  // When true, Android calls 127.0.0.1:8000; with `adb reverse tcp:8000 tcp:8000` that forwards to the host.
  const useAdbReverse =
      bool.fromEnvironment("USE_ADB_REVERSE", defaultValue: false);

  if (kIsWeb) {
    return "http://localhost:8000";
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      if (useAdbReverse) {
        return "http://127.0.0.1:8000";
      }
      return "http://10.0.2.2:8000";
    default:
      return "http://127.0.0.1:8000";
  }
}
