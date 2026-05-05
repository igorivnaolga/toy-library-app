"""Maps `public.profiles` — app roles for Supabase-authenticated users."""

from __future__ import annotations

import uuid

from sqlalchemy import String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        doc="Matches Supabase auth.users.id",
    )
    role: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text("'guest'"),
    )
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
