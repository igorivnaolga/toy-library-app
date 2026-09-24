"""
Role × endpoint matrix: every route must declare who may call it.

Only *denials* are exercised (401/403 are raised by auth dependencies before any
handler or database code runs), so no database is needed. Adding a route without
listing it in ``POLICY`` fails ``test_every_route_has_a_policy``.
"""

from __future__ import annotations

import re
import uuid
from unittest.mock import MagicMock

import pytest
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

from app.core import auth_deps
from app.core.auth_deps import get_current_principal
from app.core.roles import Role
from app.db.session import get_db
from app.main import app
from app.schemas.principal import Principal

GUEST = "guest"
MEMBER = "member"
VOLUNTEER_OFF_DUTY = "volunteer_off_duty"
VOLUNTEER_ON_DUTY = "volunteer_on_duty"
ADMIN = "admin"
ALL_ROLES = (GUEST, MEMBER, VOLUNTEER_OFF_DUTY, VOLUNTEER_ON_DUTY, ADMIN)

PUBLIC = "public"  # no auth at all
CRON = "cron"  # X-Cron-Secret, tested separately

ANY_USER = frozenset(ALL_ROLES)
BOOKING_MEMBER = frozenset({MEMBER, VOLUNTEER_OFF_DUTY, VOLUNTEER_ON_DUTY})
MEMBERS = frozenset({MEMBER, VOLUNTEER_OFF_DUTY, VOLUNTEER_ON_DUTY, ADMIN})
VOLUNTEERS = frozenset({VOLUNTEER_OFF_DUTY, VOLUNTEER_ON_DUTY, ADMIN})
ON_DUTY = frozenset({VOLUNTEER_ON_DUTY, ADMIN})
ADMIN_ONLY = frozenset({ADMIN})

POLICY: dict[str, str | frozenset[str]] = {
    "GET /api/v1/health": PUBLIC,
    "GET /api/v1/health/ready": PUBLIC,
    "GET /api/v1/auth/email-registered": PUBLIC,
    "GET /api/v1/auth/me": ANY_USER,
    "PATCH /api/v1/auth/me/membership": ANY_USER,
    "POST /api/v1/auth/me/registration": ANY_USER,
    "PATCH /api/v1/auth/me/profile": ANY_USER,
    "POST /api/v1/admin/notifications/send-member-reminders": ADMIN_ONLY,
    "POST /api/v1/admin/notifications/send-member-reminders/cron": CRON,
    "GET /api/v1/admin/notifications": ADMIN_ONLY,
    "GET /api/v1/admin/todays-duty-shifts": ADMIN_ONLY,
    "GET /api/v1/admin/recent-members": ADMIN_ONLY,
    "GET /api/v1/admin/pending-duty-volunteers": ADMIN_ONLY,
    "POST /api/v1/admin/users/{user_id}/approve-volunteer": ADMIN_ONLY,
    "GET /api/v1/admin/bookings": ADMIN_ONLY,
    "GET /api/v1/admin/members": ADMIN_ONLY,
    "GET /api/v1/admin/users/{user_id}": ADMIN_ONLY,
    "GET /api/v1/admin/users/{user_id}/duty-sessions": ADMIN_ONLY,
    "GET /api/v1/admin/users/{user_id}/loans": ADMIN_ONLY,
    "PATCH /api/v1/admin/users/{user_id}/membership": ADMIN_ONLY,
    "PATCH /api/v1/admin/users/{user_id}": ADMIN_ONLY,
    "PATCH /api/v1/admin/categories/{code}": ADMIN_ONLY,
    "POST /api/v1/admin/toys": ADMIN_ONLY,
    "PATCH /api/v1/admin/toys/{toy_id}": ADMIN_ONLY,
    "DELETE /api/v1/admin/toys/{toy_id}": ADMIN_ONLY,
    "POST /api/v1/admin/toys/{toy_id}/photo": ADMIN_ONLY,
    "GET /api/v1/admin/events": ADMIN_ONLY,
    "GET /api/v1/admin/events/assignees": ADMIN_ONLY,
    "POST /api/v1/admin/events/slots/{slot_id}/book": ADMIN_ONLY,
    "DELETE /api/v1/admin/events/slots/{slot_id}/book/{user_id}": ADMIN_ONLY,
    "POST /api/v1/admin/events": ADMIN_ONLY,
    "PATCH /api/v1/admin/events/{event_id}": ADMIN_ONLY,
    "DELETE /api/v1/admin/events/{event_id}": ADMIN_ONLY,
    "GET /api/v1/admin/stats/overview": ADMIN_ONLY,
    "GET /api/v1/admin/stats/loans/breakdown": ADMIN_ONLY,
    "GET /api/v1/admin/stats/toys/popularity": ADMIN_ONLY,
    "GET /api/v1/admin/stats/payments/pending-members": ADMIN_ONLY,
    "GET /api/v1/admin/stats/members/heard-about-us": ADMIN_ONLY,
    "GET /api/v1/admin/stats/catalog": ADMIN_ONLY,
    "GET /api/v1/bookings/pickup-dates": BOOKING_MEMBER,
    "POST /api/v1/bookings": BOOKING_MEMBER,
    "GET /api/v1/bookings/me": BOOKING_MEMBER,
    "GET /api/v1/bookings/pending": ON_DUTY,
    "PATCH /api/v1/bookings/{booking_id}": BOOKING_MEMBER,
    "POST /api/v1/bookings/{booking_id}/cancel": BOOKING_MEMBER,
    "GET /api/v1/loans/me": MEMBERS,
    "GET /api/v1/loans/active": ON_DUTY,
    "POST /api/v1/loans/check-out/booking": ON_DUTY,
    "POST /api/v1/loans/check-out/walk-in": ON_DUTY,
    "POST /api/v1/loans/{loan_id}/check-in": ON_DUTY,
    "POST /api/v1/loans/{loan_id}/renew": MEMBERS,
    "GET /api/v1/toys/{toy_id}/photo": PUBLIC,
    "GET /api/v1/toys": PUBLIC,
    "GET /api/v1/toys/meta": PUBLIC,
    "GET /api/v1/toys/{toy_id}": PUBLIC,
    "PATCH /api/v1/toys/{toy_id}/pieces": ON_DUTY,
    "GET /api/v1/categories": PUBLIC,
    "GET /api/v1/duty/sessions": VOLUNTEERS,
    "GET /api/v1/duty/me/on-duty": VOLUNTEERS,
    "GET /api/v1/duty/me/sessions": VOLUNTEERS,
    "GET /api/v1/duty/members": ON_DUTY,
    "POST /api/v1/duty/sessions": ADMIN_ONLY,
    "PATCH /api/v1/duty/sessions/{session_id}/assign": ADMIN_ONLY,
    "DELETE /api/v1/duty/sessions/{session_id}/assign": ADMIN_ONLY,
    "DELETE /api/v1/duty/sessions/{session_id}": ADMIN_ONLY,
    "POST /api/v1/duty/sessions/{session_id}/book": VOLUNTEERS,
    "POST /api/v1/duty/sessions/{session_id}/confirm": ADMIN_ONLY,
    "DELETE /api/v1/duty/sessions/{session_id}/book": VOLUNTEERS,
    "GET /api/v1/events": MEMBERS,
    "GET /api/v1/events/availability": MEMBERS,
    "GET /api/v1/events/dates": MEMBERS,
    "POST /api/v1/events/slots/{slot_id}/book": MEMBERS,
    "DELETE /api/v1/events/slots/{slot_id}/book": MEMBERS,
    "PATCH /api/v1/desk/toys/{toy_id}/pieces": ON_DUTY,
    "POST /api/v1/desk/identify-pieces": ON_DUTY,
    "POST /api/v1/desk/learn-from-photo": ON_DUTY,
    "POST /api/v1/notifications/device": MEMBERS,
    "POST /api/v1/notifications/device/unregister": ANY_USER,
    "GET /api/v1/payments/me": ANY_USER,
    "GET /api/v1/payments/users/{user_id}": ADMIN_ONLY,
    "GET /api/v1/payments/users/{user_id}/balance-summary": ON_DUTY,
    "POST /api/v1/payments/{payment_id}/mark-paid": ON_DUTY,
    "POST /api/v1/payments/users/{user_id}/mark-payments-paid": ON_DUTY,
    "POST /api/v1/payments/users/{user_id}/mark-membership-paid": ON_DUTY,
    "POST /api/v1/payments/users/{user_id}/top-up": ON_DUTY,
}

_ROLE_FOR = {
    GUEST: Role.GUEST,
    MEMBER: Role.MEMBER,
    VOLUNTEER_OFF_DUTY: Role.VOLUNTEER,
    VOLUNTEER_ON_DUTY: Role.VOLUNTEER,
    ADMIN: Role.ADMIN,
}


def _route_keys() -> list[str]:
    keys: list[str] = []
    for route in app.routes:
        if isinstance(route, APIRoute):
            keys.extend(f"{method} {route.path}" for method in sorted(route.methods))
    return keys


def _concrete(path: str) -> str:
    def _value(match: re.Match[str]) -> str:
        name = match.group(1)
        if name in {"toy_id"}:
            return "T1"
        if name == "code":
            return "C1"
        return str(uuid.uuid4())

    return re.sub(r"\{(\w+)\}", _value, path)


def _query_for(path: str) -> dict[str, str]:
    # Required query params, so validation can't mask a missing auth check.
    if path.endswith(("/duty/sessions", "/events", "/events/dates")):
        return {"from": "2026-01-01", "to": "2026-01-31"}
    return {}


def _call(client: TestClient, key: str):
    method, path = key.split(" ", 1)
    return client.request(method, _concrete(path), params=_query_for(path), json={})


@pytest.fixture
def client():
    app.dependency_overrides[get_db] = lambda: MagicMock()
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


def _as_role(role_key: str, monkeypatch: pytest.MonkeyPatch) -> None:
    principal = Principal(id=uuid.uuid4(), role=_ROLE_FOR[role_key])
    app.dependency_overrides[get_current_principal] = lambda: principal
    on_duty = role_key == VOLUNTEER_ON_DUTY
    monkeypatch.setattr(auth_deps, "is_volunteer_on_duty_now", lambda *_a, **_k: on_duty)
    monkeypatch.setattr(auth_deps, "volunteer_has_booked_slot_today", lambda *_a, **_k: False)


def test_every_route_has_a_policy() -> None:
    routes = set(_route_keys())
    missing = sorted(routes - POLICY.keys())
    stale = sorted(POLICY.keys() - routes)
    assert not missing, f"Add these routes to POLICY in tests/test_rbac.py: {missing}"
    assert not stale, f"Remove routes that no longer exist from POLICY: {stale}"


PROTECTED = [key for key, policy in POLICY.items() if isinstance(policy, frozenset)]


@pytest.mark.parametrize("key", PROTECTED)
def test_protected_route_requires_token(client: TestClient, key: str) -> None:
    assert _call(client, key).status_code == 401


DENIALS = [
    (key, role)
    for key, policy in POLICY.items()
    if isinstance(policy, frozenset)
    for role in ALL_ROLES
    if role not in policy
]


@pytest.mark.parametrize(("key", "role"), DENIALS)
def test_role_is_denied(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
    key: str,
    role: str,
) -> None:
    _as_role(role, monkeypatch)
    response = _call(client, key)
    assert response.status_code == 403, (key, role, response.text)


def test_cron_rejects_missing_and_wrong_secret(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from types import SimpleNamespace

    from app.api.v1.endpoints import admin

    monkeypatch.setattr(admin, "get_settings", lambda: SimpleNamespace(cron_secret="s3cret-value"))
    path = "/api/v1/admin/notifications/send-member-reminders/cron"
    assert client.post(path).status_code == 403
    assert client.post(path, headers={"X-Cron-Secret": "wrong"}).status_code == 403


def test_cron_disabled_when_secret_unset(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from types import SimpleNamespace

    from app.api.v1.endpoints import admin

    monkeypatch.setattr(admin, "get_settings", lambda: SimpleNamespace(cron_secret=None))
    response = client.post(
        "/api/v1/admin/notifications/send-member-reminders/cron",
        headers={"X-Cron-Secret": ""},
    )
    assert response.status_code == 403
