# Backend

FastAPI backend for Toy Library app.

## Local Run (Step 6)

From VS Code terminal in `backend/`:

1. Create virtual environment:
   - `python -m venv .venv`
2. Activate:
   - Git Bash: `source .venv/Scripts/activate`
   - PowerShell: `.\.venv\Scripts\Activate.ps1`
3. Install dependencies:
   - `python -m pip install --upgrade pip`
   - `pip install -r requirements.txt`
4. Start API:
   - `uvicorn app.main:app --reload`
5. Verify:
   - `http://127.0.0.1:8000/api/v1/health`
   - `http://127.0.0.1:8000/docs`

## Week 1 (commit-sized chunks)

### Commit W1.1 - Database foundation (this change)

- Configure settings via environment variables (`.env`)
- Add SQLAlchemy engine + `Session` dependency (`get_db`)
- Add ORM models: `categories`, `toys`, `toy_images`
- Optional: `CREATE_TABLES_ON_STARTUP=true` to `create_all()` in dev

### Commit W1.2 - CSV → Postgres seed

- Implement `python -m app.scripts.seed_from_csv` to import:
  - `export_imgs/toy_photo_map_by_description.csv`
  - `export_imgs/Toys-categories.csv`

Run:

```bash
cd backend
source .venv/Scripts/activate
pip install -r requirements.txt
python -m app.scripts.seed_from_csv
```

### Commit W1.3 - Read from DB in API

- Update `/toys` and `/categories` to query Postgres when `DATABASE_URL` is set
- Keep CSV path as fallback (optional) while migrating

## Current Scope

- App entrypoint
- API router
- Health endpoint
- Initial requirements and env template
