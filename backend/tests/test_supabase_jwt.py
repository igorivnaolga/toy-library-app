"""Access-token verification: algorithms pinned, aud/iss/exp enforced."""

from __future__ import annotations

import time
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException

from app.core import supabase_jwt
from app.core.config import Settings
from app.core.supabase_jwt import decode_supabase_access_token

SUPABASE_URL = "https://example.supabase.co"
ISSUER = f"{SUPABASE_URL}/auth/v1"
SECRET = "test-secret-that-is-long-enough-for-hs256-signing"


def _settings(**overrides) -> Settings:
    values = {
        "supabase_url": SUPABASE_URL,
        "supabase_jwt_secret": SECRET,
        "supabase_jwt_leeway_seconds": 0,
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def _claims(**overrides) -> dict:
    now = int(time.time())
    claims = {
        "sub": "7b3b3c2e-6f47-4a55-9a0c-2a8b7c1f0e11",
        "aud": "authenticated",
        "iss": ISSUER,
        "iat": now,
        "exp": now + 300,
    }
    claims.update(overrides)
    return claims


def _hs256(claims: dict, key: str = SECRET) -> str:
    return jwt.encode(claims, key, algorithm="HS256")


def _rejects(token: str, settings: Settings | None = None) -> None:
    with pytest.raises(HTTPException) as exc:
        decode_supabase_access_token(token, settings or _settings())
    assert exc.value.status_code == 401
    # Library error text must not leak to clients.
    assert exc.value.detail == "Invalid or expired token"


def test_valid_hs256_token_is_accepted() -> None:
    payload = decode_supabase_access_token(_hs256(_claims()), _settings())
    assert payload["sub"] == _claims()["sub"]


def test_wrong_audience_is_rejected() -> None:
    _rejects(_hs256(_claims(aud="anon")))


def test_wrong_issuer_is_rejected() -> None:
    _rejects(_hs256(_claims(iss="https://evil.supabase.co/auth/v1")))


def test_expired_token_is_rejected() -> None:
    _rejects(_hs256(_claims(exp=int(time.time()) - 10)))


def test_wrong_secret_is_rejected() -> None:
    _rejects(_hs256(_claims(), key="another-secret-that-is-also-long-enough"))


def test_alg_none_is_rejected() -> None:
    token = jwt.encode(_claims(), key=None, algorithm="none")
    with pytest.raises(HTTPException) as exc:
        decode_supabase_access_token(token, _settings())
    assert exc.value.status_code == 401


def test_unlisted_hmac_algorithm_is_rejected() -> None:
    token = jwt.encode(_claims(), SECRET, algorithm="HS512")
    with pytest.raises(HTTPException) as exc:
        decode_supabase_access_token(token, _settings())
    assert exc.value.status_code == 401


def test_hs256_can_be_disabled() -> None:
    _rejects(_hs256(_claims()), _settings(supabase_jwt_allow_hs256=False))


def test_garbage_token_is_rejected() -> None:
    _rejects("not-a-jwt")


def test_missing_supabase_url_is_503() -> None:
    with pytest.raises(HTTPException) as exc:
        decode_supabase_access_token(_hs256(_claims()), _settings(supabase_url=None))
    assert exc.value.status_code == 503


@pytest.fixture
def rsa_keys(monkeypatch: pytest.MonkeyPatch):
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    class _FakeJwks:
        def get_signing_key_from_jwt(self, _token: str):
            return SimpleNamespace(key=public_key)

    monkeypatch.setattr(supabase_jwt, "_jwks_client", lambda _url: _FakeJwks())
    return private_key


def test_valid_rs256_token_is_accepted(rsa_keys) -> None:
    token = jwt.encode(_claims(), rsa_keys, algorithm="RS256")
    payload = decode_supabase_access_token(token, _settings(supabase_jwt_secret=None))
    assert payload["aud"] == "authenticated"


def test_rs256_wrong_issuer_is_rejected(rsa_keys) -> None:
    token = jwt.encode(_claims(iss="https://evil/auth/v1"), rsa_keys, algorithm="RS256")
    _rejects(token, _settings(supabase_jwt_secret=None))


def test_rs256_token_signed_by_other_key_is_rejected(rsa_keys) -> None:
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    _rejects(jwt.encode(_claims(), other, algorithm="RS256"), _settings(supabase_jwt_secret=None))


def test_optional_principal_treats_expired_token_as_guest() -> None:
    from fastapi.security import HTTPAuthorizationCredentials
    from unittest.mock import MagicMock

    from app.core import auth_deps

    token = _hs256(_claims(exp=int(time.time()) - 10))
    creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    original = auth_deps.get_settings
    auth_deps.get_settings = lambda: _settings()
    try:
        assert auth_deps.get_optional_principal(MagicMock(), creds) is None
    finally:
        auth_deps.get_settings = original
