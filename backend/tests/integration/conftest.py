"""
Fixtures for tests against a real, migrated Postgres.

Set TEST_DATABASE_URL (postgresql+psycopg://...) to a throwaway database that has
had `tests/integration/supabase_stubs.sql` and `alembic upgrade head` applied.
Without it these tests are skipped. Tables are truncated after each test.
"""

from __future__ import annotations

import os
import threading
import uuid
from collections.abc import Callable, Iterator

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")

pytestmark = pytest.mark.integration

_APP_TABLES = (
    "event_bookings, event_time_slots, library_events, payments, loans, bookings, "
    "duty_sessions, device_tokens, push_notification_logs, toy_images, toys, "
    "categories, profiles"
)


@pytest.fixture(scope="session")
def engine():
    if not TEST_DATABASE_URL:
        pytest.skip("TEST_DATABASE_URL not set; skipping Postgres integration tests")
    eng = create_engine(TEST_DATABASE_URL, pool_size=10)
    yield eng
    eng.dispose()


@pytest.fixture
def session_factory(engine) -> Iterator[sessionmaker[Session]]:
    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    yield factory
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE {_APP_TABLES} RESTART IDENTITY CASCADE"))
        conn.execute(text("TRUNCATE auth.users CASCADE"))


@pytest.fixture
def make_user(session_factory) -> Callable[..., uuid.UUID]:
    def _make(role: str = "member", tier: str | None = "non_duty") -> uuid.UUID:
        user_id = uuid.uuid4()
        with session_factory() as s:
            s.execute(
                text("INSERT INTO auth.users (id, email) VALUES (:id, :email)"),
                {"id": user_id, "email": f"{user_id}@example.test"},
            )
            s.execute(
                text(
                    "INSERT INTO public.profiles (id, role, membership_tier) "
                    "VALUES (:id, :role, :tier) "
                    "ON CONFLICT (id) DO UPDATE SET role = :role, membership_tier = :tier"
                ),
                {"id": user_id, "role": role, "tier": tier},
            )
            s.commit()
        return user_id

    return _make


@pytest.fixture
def make_toy(session_factory) -> Callable[..., str]:
    def _make(toy_id: str = "T1", status: str = "In library") -> str:
        with session_factory() as s:
            s.execute(
                text("INSERT INTO public.toys (toy_id, name, status) VALUES (:id, :name, :status)"),
                {"id": toy_id, "name": f"Toy {toy_id}", "status": status},
            )
            s.commit()
        return toy_id

    return _make


def run_concurrently(session_factory, *workers: Callable[[Session], object]) -> list[object]:
    """
    Run each worker in its own thread and session, released together by a barrier.

    Returns each worker's result, or the exception it raised. Workers commit on success.
    """
    barrier = threading.Barrier(len(workers))
    results: list[object] = [None] * len(workers)

    def _run(index: int, worker: Callable[[Session], object]) -> None:
        with session_factory() as session:
            barrier.wait()
            try:
                results[index] = worker(session)
                session.commit()
            except Exception as exc:  # noqa: BLE001 - surfaced to the test
                session.rollback()
                results[index] = exc

    threads = [threading.Thread(target=_run, args=(i, w)) for i, w in enumerate(workers)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)
    return results
