# Launch Flutter web against local FastAPI on http://localhost:8000.
# Requires: backend running on port 8000 and env/dev.json with Supabase keys.
Set-Location $PSScriptRoot

if (-not (Test-Path "env/dev.json")) {
  Write-Error "Missing env/dev.json — copy from env/dev.json.example and set Supabase keys."
  exit 1
}

& flutter run -d chrome `
  --dart-define-from-file=env/dev.json `
  --dart-define=API_BASE=http://localhost:8000 `
  --dart-define=FIREBASE_ENABLED=false `
  @args
