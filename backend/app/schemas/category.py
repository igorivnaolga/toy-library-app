from pydantic import BaseModel, Field


class CategoryOut(BaseModel):
    code: str
    label: str
    max_renewals: int | None = None
    reservable: bool | None = None
    toy_count_current: int | None = None
    toy_count_total: int | None = None
    pct: str | None = Field(None, description="CSV '%' popularity column")


class CategoriesListResponse(BaseModel):
    data: list[CategoryOut]
