# toy-library-app

## Project Theme
AI-assisted mobile Toy Library Management System for community toy libraries, designed to improve catalog access, booking and lending workflows, and inventory control through role-based user journeys and computer-vision-assisted check-in.

## Project Purpose
This diploma project aims to design and implement a mobile-first information system that replaces fragmented manual toy library operations with a centralized digital platform.
The system enables guests, members, and administrators to work with the toy catalog and lending workflows efficiently, while adding AI-assisted inventory verification to reduce check-in errors during toy returns.

## Quick start

| Folder | Role |
|--------|------|
| [`backend/`](backend/) | FastAPI REST API, Postgres (Supabase), JWT auth |
| [`mobile/`](mobile/) | Flutter client |

**Backend — full instructions:** [`backend/README.md`](backend/README.md) (environment variables, seeding, running on `0.0.0.0` for a phone/emulator on the LAN).

Minimal run from `backend/` after Python 3.11+ and a configured `.env`:

```bash
python -m venv .venv
# activate .venv (see backend README for Windows/Git Bash)
pip install -r requirements.txt
cp .env.example .env   # set DATABASE_URL, Supabase settings, etc.
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Then open **http://127.0.0.1:8000/docs** (Swagger) and **http://127.0.0.1:8000/api/v1/health**.

**Mobile app:** from `mobile/`, run `flutter pub get` and `flutter run`. Configure the API base URL and Supabase keys with `--dart-define` as in your setup (see `mobile/lib/core/api_base_url.dart` and `mobile/lib/main.dart`).

**Deploying a pilot:** see [`docs/DEPLOY.md`](docs/DEPLOY.md) (Supabase, Docker/Railway, CI, cron, release APK).

**Install on Android (pilot testers):** build `app-release.apk`, copy it to the phone, and sideload — full steps in [`docs/DEPLOY.md` §5](docs/DEPLOY.md#5-install-the-apk-on-a-phone-pilot-sideload).
