"""Admin statistics aggregates from live app data."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.payment import PAID_STATUSES
from app.services.stats_period import StatsPeriod

_AUCKLAND_DATE = "timezone('Pacific/Auckland', {col})::date"


@dataclass(frozen=True)
class CountRow:
    label: str
    count: int


@dataclass(frozen=True)
class ToyPopularityRow:
    toy_id: str
    name: str
    count: int


@dataclass(frozen=True)
class StatsOverview:
    period_label: str
    total_members: int
    new_members: int
    bookings: int
    checkouts: int
    returns: int
    revenue_cents: int
    pending_revenue_cents: int
    catalog_toys: int


def _date_filter_sql(
    column_expr: str,
    period: StatsPeriod,
    *,
    bind_start: str = "start_date",
    bind_end: str = "end_date",
) -> tuple[str, dict[str, date]]:
    if period.start is None or period.end is None:
        return "", {}
    clause = (
        f" and {_AUCKLAND_DATE.format(col=column_expr)} "
        f"between :{bind_start} and :{bind_end}"
    )
    return clause, {bind_start: period.start, bind_end: period.end}


def _booking_date_filter(period: StatsPeriod) -> tuple[str, dict[str, date]]:
    if period.start is None or period.end is None:
        return "", {}
    return (
        " and b.pickup_date between :start_date and :end_date",
        {"start_date": period.start, "end_date": period.end},
    )


def _on_or_before_period_end_filter(
    column_expr: str,
    period: StatsPeriod,
) -> tuple[str, dict[str, date]]:
    """Rows on or before the period end (inclusive), in Pacific/Auckland."""
    if period.end is None:
        return "", {}
    return (
        f" and {_AUCKLAND_DATE.format(col=column_expr)} <= :end_date",
        {"end_date": period.end},
    )


def _count_members(session: Session, period: StatsPeriod) -> int:
    """Members at period end, or all current members for all-time."""
    end_filter, end_params = _on_or_before_period_end_filter("u.created_at", period)
    return int(
        session.execute(
            text(
                f"""
                select count(*) from profiles p
                join auth.users u on u.id = p.id
                where p.role in ('member', 'volunteer')
                {end_filter}
                """
            ),
            end_params,
        ).scalar_one()
        or 0
    )


def _count_toys_for_period(session: Session, period: StatsPeriod) -> int:
    """
    All-time: toys in the catalog now.

    Bounded period: distinct toys checked out at least once in the period
    (we have no per-toy created_at for historical catalog size).
    """
    if period.start is None or period.end is None:
        return int(session.execute(text("select count(*) from toys")).scalar_one() or 0)

    checkout_filter, checkout_params = _date_filter_sql("l.checked_out_at", period)
    return int(
        session.execute(
            text(
                f"""
                select count(distinct l.toy_id) from loans l
                where 1=1
                {checkout_filter}
                """
            ),
            checkout_params,
        ).scalar_one()
        or 0
    )


def stats_overview(session: Session, period: StatsPeriod) -> StatsOverview:
    member_filter, member_params = _date_filter_sql("u.created_at", period)
    booking_filter, booking_params = _booking_date_filter(period)
    checkout_filter, checkout_params = _date_filter_sql("l.checked_out_at", period)
    return_filter, return_params = _date_filter_sql("l.returned_at", period)
    paid_filter, paid_params = _date_filter_sql(
        "coalesce(p.paid_at, p.created_at)", period
    )
    pending_filter, pending_params = _date_filter_sql("p.created_at", period)

    total_members = _count_members(session, period)

    new_members = int(
        session.execute(
            text(
                f"""
                select count(*) from profiles p
                join auth.users u on u.id = p.id
                where p.role in ('member', 'volunteer')
                {member_filter}
                """
            ),
            member_params,
        ).scalar_one()
        or 0
    )

    bookings = int(
        session.execute(
            text(
                f"""
                select count(*) from bookings b
                where b.status != 'cancelled'
                {booking_filter}
                """
            ),
            booking_params,
        ).scalar_one()
        or 0
    )

    checkouts = int(
        session.execute(
            text(
                f"""
                select count(*) from loans l
                where 1=1
                {checkout_filter}
                """
            ),
            checkout_params,
        ).scalar_one()
        or 0
    )

    returns = int(
        session.execute(
            text(
                f"""
                select count(*) from loans l
                where l.returned_at is not null
                {return_filter}
                """
            ),
            return_params,
        ).scalar_one()
        or 0
    )

    paid_statuses = ", ".join(f"'{s}'" for s in sorted(PAID_STATUSES))
    revenue_cents = int(
        session.execute(
            text(
                f"""
                select coalesce(sum(p.amount_cents), 0) from payments p
                where p.status in ({paid_statuses})
                {paid_filter}
                """
            ),
            paid_params,
        ).scalar_one()
        or 0
    )

    pending_revenue_cents = int(
        session.execute(
            text(
                f"""
                select coalesce(sum(p.amount_cents), 0) from payments p
                where p.status = 'pending'
                {pending_filter}
                """
            ),
            pending_params,
        ).scalar_one()
        or 0
    )

    catalog_toys = _count_toys_for_period(session, period)

    return StatsOverview(
        period_label=period.label,
        total_members=total_members,
        new_members=new_members,
        bookings=bookings,
        checkouts=checkouts,
        returns=returns,
        revenue_cents=revenue_cents,
        pending_revenue_cents=pending_revenue_cents,
        catalog_toys=catalog_toys,
    )


def loan_counts_by_group(
    session: Session,
    period: StatsPeriod,
    *,
    group_by: str,
    limit: int = 12,
) -> list[CountRow]:
    column_map = {
        "category": "coalesce(t.category_label, 'Uncategorised')",
        "age": "coalesce(nullif(trim(t.age_range), ''), 'Unknown')",
        "manufacturer": "coalesce(nullif(trim(t.manufacturer), ''), 'Unknown')",
    }
    col = column_map.get(group_by)
    if col is None:
        raise ValueError("group_by must be category, age, or manufacturer.")

    date_filter, params = _date_filter_sql("l.checked_out_at", period)
    params["lim"] = limit
    rows = session.execute(
        text(
            f"""
            select {col} as label, count(*)::int as cnt
            from loans l
            join toys t on t.toy_id = l.toy_id
            where 1=1
            {date_filter}
            group by 1
            order by cnt desc, label asc
            limit :lim
            """
        ),
        params,
    ).all()
    return [CountRow(label=str(label), count=int(cnt)) for label, cnt in rows]


def catalog_counts_by_category(session: Session, *, limit: int = 12) -> list[CountRow]:
    rows = session.execute(
        text(
            """
            select coalesce(category_label, 'Uncategorised') as label,
                   count(*)::int as cnt
            from toys
            group by 1
            order by cnt desc, label asc
            limit :lim
            """
        ),
        {"lim": limit},
    ).all()
    return [CountRow(label=str(label), count=int(cnt)) for label, cnt in rows]


def catalog_counts_by_status(session: Session) -> list[CountRow]:
    rows = session.execute(
        text(
            """
            select coalesce(nullif(trim(status), ''), 'Unknown') as label,
                   count(*)::int as cnt
            from toys
            group by 1
            order by cnt desc, label asc
            """
        )
    ).all()
    return [CountRow(label=str(label), count=int(cnt)) for label, cnt in rows]


def _registration_date_expr() -> str:
    return (
        "coalesce("
        "p.registered_at, "
        f"{_AUCKLAND_DATE.format(col='p.terms_accepted_at')}, "
        f"{_AUCKLAND_DATE.format(col='u.created_at')}"
        ")"
    )


def _registration_date_filter(period: StatsPeriod) -> tuple[str, dict[str, date]]:
    if period.start is None or period.end is None:
        return "", {}
    expr = _registration_date_expr()
    return (
        f" and {expr} between :start_date and :end_date",
        {"start_date": period.start, "end_date": period.end},
    )


@dataclass(frozen=True)
class PendingMemberRow:
    user_id: str
    email: str
    full_name: str
    pending_cents: int


def pending_members_in_period(
    session: Session,
    period: StatsPeriod,
    *,
    limit: int = 100,
) -> tuple[int, list[PendingMemberRow]]:
    """Members with pending payment charges in the stats period."""
    date_filter, params = _date_filter_sql("p.created_at", period)
    params["lim"] = limit

    total_pending_cents = int(
        session.execute(
            text(
                f"""
                select coalesce(sum(p.amount_cents), 0) from payments p
                where p.status = 'pending'
                {date_filter}
                """
            ),
            params,
        ).scalar_one()
        or 0
    )

    rows = session.execute(
        text(
            f"""
            select prof.id::text as user_id,
                   coalesce(u.email::text, '') as email,
                   coalesce(prof.full_name, '') as full_name,
                   sum(p.amount_cents)::int as pending_cents
            from payments p
            join profiles prof on prof.id = p.user_id
            join auth.users u on u.id = prof.id
            where p.status = 'pending'
            {date_filter}
            group by prof.id, u.email, prof.full_name
            order by pending_cents desc, prof.full_name asc
            limit :lim
            """
        ),
        params,
    ).all()
    data = [
        PendingMemberRow(
            user_id=str(user_id),
            email=str(email),
            full_name=str(full_name),
            pending_cents=int(pending_cents),
        )
        for user_id, email, full_name, pending_cents in rows
    ]
    return total_pending_cents, data


def heard_about_us_counts(
    session: Session,
    period: StatsPeriod,
    *,
    limit: int = 12,
) -> tuple[int, list[CountRow]]:
    """Group registration answers for how members heard about the library."""
    date_filter, params = _registration_date_filter(period)
    params["lim"] = limit

    total_responses = int(
        session.execute(
            text(
                f"""
                select count(*) from profiles p
                join auth.users u on u.id = p.id
                where p.role in ('member', 'volunteer')
                  and nullif(trim(p.heard_about_us), '') is not null
                {date_filter}
                """
            ),
            params,
        ).scalar_one()
        or 0
    )

    rows = session.execute(
        text(
            f"""
            select initcap(lower(trim(p.heard_about_us))) as label,
                   count(*)::int as cnt
            from profiles p
            join auth.users u on u.id = p.id
            where p.role in ('member', 'volunteer')
              and nullif(trim(p.heard_about_us), '') is not null
            {date_filter}
            group by 1
            order by cnt desc, label asc
            limit :lim
            """
        ),
        params,
    ).all()
    data = [CountRow(label=str(label), count=int(cnt)) for label, cnt in rows]
    return total_responses, data


def toy_popularity(
    session: Session,
    period: StatsPeriod,
    *,
    limit: int = 15,
) -> list[ToyPopularityRow]:
    """Most-checked-out toys in the period (loan count per toy)."""
    date_filter, params = _date_filter_sql("l.checked_out_at", period)
    params["lim"] = limit
    rows = session.execute(
        text(
            f"""
            select t.toy_id, t.name, count(*)::int as cnt
            from loans l
            join toys t on t.toy_id = l.toy_id
            where 1=1
            {date_filter}
            group by t.toy_id, t.name
            order by cnt desc, t.name asc
            limit :lim
            """
        ),
        params,
    ).all()
    return [
        ToyPopularityRow(toy_id=str(toy_id), name=str(name), count=int(cnt))
        for toy_id, name, cnt in rows
    ]
