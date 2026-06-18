# Deployment guide

Pilot-ready deployment path: **Supabase** (database, auth, storage) + **hosted FastAPI** (Railway / Render / Fly) + **Android APK/AAB** with production `--dart-define` values.

## Checklist

### 1. Supabase (production project)

1. Create a **production** Supabase project (separate from dev).
2. Run SQL snippets **in numeric order** in the SQL editor (`backend/supabase/snippets/`):
   - `001_profiles.sql` through `021_push_notifications.sql`
   - Run `002_catalog.sql` after `001_profiles.sql` (before bookings that reference toys).
   - Apply both `007_kids_birth_dates.sql` and `007_registration_fields.sql`.
3. Enable Auth (email) and configure redirect URLs if needed.
4. Run `017_toy_photos_storage.sql` and set `SUPABASE_SERVICE_ROLE_KEY` on the API.
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
| `CREATE_TABLES_ON_STARTUP` | `false` |
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

### 5. Smoke test after deploy

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
| DB schema | SQL snippets | Run once in Supabase |
| Push reminders | Cron workflow | Set secrets + tune UTC times |
| Play Store | — | Signing, listing, upload |
