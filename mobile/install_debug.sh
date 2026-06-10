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

BUILD_ARGS=(
  --dart-define-from-file=env/dev.json
  --dart-define=USE_ADB_REVERSE=true
)

if [[ ! -x "$ADB" && -x "${ADB}.exe" ]]; then
  ADB="${ADB}.exe"
fi

echo "Building debug APK (USB / adb reverse mode)..."
flutter build apk --debug "${BUILD_ARGS[@]}"

"$ADB" -s "$DEVICE" install -r "$APK"
"$ADB" -s "$DEVICE" reverse tcp:8000 tcp:8000
echo "Installed on $DEVICE (API via adb reverse -> host :8000)"
