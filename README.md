# Church Corner Toy Library App

Mobile-first platform for **Church Corner Toy Library** (Christchurch, New Zealand): catalog, bookings, lending, volunteer duty, library events, and admin tools — backed by a hosted FastAPI API and Supabase.

## About

**Theme:** A community toy library management system that replaces manual catalog and lending workflows with a single app for members, volunteers, and administrators. The stack supports role-based journeys (guest → member → volunteer → admin), Wed/Sat library sessions, and optional AI-assisted toy check-in at the volunteer desk.

**Purpose:** This project delivers a production-style pilot for a real toy library: browse ~1,200 toys, book pickups, manage loans and returns, run the duty roster and event schedule, and handle membership onboarding and payments — without relying on spreadsheets or a separate SETLS-only workflow.

| Component | Technology |
|-----------|------------|
| [`mobile/`](mobile/) | Flutter (Android pilot APK; iOS-capable) |
| [`backend/`](backend/) | FastAPI, SQLAlchemy, Postgres via Supabase |
| Auth & storage | Supabase Auth, JWT, Storage (toy photos) |
| Hosted API | Docker / [Railway](docs/DEPLOY.md) |
| CI | GitHub Actions (`pytest`, `flutter analyze`, `flutter test`) |

## Quick start

### Backend

Full setup: [`backend/README.md`](backend/README.md) (`.env`, SQL snippets, seeding, LAN access for device testing).

```bash
cd backend
python -m venv .venv
# activate .venv (see backend README for Windows / Git Bash)
pip install -r requirements.txt
cp .env.example .env   # DATABASE_URL, SUPABASE_URL, SUPABASE_JWT_SECRET, etc.
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- API docs: **http://127.0.0.1:8000/docs**
- Health: **http://127.0.0.1:8000/api/v1/health**

### Mobile

```bash
cd mobile
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

See [`mobile/README.md`](mobile/README.md) for production builds and `--dart-define` keys (`API_BASE`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

## Pilot deployment

| Task | Guide |
|------|--------|
| Supabase, Railway, env vars, cron | [`docs/DEPLOY.md`](docs/DEPLOY.md) |
| Build release APK | [`docs/DEPLOY.md` §4](docs/DEPLOY.md#4-mobile-android-release) |
| Install APK on Android phones | [`docs/DEPLOY.md` §5](docs/DEPLOY.md#5-install-the-apk-on-a-phone-pilot-sideload) |

Railway redeploys the API automatically when you push to `main` (if the repo is connected). Mobile changes require rebuilding and reinstalling `app-release.apk` on each device.

## Repository layout

```text
backend/          FastAPI app, SQL snippets, Docker/Railway config
mobile/           Flutter client
docs/DEPLOY.md    Production and sideload instructions
.github/          CI and scheduled reminder workflows
```
