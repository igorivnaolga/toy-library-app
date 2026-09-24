# Deployment guide

Pilot-ready deployment path: **Supabase** (database, auth, storage) + **hosted FastAPI** (Railway / Render / Fly) + **Android APK/AAB** with production `--dart-define` values.

## Checklist

### 1. Supabase (production project)

1. Create a **production** Supabase project (separate from dev).
2. Apply the schema with Alembic from `backend/` (with `DATABASE_URL` pointing at the project):
   - **New database:** `alembic upgrade head`
   - **Database already built from the old `supabase/snippets/*.sql`:** run once
     `alembic stamp 0001_baseline`, then `alembic upgrade head`.
   - Every later deploy that adds a migration: `alembic upgrade head` **before** the new API
     version starts (e.g. `railway run alembic upgrade head`, or a Railway pre-deploy command).
3. Enable Auth (email) and configure redirect URLs if needed.
4. Set `SUPABASE_SERVICE_ROLE_KEY` on the API (the toy-photos bucket comes from the baseline migration).
5. Upload catalog photos: `python -m app.scripts.migrate_toy_photos_to_supabase` (from `backend/`).
6. Seed toys if needed: `python -m app.scripts.seed_from_csv`.

### 2. Backend (hosted API)

**Option A — Railway (recommended)**

1. New project → **Deploy from GitHub** → set root directory to `backend/`.
2. Railway picks up `Dockerfile` and `railway.toml` automatically.
3. Set environment variables (see [Production env](#production-env)).
4. Deploy and verify: `GET https://<host>/api/v1/health`.

**Option B — Docker anywhere**

```bash
cd backend
docker build -t toy-library-api .
docker run --rm -p 8000:8000 --env-file .env.production toy-library-api
```

**Production env**

| Variable | Value |
|----------|--------|
| `DATABASE_URL` | Supabase **Session pooler** URI (`postgresql+psycopg://…pooler…`) |
| `CORS_ORIGINS` | Only for Flutter web: the web app's origin(s). Leave unset for mobile-only. |
| `SUPABASE_URL` | Project URL |
| `SUPABASE_JWT_SECRET` or JWKS | From Supabase → Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role (photo uploads) |
| `CRON_SECRET` | Long random string |
| `FIREBASE_CREDENTIALS_PATH` or JSON mount | Optional push notifications |

Do **not** commit `.env` or Firebase JSON.

### 3. GitHub Actions

**CI** (`.github/workflows/ci.yml`) runs on push/PR to `main`:

- `pytest` in `backend/`
- `flutter analyze` + `flutter test` in `mobile/`

**Cron reminders** (`.github/workflows/member-reminders-cron.yml`):

Add repository secrets:

- `PRODUCTION_API_URL` — e.g. `https://your-api.up.railway.app`
- `CRON_SECRET` — same as backend

Until secrets are set, the cron workflow skips safely.

### 4. Mobile (Android release)

1. Copy `mobile/env/production.json.example` → `mobile/env/production.json` (gitignored) and fill in values.
2. Copy `backend/.env.production.example` → `backend/.env.production` locally for Docker smoke tests (gitignored).
3. Build release APK:

```bash
cd mobile
flutter build apk --release \
  --dart-define-from-file=env/production.json
```

4. Or AAB for Play Store: `flutter build appbundle --release --dart-define-from-file=env/production.json`.

**`production.json` keys**

| Key | Example |
|-----|---------|
| `API_BASE` | `https://your-api.up.railway.app` |
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon key |

5. Before store release: change Android `applicationId` from `com.example.toy_library_mobile` and configure release signing in `android/app/build.gradle.kts`.

### 5. Install the APK on a phone (pilot sideload)

For pilot testers who are **not** installing from the Play Store yet. **Testers:** use [`TRY_THE_APP.md`](TRY_THE_APP.md) instead (GitHub Release download, install, sign in).

#### Build the file (once)

Follow [§4 Mobile (Android release)](#4-mobile-android-release) above. After a successful build, the installable file is:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Use **`app-release.apk`**.

#### Copy the APK to the phone

Any of these work:

| Method | Steps |
|--------|--------|
| **USB cable** | Connect the phone to your PC, copy `app-release.apk` to **Downloads** (or another folder you can find in the Files app). |
| **Cloud / chat** | Upload to Google Drive, Dropbox, or email it to yourself; open the link on the phone and download. |
| **ADB (developers)** | With USB debugging enabled: `adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk` |

#### Install on the phone

1. Open **Files** (or **Downloads**) and tap **`app-release.apk`**.
2. If Android asks to allow installs from that app (Files, Drive, Chrome, etc.), turn on **Install unknown apps** / **Allow from this source** for that app only.
3. Tap **Install**, then **Open**.

#### Install directly from your PC (optional, for developers)

With the phone connected and [USB debugging](https://developer.android.com/studio/debug/dev-options) enabled:

```bash
cd mobile
flutter install --release --dart-define-from-file=env/production.json
```

Or, after `flutter build apk`, run `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

### 6. Smoke test after deploy

- [ ] Health: `/api/v1/health`
- [ ] Sign in on device with production Supabase
- [ ] Browse catalog + toy photos load
- [ ] Book / loan / return flow (test member)
- [ ] Admin panel + duty desk
- [ ] Schedule → library events
- [ ] Trigger cron manually (GitHub Actions → *Member push reminders* → Run workflow)

## What is automated vs manual

| Step | Automated | Manual |
|------|-----------|--------|
| Tests on push | GitHub Actions CI | — |
| API container build | Dockerfile / Railway | First-time host setup |
| DB schema | Alembic migrations (CI applies them to a test DB) | `alembic upgrade head` per release |
| Push reminders | Cron workflow (DST-proof schedule) | Set secrets |
| Play Store | — | Signing, listing, upload |
