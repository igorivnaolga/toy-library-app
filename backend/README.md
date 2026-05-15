# Toy Library — Backend (FastAPI)

REST API for the Toy Library mobile app: catalog, categories, toy photos, and Supabase-backed authentication (`/api/v1/auth/me`).

## Prerequisites

- **Python 3.11+** (3.12 works)
- **PostgreSQL** — use [Supabase](https://supabase.com) or any Postgres instance  
- Optional: **toy photos** on disk if you use `GET /api/v1/toys/{id}/photo`

## 1. Clone and enter the backend folder

From the repository root:

```bash
cd backend
```

All commands below assume your current directory is **`backend/`** (so imports like `app.main:app` resolve correctly).

## 2. Virtual environment

Create and activate a virtual environment:

**Git Bash / Linux / macOS**

```bash
python -m venv .venv
source .venv/Scripts/activate   # Windows Git Bash
# or: source .venv/bin/activate  # Linux / macOS
```

**PowerShell (Windows)**

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

## 3. Install dependencies

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

If `uvicorn` is not found after this, use `python -m uvicorn` instead of plain `uvicorn` (see below).

## 4. Environment variables

Copy the example file and edit it:

```bash
cp .env.example .env
```

Fill at least:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | SQLAlchemy URL, e.g. `postgresql+psycopg://postgres.[ref]:PASSWORD@...pooler.supabase.com:6543/postgres` |
| `CREATE_TABLES_ON_STARTUP` | Set `true` in development so tables are created on startup (use migrations in production) |
| `SUPABASE_URL` | Project URL from Supabase → Settings → API |
| `SUPABASE_JWT_SECRET` | **JWT Secret** from the same page (not the anon key) — required when Supabase signs access tokens with **HS256**. Newer projects may use **asymmetric** signing (RS256/ES256); the API then verifies using **JWKS** and only needs `SUPABASE_URL`. |

Optional:

| Variable | Purpose |
|----------|---------|
| `TOY_IMAGES_DIR` | Absolute path to a folder of image files named like `photo_file` in the DB (e.g. `142928.jpg`). If unset, the API may fall back to `<repo>/toy_library_photos` when present. |

Settings are loaded from **`backend/.env`** (and also **`./.env`** at repo root if present).

Apply Supabase SQL for user profiles (signup → `public.profiles`) when you use Auth:

- `backend/supabase/snippets/001_profiles.sql`

## 5. Seed the database (optional)

After `DATABASE_URL` is set in `.env`:

```bash
python -m app.scripts.seed_from_csv
```

This creates tables if needed and imports CSV seed data (paths are defined in the seed service). Requires CSV assets under the repo as expected by the script.

## 6. Run the API

**Local development (reload on code changes):**

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

If `uvicorn` is not on your PATH:

```bash
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

**Phone / emulator on the same LAN as your PC** — bind on all interfaces so the device can reach your machine (use your PC’s LAN IP in the app, not `127.0.0.1`):

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 7. Verify

Open in a browser:

- Interactive docs (Swagger): **http://127.0.0.1:8000/docs**
- Health check: **http://127.0.0.1:8000/api/v1/health**
- Catalog filter metadata (distinct age ranges from DB or CSV fallback): **http://127.0.0.1:8000/api/v1/toys/meta**

Protected routes need a valid Supabase **access token** in the header: `Authorization: Bearer <token>`.

## Project layout (short)

- `app/main.py` — FastAPI app and lifespan (optional `create_all` in dev)
- `app/api/v1/` — HTTP routers (toys, categories, auth, health)
- `app/core/` — settings, JWT helpers, RBAC dependencies
- `app/models/`, `app/repositories/`, `app/schemas/` — data layer
- `app/scripts/seed_from_csv.py` — CLI seed entrypoint
