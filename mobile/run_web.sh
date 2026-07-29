#!/usr/bin/env bash
# Launch Flutter web against local FastAPI on http://localhost:8000.
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f env/dev.json ]]; then
  echo "Missing env/dev.json — copy from env/dev.json.example and set Supabase keys."
  exit 1
fi

# Full restart so dart-defines (SUPABASE_*) are applied — hot reload is not enough.
flutter run -d chrome \
  --dart-define-from-file=env/dev.json \
  --dart-define=API_BASE=http://localhost:8000 \
  --dart-define=FIREBASE_ENABLED=false \
  "$@"
