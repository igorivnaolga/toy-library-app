"""Maps `public.profiles` — app roles for Supabase-authenticated users."""

from __future__ import annotations

import uuid

from sqlalchemy import Boolean, String, text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

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
    membership_tier: Mapped[str | None] = mapped_column(String(32), nullable=True)
    volunteer_confirmed: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("false"),
    )
    kids_names: Mapped[list[str]] = mapped_column(
        ARRAY(String),
        nullable=False,
        server_default=text("'{}'"),
    )
    kids: Mapped[list[dict]] = mapped_column(
        JSONB,
        nullable=False,
        server_default=text("'[]'"),
    )
    avatar_path: Mapped[str | None] = mapped_column(String(500), nullable=True)

    bookings: Mapped[list["Booking"]] = relationship(back_populates="profile")
    loans: Mapped[list["Loan"]] = relationship(back_populates="profile")
