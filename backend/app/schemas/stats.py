"""Admin statistics API models."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class StatsCountRowOut(BaseModel):
    label: str
    count: int = Field(ge=0)


class StatsOverviewOut(BaseModel):
    period: str
    period_label: str
    total_members: int = Field(
        ge=0,
        description="All members now (all-time), or members joined on/before period end.",
    )
    new_members: int = Field(ge=0, description="Members who joined during the period.")
    bookings: int = Field(ge=0)
    checkouts: int = Field(ge=0)
    returns: int = Field(ge=0)
    revenue_cents: int = Field(ge=0)
    pending_revenue_cents: int = Field(ge=0)
    catalog_toys: int = Field(
        ge=0,
        description="Catalog size (all-time), or distinct toys loaned in the period.",
    )


class StatsBreakdownOut(BaseModel):
    period: str
    period_label: str
    group_by: Literal["category", "age", "manufacturer"]
    data: list[StatsCountRowOut]


class StatsCatalogOut(BaseModel):
    by_category: list[StatsCountRowOut]
    by_status: list[StatsCountRowOut]


class ToyPopularityRowOut(BaseModel):
    toy_id: str
    name: str
    count: int = Field(ge=0)


class ToyPopularityOut(BaseModel):
    period: str
    period_label: str
    data: list[ToyPopularityRowOut] = Field(default_factory=list)


class StatsHeardAboutOut(BaseModel):
    period: str
    period_label: str
    total_responses: int = Field(
        ge=0,
        description="Members with a heard-about-us answer in the period.",
    )
    data: list[StatsCountRowOut] = Field(default_factory=list)


class StatsPendingMemberOut(BaseModel):
    user_id: str
    email: str = ""
    full_name: str = ""
    pending_cents: int = Field(ge=0)


class StatsPendingMembersOut(BaseModel):
    period: str
    period_label: str
    total_pending_cents: int = Field(ge=0)
    data: list[StatsPendingMemberOut] = Field(default_factory=list)
