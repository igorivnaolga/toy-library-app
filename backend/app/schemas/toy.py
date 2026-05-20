from pydantic import BaseModel, Field, field_validator

from app.core import availability as avail
from app.utils.text import capitalize_first_letter


class ToyOut(BaseModel):
    toy_id: str
    name: str
    category: str | None = None
    age_range: str | None = None
    status: str | None = Field(
        default=None,
        description='Raw status label from CSV/DB (e.g. "In library", "On loan").',
    )

    availability: str = Field(
        default=avail.UNKNOWN,
        description="Canonical lending code: available | on_loan | reserved | unavailable | unknown.",
    )
    manufacturer: str | None = None
    description: str | None = None
    photo_file: str | None = None

    @field_validator("name", mode="before")
    @classmethod
    def _capitalize_name(cls, value: str) -> str:
        if not isinstance(value, str):
            return value
        return capitalize_first_letter(value)


class ToysListMeta(BaseModel):
    page: int
    limit: int
    total: int
    has_next: bool


class ToysListResponse(BaseModel):
    data: list[ToyOut]
    meta: ToysListMeta


class ToysMetaOut(BaseModel):
    """Distinct filter values derived from the current toy dataset (DB or CSV fallback)."""

    age_ranges: list[str] = Field(
        default_factory=list,
        description="Non-empty distinct age_range labels, sorted case-insensitively.",
    )
