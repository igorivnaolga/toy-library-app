"""
Application configuration loaded from environment variables.

We load both `./.env` and `./backend/.env` so commands work whether your CWD is repo
root or `backend/` (common in VS Code terminals).
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Toy Library API"
    database_url: str | None = Field(
        default=None,
        description="Async/sync SQLAlchemy URL, e.g. postgresql+psycopg://...",
    )
    # When true, `app/main.py` will `create_all()` on startup (dev convenience).
    create_tables_on_startup: bool = False
    # Folder containing files named like `ToyOut.photo_file` (e.g. `142928.jpg`). See `GET /api/v1/toys/{id}/photo`.
    toy_images_dir: str | None = Field(
        default=None,
        description="Absolute or relative path to toy photo files on disk.",
    )
    # Supabase Auth — Settings → API: Project URL + JWT Secret (HS256 access tokens).
    supabase_url: str | None = Field(
        default=None,
        description="e.g. https://xxxx.supabase.co — used as JWT issuer base.",
    )
    supabase_jwt_secret: str | None = Field(
        default=None,
        description="Supabase JWT Secret (not the anon key). Used to verify Bearer tokens.",
    )
    supabase_jwt_leeway_seconds: int = Field(
        default=120,
        ge=0,
        le=600,
        description="Clock skew tolerance when validating access token iat/nbf/exp.",
    )
    firebase_credentials_path: str | None = Field(
        default=None,
        description="Path to Firebase service account JSON for FCM push (optional).",
    )
    cron_secret: str | None = Field(
        default=None,
        description="Shared secret for scheduled jobs (X-Cron-Secret header).",
    )


@lru_cache
def get_settings() -> Settings:
    # Cached so repeated access (e.g. per request) doesn't re-parse `.env` files.
    return Settings()
