"""Load `profiles` rows linked to Supabase users."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.profile import Profile


def get_profile_by_id(session: Session, user_id: uuid.UUID) -> Profile | None:
    return session.scalar(select(Profile).where(Profile.id == user_id))
