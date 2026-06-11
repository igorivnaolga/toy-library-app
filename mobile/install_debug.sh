#!/usr/bin/env bash
# Build and install debug APK to a USB-connected phone (uses adb reverse, not LAN IP).
set -euo pipefail
cd "$(dirname "$0")"

ADB="${ANDROID_HOME:-/c/Users/igori/AppData/Local/Android/Sdk}/platform-tools/adb"
DEVICE="${1:-4feead8a}"
APK="build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -f env/dev.json ]]; then
  echo "Missing mobile/env/dev.json"
  echo "Copy env/dev.json.example to env/dev.json and fill in Supabase values."
  exit 1
fi

if grep -q '"FIREBASE_ENABLED"[[:space:]]*:[[:space:]]*"true"' env/dev.json \
   && [[ ! -f android/app/google-services.json ]]; then
  echo "FIREBASE_ENABLED is true but android/app/google-services.json is missing."
  echo "Download it from Firebase Console and copy google-services.json.example as a guide."
  exit 1
fi

BUILD_ARGS=(
  --dart-define-from-file=env/dev.json
  --dart-define=USE_ADB_REVERSE=true
)

if [[ ! -x "$ADB" && -x "${ADB}.exe" ]]; then
  ADB="${ADB}.exe"
fi

echo "Building debug APK (USB / adb reverse mode)..."
flutter build apk --debug "${BUILD_ARGS[@]}"

_install_apk() {
  local out
  if out=$("$ADB" -s "$DEVICE" install -r "$APK" 2>&1); then
    echo "$out"
    return 0
  fi
  echo "$out" >&2
  if [[ "$out" != *"INSTALL_FAILED_INSUFFICIENT_STORAGE"* ]]; then
    return 1
  fi

  echo "Emulator storage full — uninstalling old build and trimming caches..."
  "$ADB" -s "$DEVICE" uninstall com.example.toy_library_mobile >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" shell pm trim-caches 999999M >/dev/null 2>&1 || true
  "$ADB" -s "$DEVICE" install -r "$APK"
}

_install_apk
"$ADB" -s "$DEVICE" reverse tcp:8000 tcp:8000
echo "Installed on $DEVICE (API via adb reverse -> host :8000)"
