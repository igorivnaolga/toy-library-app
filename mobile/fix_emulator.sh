#!/usr/bin/env bash
# Fix stuck Android emulator (package manager / install failures).
set -euo pipefail
cd "$(dirname "$0")"
exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./fix_emulator.ps1"
