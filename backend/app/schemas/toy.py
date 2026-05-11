from pydantic import BaseModel, Field

from app.core import availability as avail


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


class ToysListMeta(BaseModel):
    page: int
    limit: int
    total: int
    has_next: bool


class ToysListResponse(BaseModel):
    data: list[ToyOut]
    meta: ToysListMeta
