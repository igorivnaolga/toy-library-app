#!/usr/bin/env bash
# Reliable Android launch on Windows (avoids debug disconnects on emulator).
set -euo pipefail
cd "$(dirname "$0")"

ADB="${ANDROID_HOME:-/c/Users/igori/AppData/Local/Android/Sdk}/platform-tools/adb"
VM_PORT=58162

_wait_for_boot() {
  local i boot
  for i in $(seq 1 24); do
    boot=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
    if [[ "$boot" == "1" ]]; then
      return 0
    fi
    sleep 5
  done
  return 1
}

_ensure_emulator_ready() {
  [[ -x "$ADB" ]] || return 0

  if ! "$ADB" get-state >/dev/null 2>&1; then
    echo "No Android device/emulator detected. Start the emulator first."
    exit 1
  fi

  if "$ADB" shell pm list packages >/dev/null 2>&1; then
    "$ADB" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
    return 0
  fi

  echo "Emulator package manager is stuck (Can't find service: package)."
  echo "Rebooting emulator — wait ~30s..."
  "$ADB" reboot >/dev/null 2>&1 || true
  "$ADB" wait-for-device
  _wait_for_boot || {
    echo "Emulator did not finish booting. In Android Studio: AVD Manager -> Cold Boot Now."
    exit 1
  }

  if ! "$ADB" shell pm list packages >/dev/null 2>&1; then
    echo "Emulator still unhealthy. Close it and use AVD Manager -> Cold Boot Now."
    exit 1
  fi

  "$ADB" reverse tcp:8000 tcp:8000 >/dev/null 2>&1 || true
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

exec flutter run "${ARGS[@]}" "$@"
