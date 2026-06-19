# Church Corner Toy Library — mobile app

Flutter client for members, volunteers, and admins.

## Development

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

For USB debugging with a local backend, see `run_android.sh` / `run_android.ps1` (`USE_ADB_REVERSE`).

Configure API and Supabase with `--dart-define` or `env/production.json` (`API_BASE`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

## Install on a phone (pilot)

1. Create `env/production.json` from `env/production.json.example` (see [`../docs/DEPLOY.md`](../docs/DEPLOY.md)).
2. Build:
   ```bash
   flutter build apk --release --dart-define-from-file=env/production.json
   ```
3. Install `build/app/outputs/flutter-apk/app-release.apk` on the device.

Full sideload steps: [`../docs/DEPLOY.md` §5](../docs/DEPLOY.md#5-install-the-apk-on-a-phone-pilot-sideload).
