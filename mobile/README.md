# Church Corner Toy Library — mobile app

Flutter client for members, volunteers, and admins.

## Development

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

For USB debugging with a local backend, see `run_android.sh` / `run_android.ps1` (`USE_ADB_REVERSE`).

### Web (Chrome)

1. Start the backend on port 8000 (`uvicorn` with `--host 0.0.0.0` or `127.0.0.1`).
2. From `mobile/`:

```powershell
.\run_web.ps1
```

Or:

```bash
flutter run -d chrome --dart-define-from-file=env/dev.json --dart-define=API_BASE=http://localhost:8000 --dart-define=FIREBASE_ENABLED=false
```

Notes:
- Browser calls need CORS on the API: set `CORS_ORIGINS` (the backend dev `.env.example` allows `http://localhost:*`).
- Release builds require an `https://` `API_BASE`; the app throws at startup otherwise.
- On-device OCR / ML Kit and local push notifications are mobile-only; web skips them.
- Release build: `flutter build web --dart-define-from-file=env/production.json`

Configure API and Supabase with `--dart-define` or `env/production.json` (`API_BASE`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

## Install on a phone (pilot)

**Testers:** see [`../docs/TRY_THE_APP.md`](../docs/TRY_THE_APP.md) (download from a GitHub Release, install, sign in).

**Maintainers** — build and sideload:

1. Create `env/production.json` from `env/production.json.example` (see [`../docs/DEPLOY.md`](../docs/DEPLOY.md)).
2. Build:
   ```bash
   flutter build apk --release --dart-define-from-file=env/production.json
   ```
3. Install `build/app/outputs/flutter-apk/app-release.apk` on the device.

Full sideload steps: [`../docs/DEPLOY.md` §5](../docs/DEPLOY.md#5-install-the-apk-on-a-phone-pilot-sideload). Share [`../docs/TRY_THE_APP.md`](../docs/TRY_THE_APP.md) with testers.

Release signing, application ID and Firebase setup: [`../docs/ANDROID_RELEASE.md`](../docs/ANDROID_RELEASE.md).
