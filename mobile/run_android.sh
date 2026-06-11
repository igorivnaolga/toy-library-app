#!/usr/bin/env bash
# Reliable Android launch on Windows (avoids debug disconnects on emulator).
set -euo pipefail
cd "$(dirname "$0")"

ADB="${ANDROID_HOME:-/c/Users/igori/AppData/Local/Android/Sdk}/platform-tools/adb"
VM_PORT=58162
TARGET_DEVICE=""
FLUTTER_ARGS=("$@")
if [[ $# -gt 0 && "$1" == emulator-* ]]; then
  TARGET_DEVICE="$1"
  FLUTTER_ARGS=("${@:2}")
fi

if [[ ! -x "$ADB" && -x "${ADB}.exe" ]]; then
  ADB="${ADB}.exe"
fi

_resolve_emulator_serial() {
  if [[ -n "$TARGET_DEVICE" ]]; then
    echo "$TARGET_DEVICE"
    return
  fi
  local serials count
  serials=$("$ADB" devices 2>/dev/null | awk '/^emulator-[0-9]+\tdevice/ { print $1 }')
  count=$(printf "%s\n" "$serials" | sed '/^$/d' | wc -l | tr -d ' ')
  if [[ "$count" -eq 1 ]]; then
    printf "%s\n" "$serials" | head -1
    return
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "Multiple emulators connected. Pass serial: ./run_android.sh emulator-5554" >&2
    exit 1
  fi
  echo "No emulator found. Start the emulator (phone-only adb will not work here)." >&2
  exit 1
}

EMULATOR_SERIAL="$(_resolve_emulator_serial)"
ADB_DEVICE=(-s "$EMULATOR_SERIAL")
echo "Using emulator: $EMULATOR_SERIAL"

_wait_for_boot() {
  local i boot
  for i in $(seq 1 24); do
    boot=$("$ADB" "${ADB_DEVICE[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
    if [[ "$boot" == "1" ]]; then
      return 0
    fi
    sleep 5
  done
  return 1
}

_ensure_emulator_ready() {
  if ! "$ADB" "${ADB_DEVICE[@]}" get-state >/dev/null 2>&1; then
    echo "Emulator $EMULATOR_SERIAL not ready. Start it or run ./fix_emulator.sh $EMULATOR_SERIAL"
    exit 1
  fi

  if "$ADB" "${ADB_DEVICE[@]}" shell pm list packages >/dev/null 2>&1; then
    "$ADB" "${ADB_DEVICE[@]}" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
    return 0
  fi

  echo "Emulator package manager is stuck (Can't find service: package)."
  echo "Rebooting emulator — wait ~30s..."
  "$ADB" "${ADB_DEVICE[@]}" reboot >/dev/null 2>&1 || true
  "$ADB" "${ADB_DEVICE[@]}" wait-for-device
  _wait_for_boot || {
    echo "Emulator did not finish booting. In Android Studio: AVD Manager -> Cold Boot Now."
    exit 1
  }

  if ! "$ADB" "${ADB_DEVICE[@]}" shell pm list packages >/dev/null 2>&1; then
    echo "Emulator still unhealthy. Close it and use AVD Manager -> Cold Boot Now."
    exit 1
  fi

  "$ADB" "${ADB_DEVICE[@]}" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
}

_ensure_emulator_ready

ARGS=(
  --no-dds
  --host-vmservice-port="${VM_PORT}"
  --device-timeout=120
  --dart-define=USE_ADB_REVERSE=true
)
if [[ -f env/dev.json ]]; then
  ARGS+=(--dart-define-from-file=env/dev.json)
fi

exec flutter run -d "$EMULATOR_SERIAL" "${ARGS[@]}" "${FLUTTER_ARGS[@]}"
