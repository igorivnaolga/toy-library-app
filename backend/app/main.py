"""
FastAPI application entrypoint.

`lifespan` is used for startup/shutdown hooks. We keep DB DDL optional because
production deployments should use migrations instead of `create_all`.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.base import Base
from app.db.session import get_engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    if settings.database_url and settings.create_tables_on_startup:
        engine = get_engine()
        if engine is not None:
            # Dev-only convenience: create ORM tables if they don't exist yet.
            Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Toy Library API", version="0.1.0", lifespan=lifespan)
app.include_router(api_router, prefix="/api/v1")
