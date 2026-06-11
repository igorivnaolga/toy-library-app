"""Persist FCM device tokens per user."""

from __future__ import annotations

import uuid

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.device_token import DeviceToken


def upsert_device_token(
    session: Session,
    *,
    user_id: uuid.UUID,
    token: str,
    platform: str,
) -> DeviceToken:
    cleaned = token.strip()
    existing = session.scalar(
        select(DeviceToken).where(DeviceToken.token == cleaned)
    )
    if existing is not None:
        existing.user_id = user_id
        existing.platform = platform
        session.flush()
        return existing

    row = DeviceToken(user_id=user_id, token=cleaned, platform=platform)
    session.add(row)
    session.flush()
    return row


def delete_device_token(session: Session, *, user_id: uuid.UUID, token: str) -> int:
    result = session.execute(
        delete(DeviceToken).where(
            DeviceToken.user_id == user_id,
            DeviceToken.token == token.strip(),
        )
    )
    return int(result.rowcount or 0)


def list_tokens_for_user(session: Session, user_id: uuid.UUID) -> list[str]:
    rows = session.scalars(
        select(DeviceToken.token).where(DeviceToken.user_id == user_id)
    ).all()
    return list(rows)


def delete_all_tokens_for_user(session: Session, user_id: uuid.UUID) -> int:
    result = session.execute(
        delete(DeviceToken).where(DeviceToken.user_id == user_id)
    )
    return int(result.rowcount or 0)
