#!/usr/bin/env bash
# Build (optional) and install debug APK to a connected phone.
set -euo pipefail
cd "$(dirname "$0")"

ADB="${ANDROID_HOME:-/c/Users/igori/AppData/Local/Android/Sdk}/platform-tools/adb"
DEVICE="${1:-4feead8a}"
APK="build/app/outputs/flutter-apk/app-debug.apk"

if [[ ! -x "$ADB" && -x "${ADB}.exe" ]]; then
  ADB="${ADB}.exe"
fi

if [[ ! -f "$APK" ]]; then
  echo "APK not found. Building..."
  flutter build apk --debug \
    --dart-define-from-file=env/dev.json \
    --dart-define=USE_ADB_REVERSE=true
fi

"$ADB" -s "$DEVICE" install -r "$APK"
"$ADB" -s "$DEVICE" reverse tcp:8000 tcp:8000
echo "Installed on $DEVICE"
