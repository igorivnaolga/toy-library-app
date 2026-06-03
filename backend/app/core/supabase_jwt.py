"""Decode and verify Supabase-issued access tokens.

Supabase may sign access tokens with:

- **HS256** + project **JWT Secret** (legacy / symmetric), or
- **RS256 / ES256** (asymmetric) using JWKS at ``/auth/v1/.well-known/jwks.json``.

See: https://supabase.com/docs/guides/auth/signing-keys
"""

from __future__ import annotations

from functools import lru_cache
from typing import Any

import jwt
from fastapi import HTTPException
from jwt import PyJWKClient

from app.core.config import Settings

# Asymmetric algorithms Supabase may use (verify only the token's declared alg).
_ASYM_ALGS = frozenset({"RS256", "RS384", "RS512", "ES256", "ES384", "ES512"})


@lru_cache(maxsize=8)
def _jwks_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(jwks_url)


def decode_supabase_access_token(token: str, settings: Settings) -> dict[str, Any]:
    """
    Verify signature and standard claims on a Supabase access JWT.

    - **HS256:** requires ``SUPABASE_JWT_SECRET`` (Dashboard → Settings → API → JWT Secret).
    - **RS*/ES*:** verifies using JWKS; only ``SUPABASE_URL`` is required.
    """
    if not settings.supabase_url:
        raise HTTPException(
            status_code=503,
            detail="Auth is not configured (set SUPABASE_URL).",
        )

    base = settings.supabase_url.rstrip("/")
    issuer = f"{base}/auth/v1"
    jwks_url = f"{issuer}/.well-known/jwks.json"

    try:
        header = jwt.get_unverified_header(token)
    except jwt.exceptions.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}") from e

    alg = header.get("alg")
    if not isinstance(alg, str) or not alg:
        raise HTTPException(status_code=401, detail="Invalid token: missing alg")

    leeway = settings.supabase_jwt_leeway_seconds

    try:
        if alg == "HS256":
            if not settings.supabase_jwt_secret:
                raise HTTPException(
                    status_code=503,
                    detail=(
                        "Auth is not configured for HS256 tokens "
                        "(set SUPABASE_JWT_SECRET from Dashboard → Settings → API → JWT Secret). "
                        "If your project uses asymmetric keys only, use an access token signed with RS256/ES256."
                    ),
                )
            return jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
                issuer=issuer,
                leeway=leeway,
            )

        if alg in _ASYM_ALGS:
            signing_key = _jwks_client(jwks_url).get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=[alg],
                audience="authenticated",
                issuer=issuer,
                leeway=leeway,
            )

        raise HTTPException(
            status_code=401,
            detail=f"Unsupported JWT algorithm: {alg}",
        )
    except jwt.exceptions.PyJWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}") from e
