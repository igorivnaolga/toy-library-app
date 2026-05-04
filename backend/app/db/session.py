"""
SQLAlchemy engine + session factory.

`get_db` is the FastAPI dependency pattern (yield session, always close).
`session_scope` is for scripts / repositories where you manage lifecycle manually.
"""

from collections.abc import Generator
from typing import Optional

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings

_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker[Session]] = None


def get_engine() -> Engine | None:
    global _engine, _SessionLocal
    settings = get_settings()
    if not settings.database_url:
        return None
    if _engine is None:
        # `pool_pre_ping` avoids stale connections after laptop sleep / DB restarts.
        _engine = create_engine(settings.database_url, pool_pre_ping=True)
        _SessionLocal = sessionmaker(
            bind=_engine,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False,
        )
    return _engine


def get_session_factory() -> sessionmaker[Session] | None:
    get_engine()
    return _SessionLocal


def get_db() -> Generator[Session, None, None]:
    SessionLocal = get_session_factory()
    if SessionLocal is None:
        raise RuntimeError("DATABASE_URL is not configured")
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def session_scope() -> Session:
    """
    Create a new Session for non-FastAPI callers.

    IMPORTANT: caller must `close()` the session (see repositories/scripts).
    """
    SessionLocal = get_session_factory()
    if SessionLocal is None:
        raise RuntimeError("DATABASE_URL is not configured")
    return SessionLocal()
