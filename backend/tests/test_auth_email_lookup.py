"""Auth email lookup for sign-in UX."""

from __future__ import annotations

from unittest.mock import MagicMock

from app.repositories.profile_repo import auth_email_is_registered


def test_auth_email_is_registered_true() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = 1
    assert auth_email_is_registered(session, "Member@Example.com") is True
    session.execute.assert_called_once()


def test_auth_email_is_registered_false_when_missing() -> None:
    session = MagicMock()
    session.execute.return_value.scalar_one_or_none.return_value = None
    assert auth_email_is_registered(session, "unknown@example.com") is False


def test_auth_email_is_registered_false_for_blank() -> None:
    session = MagicMock()
    assert auth_email_is_registered(session, "   ") is False
    session.execute.assert_not_called()
