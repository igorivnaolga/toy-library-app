from __future__ import annotations

import uuid

from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    label: Mapped[str] = mapped_column(Text, unique=True, index=True)

    max_renewals: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reservable: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    toy_count_current: Mapped[int | None] = mapped_column(Integer, nullable=True)
    toy_count_total: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pct_label: Mapped[str | None] = mapped_column(String(32), nullable=True)

    toys: Mapped[list["Toy"]] = relationship(back_populates="category_rel")
