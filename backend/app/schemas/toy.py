from pydantic import BaseModel


class ToyOut(BaseModel):
    toy_id: str
    name: str
    category: str | None = None
    age_range: str | None = None
    status: str | None = None
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
