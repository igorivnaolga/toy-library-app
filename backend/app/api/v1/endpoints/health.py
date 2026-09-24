import logging

from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db.session import get_session_factory

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    """Liveness: the process is up (used by the Railway healthcheck)."""
    return {"status": "ok"}


@router.get("/health/ready")
def ready() -> dict[str, str]:
    """Readiness: the database answers a trivial query."""
    factory = get_session_factory()
    if factory is None:
        raise HTTPException(status_code=503, detail="Database is not configured.")
    try:
        with factory() as session:
            session.execute(text("select 1"))
    except Exception as exc:
        logger.warning("Readiness check failed: %s", exc)
        raise HTTPException(status_code=503, detail="Database unavailable.") from exc
    return {"status": "ready"}
