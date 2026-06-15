"""Library event persistence."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time

from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session, joinedload

from app.models.library_event import EventBooking, EventTimeSlot, LibraryEvent


def _time_str(value: time) -> str:
    return value.strftime("%H:%M:%S")


def get_event_by_id(session: Session, event_id: uuid.UUID) -> LibraryEvent | None:
    return session.get(
        LibraryEvent,
        event_id,
        options=[joinedload(LibraryEvent.slots).joinedload(EventTimeSlot.bookings)],
    )


def list_events_in_range(
    session: Session,
    *,
    from_date: date,
    to_date: date,
    published_only: bool = True,
) -> list[LibraryEvent]:
    stmt = (
        select(LibraryEvent)
        .where(LibraryEvent.event_date <= to_date)
        .where(LibraryEvent.end_date >= from_date)
        .options(
            joinedload(LibraryEvent.slots).joinedload(EventTimeSlot.bookings),
        )
        .order_by(LibraryEvent.event_date.asc(), LibraryEvent.name.asc())
    )
    if published_only:
        stmt = stmt.where(LibraryEvent.is_published.is_(True))
    return list(session.scalars(stmt).unique().all())


def list_event_dates_in_range(
    session: Session,
    *,
    from_date: date,
    to_date: date,
) -> list[date]:
    rows = session.execute(
        select(LibraryEvent.event_date, LibraryEvent.end_date)
        .where(LibraryEvent.event_date <= to_date)
        .where(LibraryEvent.end_date >= from_date)
        .where(LibraryEvent.is_published.is_(True))
    ).all()
    return _expand_event_date_ranges(rows, from_date=from_date, to_date=to_date)


def list_event_dates_in_range_for_audiences(
    session: Session,
    *,
    from_date: date,
    to_date: date,
    audiences: list[str],
) -> list[date]:
    rows = session.execute(
        select(LibraryEvent.event_date, LibraryEvent.end_date)
        .join(EventTimeSlot, EventTimeSlot.event_id == LibraryEvent.id)
        .where(LibraryEvent.event_date <= to_date)
        .where(LibraryEvent.end_date >= from_date)
        .where(LibraryEvent.is_published.is_(True))
        .where(EventTimeSlot.audience.in_(audiences))
        .distinct()
    ).all()
    return _expand_event_date_ranges(rows, from_date=from_date, to_date=to_date)


def _expand_event_date_ranges(
    rows,
    *,
    from_date: date,
    to_date: date,
) -> list[date]:
    marked: set[date] = set()
    for start, end in rows:
        day = start
        while day <= end:
            if from_date <= day <= to_date:
                marked.add(day)
            day = day.fromordinal(day.toordinal() + 1)
    return sorted(marked)


def get_slot_by_id(session: Session, slot_id: uuid.UUID) -> EventTimeSlot | None:
    return session.get(
        EventTimeSlot,
        slot_id,
        options=[
            joinedload(EventTimeSlot.event),
            joinedload(EventTimeSlot.bookings),
        ],
    )


def create_event(
    session: Session,
    *,
    name: str,
    description: str | None,
    event_date: date,
    end_date: date,
    is_published: bool,
    created_by: uuid.UUID | None,
    slots: list[dict],
) -> LibraryEvent:
    event = LibraryEvent(
        name=name.strip(),
        description=description.strip() if description else None,
        event_date=event_date,
        end_date=end_date,
        is_published=is_published,
        created_by=created_by,
    )
    session.add(event)
    session.flush()
    for slot in slots:
        session.add(
            EventTimeSlot(
                event_id=event.id,
                start_time=slot["start_time"],
                end_time=slot["end_time"],
                capacity=slot["capacity"],
                audience=slot["audience"],
            )
        )
    session.flush()
    session.refresh(event)
    return get_event_by_id(session, event.id) or event


def update_event(
    session: Session,
    event: LibraryEvent,
    *,
    name: str | None = None,
    description: str | None = None,
    event_date: date | None = None,
    end_date: date | None = None,
    is_published: bool | None = None,
    slots: list[dict] | None = None,
) -> LibraryEvent:
    if name is not None:
        event.name = name.strip()
    if description is not None:
        event.description = description.strip() or None
    if event_date is not None:
        event.event_date = event_date
    if end_date is not None:
        event.end_date = end_date
    if is_published is not None:
        event.is_published = is_published
    if slots is not None:
        for existing in list(event.slots):
            session.delete(existing)
        session.flush()
        for slot in slots:
            session.add(
                EventTimeSlot(
                    event_id=event.id,
                    start_time=slot["start_time"],
                    end_time=slot["end_time"],
                    capacity=slot["capacity"],
                    audience=slot["audience"],
                )
            )
    session.flush()
    session.refresh(event)
    return get_event_by_id(session, event.id) or event


def delete_event(session: Session, event: LibraryEvent) -> None:
    session.delete(event)


def create_booking(
    session: Session,
    *,
    slot: EventTimeSlot,
    user_id: uuid.UUID,
) -> EventBooking:
    booking = EventBooking(slot_id=slot.id, user_id=user_id)
    session.add(booking)
    session.flush()
    return booking


def delete_booking(session: Session, booking: EventBooking) -> None:
    session.delete(booking)


def find_booking(
    session: Session,
    *,
    slot_id: uuid.UUID,
    user_id: uuid.UUID,
) -> EventBooking | None:
    return session.scalar(
        select(EventBooking).where(
            EventBooking.slot_id == slot_id,
            EventBooking.user_id == user_id,
        )
    )


def count_bookings_for_slot(session: Session, slot_id: uuid.UUID) -> int:
    return int(
        session.scalar(
            select(func.count())
            .select_from(EventBooking)
            .where(EventBooking.slot_id == slot_id)
        )
        or 0
    )


def availability_counts_for_user(
    session: Session,
    *,
    user_id: uuid.UUID,
    audiences: list[str],
    from_date: date,
    to_date: date,
    today: date,
) -> tuple[int, int]:
    """Count bookable slots and distinct events without loading full event trees."""
    effective_from = max(from_date, today)
    booked_count = (
        select(func.count())
        .select_from(EventBooking)
        .where(EventBooking.slot_id == EventTimeSlot.id)
        .correlate(EventTimeSlot)
        .scalar_subquery()
    )
    user_already_booked = exists(
        select(1).where(
            EventBooking.slot_id == EventTimeSlot.id,
            EventBooking.user_id == user_id,
        )
    )
    stmt = (
        select(EventTimeSlot.event_id)
        .join(LibraryEvent, LibraryEvent.id == EventTimeSlot.event_id)
        .where(
            LibraryEvent.is_published.is_(True),
            LibraryEvent.end_date >= effective_from,
            LibraryEvent.event_date <= to_date,
            EventTimeSlot.audience.in_(audiences),
            booked_count < EventTimeSlot.capacity,
            ~user_already_booked,
        )
    )
    event_ids = session.scalars(stmt).all()
    available_slots = len(event_ids)
    bookable_events = len(set(event_ids))
    return available_slots, bookable_events
