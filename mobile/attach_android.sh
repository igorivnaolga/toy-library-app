#!/usr/bin/env bash
# Re-attach debugger after "Lost connection" (app still running on emulator).
set -euo pipefail
cd "$(dirname "$0")"

VM_PORT=58162
exec flutter attach --no-dds --host-vmservice-port="${VM_PORT}" --device-timeout=120 "$@"
