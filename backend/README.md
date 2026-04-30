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

## Current Scope

- App entrypoint
- API router
- Health endpoint
- Initial requirements and env template
