"""
FastAPI application entrypoint.

The API never runs DDL: schema changes live in Alembic migrations
(`backend/migrations/`, applied with `alembic upgrade head`).
"""

import logging
import re

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)


def cors_options(settings: Settings) -> dict | None:
    """
    CORSMiddleware kwargs from ``CORS_ORIGINS``, or None when browser CORS is off.

    Exact origins go to ``allow_origins``; entries with ``*`` (e.g.
    ``http://localhost:*``) become an ``allow_origin_regex``; a lone ``*`` allows all.
    """
    entries = [o.strip().rstrip("/") for o in settings.cors_origins.split(",") if o.strip()]
    if not entries:
        return None
    if "*" in entries:
        logger.warning("CORS_ORIGINS=* allows any website to call this API; use only in development.")
        return {"allow_origins": ["*"]}
    exact = [o for o in entries if "*" not in o]
    patterns = [re.escape(o).replace(r"\*", "[^/]*") for o in entries if "*" in o]
    options: dict = {"allow_origins": exact}
    if patterns:
        options["allow_origin_regex"] = "^(" + "|".join(patterns) + ")$"
    return options


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    docs = settings.expose_api_docs
    app = FastAPI(
        title="Toy Library API",
        version="0.1.0",
        docs_url="/docs" if docs else None,
        redoc_url="/redoc" if docs else None,
        openapi_url="/openapi.json" if docs else None,
    )

    # Browser (Flutter web) needs CORS; Bearer tokens don't require credentials cookies.
    cors = cors_options(settings)
    if cors is not None:
        app.add_middleware(
            CORSMiddleware,
            allow_credentials=False,
            allow_methods=["*"],
            allow_headers=["*"],
            **cors,
        )

    app.include_router(api_router, prefix="/api/v1")
    return app


app = create_app()
