"""Regression tests for the 2026-09 security/integrity review fixes."""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from app.core.config import Settings
from app.core.date_ranges import MAX_RANGE_DAYS, require_bounded_range
from app.core.rate_limit import RateLimiter, client_ip
from app.main import cors_options, create_app
from app.schemas.principal import ProfileUpdateIn, validate_avatar_path
from app.services.payment_service import PaymentError, mark_payment_paid, record_top_up
from app.utils.text import like_contains


# --- LIKE escaping ---------------------------------------------------------


def test_like_contains_escapes_wildcards() -> None:
    assert like_contains("a_b%c\\d") == "%a\\_b\\%c\\\\d%"
    assert like_contains("plain") == "%plain%"


# --- Rate limiting ---------------------------------------------------------


def test_rate_limiter_blocks_after_limit_and_recovers() -> None:
    limiter = RateLimiter(max_calls=2, window_seconds=60)
    assert limiter.check("ip", now=0)
    assert limiter.check("ip", now=1)
    assert not limiter.check("ip", now=2)
    assert limiter.check("other-ip", now=2)
    assert limiter.check("ip", now=61.5)


def test_client_ip_uses_proxy_appended_forwarded_entry() -> None:
    request = SimpleNamespace(
        headers={"x-forwarded-for": "6.6.6.6, 203.0.113.9"},
        client=SimpleNamespace(host="10.0.0.1"),
    )
    assert client_ip(request) == "203.0.113.9"


def test_email_lookup_is_rate_limited(monkeypatch: pytest.MonkeyPatch) -> None:
    from fastapi.testclient import TestClient

    from app.api.v1.endpoints import auth
    from app.db.session import get_db
    from app.main import app

    monkeypatch.setattr(auth, "auth_email_is_registered", lambda _db, _email: False)
    monkeypatch.setattr(auth, "_email_lookup_limiter", RateLimiter(max_calls=10, window_seconds=60))
    # Rebind the dependency closure to the fresh limiter.
    route = next(r for r in app.routes if getattr(r, "path", "") == "/api/v1/auth/email-registered")
    app.dependency_overrides[get_db] = lambda: MagicMock()
    guard = route.dependant.dependencies[-1].call
    app.dependency_overrides[guard] = auth._email_lookup_limiter.dependency()
    try:
        client = TestClient(app)
        statuses = [
            client.get("/api/v1/auth/email-registered", params={"email": "a@example.com"}).status_code
            for _ in range(11)
        ]
    finally:
        app.dependency_overrides.clear()
    assert statuses[:10] == [200] * 10
    assert statuses[10] == 429


# --- CORS / docs -----------------------------------------------------------


def _settings(**values) -> Settings:
    return Settings(_env_file=None, **values)


def test_cors_disabled_by_default() -> None:
    assert cors_options(_settings()) is None


def test_cors_wildcard_port_becomes_regex() -> None:
    options = cors_options(_settings(cors_origins="https://app.example.org, http://localhost:*"))
    assert options is not None
    assert options["allow_origins"] == ["https://app.example.org"]
    import re

    pattern = re.compile(options["allow_origin_regex"])
    assert pattern.fullmatch("http://localhost:5173")
    assert not pattern.fullmatch("http://localhost.evil.com")
    assert not pattern.fullmatch("https://evil.example")


def test_api_docs_hidden_unless_enabled() -> None:
    from fastapi.testclient import TestClient

    assert TestClient(create_app(_settings())).get("/openapi.json").status_code == 404
    assert TestClient(create_app(_settings(expose_api_docs=True))).get("/openapi.json").status_code == 200


# --- Date ranges -----------------------------------------------------------


def test_require_bounded_range() -> None:
    start = date(2026, 1, 1)
    require_bounded_range(start, start + timedelta(days=MAX_RANGE_DAYS))
    with pytest.raises(HTTPException) as exc:
        require_bounded_range(start, start + timedelta(days=MAX_RANGE_DAYS + 1))
    assert exc.value.status_code == 422
    with pytest.raises(HTTPException):
        require_bounded_range(start, start - timedelta(days=1))


def test_roster_generation_is_clamped_to_window() -> None:
    from app.services import duty_service

    inserted: list[list] = []
    today = date(2026, 9, 24)
    with patch.object(duty_service, "list_duty_sessions", return_value=[]), patch.object(
        duty_service, "insert_missing_duty_sessions", side_effect=lambda _s, rows: inserted.append(rows)
    ):
        duty_service.ensure_roster_sessions(
            MagicMock(),
            from_date=date(2000, 1, 1),
            to_date=date(9999, 12, 31),
            today=today,
        )
    days = [row[0] for row in inserted[0]]
    assert min(days) >= today - timedelta(days=duty_service.ROSTER_PAST_DAYS)
    assert max(days) <= today + timedelta(days=duty_service.ROSTER_FUTURE_DAYS)
    assert all(day.weekday() in {2, 5} for day in days)


# --- Profile update validation --------------------------------------------


def test_profile_update_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        ProfileUpdateIn.model_validate({"role": "admin"})


def test_profile_update_validates_phone_and_length() -> None:
    with pytest.raises(ValidationError):
        ProfileUpdateIn.model_validate({"mobile_phone": "not a phone"})
    with pytest.raises(ValidationError):
        ProfileUpdateIn.model_validate({"skills": "x" * 501})


def test_profile_update_rejects_future_registration_date() -> None:
    with pytest.raises(ValidationError):
        ProfileUpdateIn.model_validate({"registered_at": "2999-01-01"})


def test_profile_update_allows_clearing_optional_fields() -> None:
    body = ProfileUpdateIn.model_validate({"address_line2": "", "skills": None})
    assert body.address_line2 is None


def test_avatar_path_must_belong_to_caller() -> None:
    uid = uuid.uuid4()
    assert validate_avatar_path(f"{uid}/avatar_1.jpg", uid) == f"{uid}/avatar_1.jpg"
    assert validate_avatar_path("  ", uid) is None
    for bad in (
        f"{uuid.uuid4()}/avatar.jpg",
        "https://tracker.example/pixel.png",
        f"{uid}/../other/avatar.jpg",
        f"{uid}/nested/avatar.jpg",
        f"{uid}/",
    ):
        with pytest.raises(ValueError):
            validate_avatar_path(bad, uid)


# --- Payments: self-recording and idempotency -------------------------------


def test_staff_cannot_mark_own_charge_paid() -> None:
    staff_id = uuid.uuid4()
    payment = SimpleNamespace(id=uuid.uuid4(), user_id=staff_id, status="pending")
    with patch("app.services.payment_service.get_payment_by_id", return_value=payment):
        with pytest.raises(PaymentError) as exc:
            mark_payment_paid(MagicMock(), payment.id, method="cash", recorded_by=staff_id)
    assert exc.value.code == "self_payment_forbidden"


def test_staff_cannot_top_up_own_account() -> None:
    staff_id = uuid.uuid4()
    with pytest.raises(PaymentError) as exc:
        record_top_up(MagicMock(), staff_id, amount_cents=500, method="cash", recorded_by=staff_id)
    assert exc.value.code == "self_payment_forbidden"


def test_top_up_retry_with_same_key_returns_original() -> None:
    existing = SimpleNamespace(payment_type="top_up", amount_cents=2000, status="paid_cash")
    with patch(
        "app.services.payment_service.get_payment_by_idempotency_key",
        return_value=existing,
    ), patch("app.services.payment_service.create_recorded_payment") as create_mock:
        result = record_top_up(
            MagicMock(),
            uuid.uuid4(),
            amount_cents=2000,
            method="cash",
            recorded_by=uuid.uuid4(),
            idempotency_key="retry-key-123",
        )
    assert result is existing
    create_mock.assert_not_called()


def test_top_up_key_reuse_with_different_amount_conflicts() -> None:
    existing = SimpleNamespace(payment_type="top_up", amount_cents=2000, status="paid_cash")
    with patch(
        "app.services.payment_service.get_payment_by_idempotency_key",
        return_value=existing,
    ):
        with pytest.raises(PaymentError) as exc:
            record_top_up(
                MagicMock(),
                uuid.uuid4(),
                amount_cents=9000,
                method="cash",
                recorded_by=uuid.uuid4(),
                idempotency_key="retry-key-123",
            )
    assert exc.value.code == "idempotency_conflict"


def test_top_up_schema_caps_amount() -> None:
    from app.schemas.payment import MAX_TOP_UP_CENTS, RecordTopUpIn

    RecordTopUpIn(amount_cents=MAX_TOP_UP_CENTS, method="cash")
    with pytest.raises(ValidationError):
        RecordTopUpIn(amount_cents=MAX_TOP_UP_CENTS + 1, method="cash")


# --- Events: duplicate booking is a conflict, not a 500 ---------------------


def test_duplicate_event_booking_maps_to_already_booked() -> None:
    from sqlalchemy.exc import IntegrityError

    from app.services.event_service import EventError, _create_booking_or_conflict

    session = MagicMock()
    session.flush.side_effect = IntegrityError("insert", {}, Exception("unique"))
    with patch("app.services.event_service.create_booking"):
        with pytest.raises(EventError) as exc:
            _create_booking_or_conflict(session, slot=SimpleNamespace(id=uuid.uuid4()), user_id=uuid.uuid4())
    assert exc.value.code == "already_booked"
    session.rollback.assert_called_once()


def test_full_slot_uses_fresh_count_not_loaded_relationship() -> None:
    from app.services import event_service
    from app.core.roles import Role

    slot = SimpleNamespace(
        id=uuid.uuid4(),
        capacity=1,
        audience="member",
        bookings=[],  # stale: relationship loaded before a concurrent insert
        event=SimpleNamespace(id=uuid.uuid4(), is_published=True, end_date=date(2999, 1, 1)),
    )
    with patch.object(event_service, "lock_slot_row"), patch.object(
        event_service, "get_slot_by_id", return_value=slot
    ), patch.object(event_service, "count_bookings_for_slot", return_value=1):
        with pytest.raises(event_service.EventError) as exc:
            event_service.book_slot_service(
                MagicMock(), slot_id=slot.id, user_id=uuid.uuid4(), role=Role.MEMBER
            )
    assert exc.value.code == "full"
