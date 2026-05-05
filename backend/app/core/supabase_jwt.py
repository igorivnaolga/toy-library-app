"""Decode and verify Supabase-issued access tokens (HS256 + project JWT secret)."""

from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from jose import JWTError, jwt

from app.core.config import Settings


def decode_supabase_access_token(token: str, settings: Settings) -> dict[str, Any]:
    """
    Verify signature and standard claims on a Supabase access JWT.

    Requires `SUPABASE_URL` (for issuer) and `SUPABASE_JWT_SECRET` from the Supabase dashboard
    (Settings → API → JWT Secret).
    """
    if not settings.supabase_url or not settings.supabase_jwt_secret:
        raise HTTPException(
            status_code=503,
            detail="Auth is not configured (set SUPABASE_URL and SUPABASE_JWT_SECRET).",
        )
    issuer = f"{settings.supabase_url.rstrip('/')}/auth/v1"
    try:
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
            issuer=issuer,
        )
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}") from e
