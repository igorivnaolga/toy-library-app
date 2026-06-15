#!/usr/bin/env bash
# Patch env/dev.json with this PC's current LAN IP (Wi-Fi dev, no USB).
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f dev.json ]]; then
  echo "Copy dev.json.example to dev.json first." >&2
  exit 1
fi

IP=$(
  ipconfig 2>/dev/null \
    | grep -i "IPv4" \
    | head -1 \
    | sed 's/.*: //' \
    | tr -d ' \r'
)

if [[ -z "$IP" ]]; then
  echo "Could not detect LAN IPv4 address." >&2
  exit 1
fi

python - <<PY
import json
from pathlib import Path

path = Path("dev.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["API_BASE"] = "http://${IP}:8000"
data["USE_ADB_REVERSE"] = "false"
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"dev.json -> API_BASE=http://${IP}:8000, USE_ADB_REVERSE=false")
print("Rebuild the app after this change.")
PY
