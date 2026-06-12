"""SETLS catalog snapshot tables (see `016_setls_stats.sql`)."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


class SetlsImportRun(Base):
    __tablename__ = "setls_import_runs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    imported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    source_label: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        server_default="export_imgs",
    )
    toy_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    category_count: Mapped[int | None] = mapped_column(Integer, nullable=True)

    categories: Mapped[list["SetlsCategoryStat"]] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
    )
    status_counts: Mapped[list["SetlsToyStatusCount"]] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
    )


class SetlsCategoryStat(Base):
    __tablename__ = "setls_category_stats"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("setls_import_runs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    code: Mapped[str] = mapped_column(String(64), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    current_toys: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_toys: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pct_share: Mapped[Decimal | None] = mapped_column(Numeric(6, 2), nullable=True)
    reservable: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    max_renewals: Mapped[int | None] = mapped_column(Integer, nullable=True)

    run: Mapped["SetlsImportRun"] = relationship(back_populates="categories")


class SetlsToyStatusCount(Base):
    __tablename__ = "setls_toy_status_counts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("setls_import_runs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(64), nullable=False)
    toy_count: Mapped[int] = mapped_column(Integer, nullable=False)

    run: Mapped["SetlsImportRun"] = relationship(back_populates="status_counts")
