#!/usr/bin/env bash
# Fix stuck Android emulator (package manager / install failures).
# Usage: ./fix_emulator.sh [emulator-5554]
set -euo pipefail
cd "$(dirname "$0")"
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./fix_emulator.ps1" "${1:-}"
