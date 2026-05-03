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
    create_tables_on_startup: bool = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
