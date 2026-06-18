# toy_library_mobile

Flutter client for Church Corner Toy Library.

## Development

```bash
flutter pub get
flutter run
```

Configure API and Supabase with `--dart-define` (see `lib/core/api_base_url.dart` and `env/production.json.example`).

## Install on a phone (pilot)

1. Build a release APK (requires `env/production.json` — see [`../docs/DEPLOY.md`](../docs/DEPLOY.md)):
   ```bash
   flutter build apk --release --dart-define-from-file=env/production.json
   ```
2. Install **`build/app/outputs/flutter-apk/app-release.apk`** on the device (not the `.sha1` file).

Full sideload steps (USB, Drive, unknown apps, Xiaomi, updates): [`../docs/DEPLOY.md` §5](../docs/DEPLOY.md#5-install-the-apk-on-a-phone-pilot-sideload).
