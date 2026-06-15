"""Admin statistics endpoints."""

from __future__ import annotations

from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin
from app.db.session import get_db
from app.schemas.principal import Principal
from app.schemas.stats import (
    StatsBreakdownOut,
    StatsCatalogOut,
    StatsCountRowOut,
    StatsHeardAboutOut,
    StatsOverviewOut,
    StatsPendingMemberOut,
    StatsPendingMembersOut,
    ToyPopularityOut,
    ToyPopularityRowOut,
)
from app.services.stats_period import StatsPeriodError, resolve_stats_period
from app.services.stats_service import (
    catalog_counts_by_category,
    catalog_counts_by_status,
    heard_about_us_counts,
    loan_counts_by_group,
    pending_members_in_period,
    stats_overview,
    toy_popularity,
)

router = APIRouter()


def _period_from_query(
    period: Literal["session", "month", "year", "all"] = Query("month"),
    session_date: date | None = Query(None),
    year: int | None = Query(None, ge=2020, le=2100),
    month: int | None = Query(None, ge=1, le=12),
):
    try:
        return resolve_stats_period(
            period=period,
            session_date=session_date,
            year=year,
            month=month,
        )
    except StatsPeriodError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/overview", response_model=StatsOverviewOut)
def admin_stats_overview(
    resolved=Depends(_period_from_query),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StatsOverviewOut:
    overview = stats_overview(db, resolved)
    return StatsOverviewOut(
        period=resolved.kind,
        period_label=overview.period_label,
        total_members=overview.total_members,
        new_members=overview.new_members,
        bookings=overview.bookings,
        checkouts=overview.checkouts,
        returns=overview.returns,
        revenue_cents=overview.revenue_cents,
        pending_revenue_cents=overview.pending_revenue_cents,
        catalog_toys=overview.catalog_toys,
    )


@router.get("/loans/breakdown", response_model=StatsBreakdownOut)
def admin_stats_loan_breakdown(
    group_by: Literal["category", "age", "manufacturer"] = Query("category"),
    limit: int = Query(12, ge=1, le=30),
    resolved=Depends(_period_from_query),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StatsBreakdownOut:
    try:
        rows = loan_counts_by_group(db, resolved, group_by=group_by, limit=limit)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return StatsBreakdownOut(
        period=resolved.kind,
        period_label=resolved.label,
        group_by=group_by,
        data=[StatsCountRowOut(label=r.label, count=r.count) for r in rows],
    )


@router.get("/toys/popularity", response_model=ToyPopularityOut)
def admin_stats_toy_popularity(
    limit: int = Query(15, ge=1, le=30),
    resolved=Depends(_period_from_query),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ToyPopularityOut:
    rows = toy_popularity(db, resolved, limit=limit)
    return ToyPopularityOut(
        period=resolved.kind,
        period_label=resolved.label,
        data=[
            ToyPopularityRowOut(toy_id=r.toy_id, name=r.name, count=r.count)
            for r in rows
        ],
    )


@router.get("/payments/pending-members", response_model=StatsPendingMembersOut)
def admin_stats_pending_members(
    limit: int = Query(100, ge=1, le=200),
    resolved=Depends(_period_from_query),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StatsPendingMembersOut:
    total, rows = pending_members_in_period(db, resolved, limit=limit)
    return StatsPendingMembersOut(
        period=resolved.kind,
        period_label=resolved.label,
        total_pending_cents=total,
        data=[
            StatsPendingMemberOut(
                user_id=r.user_id,
                email=r.email,
                full_name=r.full_name,
                pending_cents=r.pending_cents,
            )
            for r in rows
        ],
    )


@router.get("/members/heard-about-us", response_model=StatsHeardAboutOut)
def admin_stats_heard_about_us(
    limit: int = Query(12, ge=1, le=30),
    resolved=Depends(_period_from_query),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StatsHeardAboutOut:
    total, rows = heard_about_us_counts(db, resolved, limit=limit)
    return StatsHeardAboutOut(
        period=resolved.kind,
        period_label=resolved.label,
        total_responses=total,
        data=[StatsCountRowOut(label=r.label, count=r.count) for r in rows],
    )


@router.get("/catalog", response_model=StatsCatalogOut)
def admin_stats_catalog(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StatsCatalogOut:
    return StatsCatalogOut(
        by_category=[
            StatsCountRowOut(label=r.label, count=r.count)
            for r in catalog_counts_by_category(db)
        ],
        by_status=[
            StatsCountRowOut(label=r.label, count=r.count)
            for r in catalog_counts_by_status(db)
        ],
    )
