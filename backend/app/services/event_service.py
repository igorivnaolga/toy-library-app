"""Library event business rules."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from app.core.library_sessions import library_now
from app.repositories.duty_repo import (
    list_duty_dates_in_range,
    list_my_duty_dates_in_range,
)
from app.core.roles import Role, parse_role
from app.repositories.event_repo import (
    availability_counts_for_user,
    count_bookings_for_slot,
    create_booking,
    create_event,
    delete_booking,
    delete_event,
    find_booking,
    get_event_by_id,
    get_slot_by_id,
    list_event_dates_in_range,
    list_event_dates_in_range_for_audiences,
    list_events_in_range,
    update_event,
)
from app.repositories.profile_repo import (
    get_profile_by_id,
    get_user_display_map,
    get_user_email,
)


@dataclass(frozen=True)
class EventError:
    code: str
    message: str


def _slots_payload(slots) -> list[dict]:
    return [
        {
            "start_time": slot.start_time,
            "end_time": slot.end_time,
            "capacity": slot.capacity,
            "audience": slot.audience,
        }
        for slot in slots
    ]


def _user_display(session: Session, user_id: uuid.UUID) -> tuple[str, str]:
    profile = get_profile_by_id(session, user_id)
    email = get_user_email(session, user_id) or ""
    name = (profile.full_name if profile else None) or ""
    return name, email


def _booking_user_ids(event) -> set[uuid.UUID]:
    ids: set[uuid.UUID] = set()
    for slot in event.slots:
        if not slot.bookings:
            continue
        for booking in slot.bookings:
            ids.add(booking.user_id)
    return ids


def slot_out_from_model(
    session: Session,
    slot,
    *,
    current_user_id: uuid.UUID | None = None,
    include_bookings: bool = False,
    display_map: dict[uuid.UUID, tuple[str, str]] | None = None,
):
    from app.schemas.event import EventBookingUserOut, EventSlotOut

    booked_count = len(slot.bookings) if slot.bookings is not None else count_bookings_for_slot(
        session, slot.id
    )
    spots_left = max(0, slot.capacity - booked_count)
    user_booked = False
    if current_user_id is not None and slot.bookings:
        user_booked = any(b.user_id == current_user_id for b in slot.bookings)

    bookings_out = []
    if include_bookings and slot.bookings:
        for booking in slot.bookings:
            if display_map is not None:
                name, email = display_map.get(booking.user_id, ("", ""))
            else:
                name, email = _user_display(session, booking.user_id)
            bookings_out.append(
                EventBookingUserOut(
                    user_id=str(booking.user_id),
                    full_name=name,
                    email=email,
                )
            )

    return EventSlotOut(
        slot_id=str(slot.id),
        start_time=slot.start_time.strftime("%H:%M:%S"),
        end_time=slot.end_time.strftime("%H:%M:%S"),
        capacity=slot.capacity,
        audience=slot.audience,
        booked_count=booked_count,
        spots_left=spots_left,
        is_full=spots_left == 0,
        user_booked=user_booked,
        bookings=bookings_out,
    )


def event_out_from_model(
    session: Session,
    event,
    *,
    current_user_id: uuid.UUID | None = None,
    include_bookings: bool = False,
):
    from app.schemas.event import EventOut

    user_display: dict[uuid.UUID, tuple[str, str]] | None = None
    if include_bookings:
        user_display = get_user_display_map(session, _booking_user_ids(event))

    return EventOut(
        event_id=str(event.id),
        name=event.name,
        description=event.description,
        event_date=event.event_date,
        end_date=event.end_date,
        is_published=event.is_published,
        created_at=event.created_at,
        slots=[
            slot_out_from_model(
                session,
                slot,
                current_user_id=current_user_id,
                include_bookings=include_bookings,
                display_map=user_display,
            )
            for slot in event.slots
        ],
    )


def audiences_for_role(role: Role) -> list[str] | None:
    """Slot audiences visible and bookable for self-service by role."""
    if role == Role.VOLUNTEER:
        return ["volunteer", "member"]
    if role == Role.MEMBER:
        return ["member"]
    return None


def can_self_book_slot(role: Role, slot_audience: str) -> bool:
    if role == Role.VOLUNTEER:
        return slot_audience in ("volunteer", "member")
    if role == Role.MEMBER:
        return slot_audience == "member"
    return False


def list_events_for_user(
    session: Session,
    *,
    from_date: date,
    to_date: date,
    current_user_id: uuid.UUID | None,
    role: Role,
    published_only: bool = True,
    include_bookings: bool = False,
):
    rows = list_events_in_range(
        session,
        from_date=from_date,
        to_date=to_date,
        published_only=published_only,
    )
    audiences = audiences_for_role(role)
    result = []
    for event in rows:
        out = event_out_from_model(
            session,
            event,
            current_user_id=current_user_id,
            include_bookings=include_bookings,
        )
        if audiences is not None:
            allowed = set(audiences)
            out.slots = [s for s in out.slots if s.audience in allowed]
        if published_only and not out.slots:
            continue
        result.append(out)
    return result


def availability_for_user(
    session: Session,
    *,
    current_user_id: uuid.UUID,
    role: Role,
    from_date: date,
    to_date: date,
) -> tuple[int, int]:
    audiences = audiences_for_role(role)
    if not audiences:
        return 0, 0
    today = library_now().date()
    return availability_counts_for_user(
        session,
        user_id=current_user_id,
        audiences=audiences,
        from_date=from_date,
        to_date=to_date,
        today=today,
    )


def create_event_service(
    session: Session,
    *,
    name: str,
    description: str | None,
    event_date: date,
    end_date: date | None,
    is_published: bool,
    created_by: uuid.UUID,
    slots,
):
    resolved_end = end_date or event_date
    if resolved_end < event_date:
        raise EventError("invalid_dates", "End date must be on or after start date.")
    if resolved_end < library_now().date():
        raise EventError("past_date", "Event must end today or in the future.")
    event = create_event(
        session,
        name=name,
        description=description,
        event_date=event_date,
        end_date=resolved_end,
        is_published=is_published,
        created_by=created_by,
        slots=_slots_payload(slots),
    )
    return event


def update_event_service(
    session: Session,
    event_id: uuid.UUID,
    *,
    name: str | None = None,
    description: str | None = None,
    event_date: date | None = None,
    end_date: date | None = None,
    is_published: bool | None = None,
    slots=None,
):
    event = get_event_by_id(session, event_id)
    if event is None:
        raise EventError("not_found", "Event not found.")
    new_start = event_date if event_date is not None else event.event_date
    new_end = end_date if end_date is not None else event.end_date
    if new_end < new_start:
        raise EventError("invalid_dates", "End date must be on or after start date.")
    if new_end < library_now().date():
        raise EventError("past_date", "Event must end today or in the future.")
    return update_event(
        session,
        event,
        name=name,
        description=description,
        event_date=event_date,
        end_date=end_date,
        is_published=is_published,
        slots=_slots_payload(slots) if slots is not None else None,
    )


def delete_event_service(session: Session, event_id: uuid.UUID) -> None:
    event = get_event_by_id(session, event_id)
    if event is None:
        raise EventError("not_found", "Event not found.")
    delete_event(session, event)


def book_slot_service(
    session: Session,
    *,
    slot_id: uuid.UUID,
    user_id: uuid.UUID,
    role: Role,
) -> tuple[uuid.UUID, uuid.UUID]:
    slot = get_slot_by_id(session, slot_id)
    if slot is None or slot.event is None:
        raise EventError("not_found", "Time slot not found.")
    event = slot.event
    if not event.is_published:
        raise EventError("unpublished", "This event is not open for booking.")
    if event.end_date < library_now().date():
        raise EventError("past_event", "This event has already passed.")

    if not can_self_book_slot(role, slot.audience):
        raise EventError(
            "wrong_audience",
            "This slot is not available for your account type.",
        )

    booked_count = len(slot.bookings) if slot.bookings else count_bookings_for_slot(
        session, slot.id
    )
    if booked_count >= slot.capacity:
        raise EventError("full", "This time slot is fully booked.")
    if find_booking(session, slot_id=slot.id, user_id=user_id) is not None:
        raise EventError("already_booked", "You have already booked this slot.")

    create_booking(session, slot=slot, user_id=user_id)
    session.flush()
    return slot.id, event.id


def cancel_booking_service(
    session: Session,
    *,
    slot_id: uuid.UUID,
    user_id: uuid.UUID,
    role: Role,
    admin_override: bool = False,
) -> tuple[uuid.UUID, uuid.UUID]:
    slot = get_slot_by_id(session, slot_id)
    if slot is None or slot.event is None:
        raise EventError("not_found", "Time slot not found.")
    event = slot.event
    booking = find_booking(session, slot_id=slot_id, user_id=user_id)
    if booking is None and not admin_override:
        raise EventError("not_booked", "You are not booked on this slot.")
    if booking is not None:
        delete_booking(session, booking)
        session.flush()
    return slot.id, event.id


def _assignee_fits_audience(profile_role: str, audience: str) -> bool:
    role = parse_role(profile_role)
    if audience == "volunteer":
        return role in {Role.VOLUNTEER, Role.ADMIN}
    if audience == "member":
        return role in {Role.MEMBER, Role.VOLUNTEER}
    return False


def admin_book_slot_service(
    session: Session,
    *,
    slot_id: uuid.UUID,
    user_id: uuid.UUID,
) -> uuid.UUID:
    slot = get_slot_by_id(session, slot_id)
    if slot is None or slot.event is None:
        raise EventError("not_found", "Time slot not found.")
    event = slot.event
    if not event.is_published:
        raise EventError("unpublished", "This event is not open for booking.")
    if event.end_date < library_now().date():
        raise EventError("past_event", "This event has already passed.")

    profile = get_profile_by_id(session, user_id)
    if profile is None:
        raise EventError("profile_not_found", "User not found.")
    if not _assignee_fits_audience(profile.role, slot.audience):
        label = "volunteers" if slot.audience == "volunteer" else "members"
        raise EventError(
            "invalid_assignee",
            f"Only {label} can be booked on this slot.",
        )

    booked_count = len(slot.bookings) if slot.bookings else count_bookings_for_slot(
        session, slot.id
    )
    if booked_count >= slot.capacity:
        raise EventError("full", "This time slot is fully booked.")
    if find_booking(session, slot_id=slot.id, user_id=user_id) is not None:
        raise EventError("already_booked", "This user is already booked on this slot.")

    create_booking(session, slot=slot, user_id=user_id)
    session.flush()
    return event.id


def admin_cancel_booking_service(
    session: Session,
    *,
    slot_id: uuid.UUID,
    user_id: uuid.UUID,
) -> uuid.UUID:
    slot = get_slot_by_id(session, slot_id)
    if slot is None or slot.event is None:
        raise EventError("not_found", "Time slot not found.")
    event = slot.event
    booking = find_booking(session, slot_id=slot_id, user_id=user_id)
    if booking is None:
        raise EventError("not_booked", "This user is not booked on this slot.")
    delete_booking(session, booking)
    session.flush()
    return event.id


def schedule_dates_in_range(
    session: Session,
    *,
    from_date: date,
    to_date: date,
    role: Role,
    user_id: uuid.UUID | None = None,
) -> tuple[list[date], list[date]]:
    audiences = audiences_for_role(role)
    if role in {Role.VOLUNTEER, Role.ADMIN}:
        duty_dates = list_duty_dates_in_range(
            session, from_date=from_date, to_date=to_date
        )
        if role == Role.VOLUNTEER and user_id is not None:
            my_dates = list_my_duty_dates_in_range(
                session,
                user_id=user_id,
                from_date=from_date,
                to_date=to_date,
            )
            duty_dates = sorted(set(duty_dates) | set(my_dates))
    else:
        duty_dates = []

    if audiences is None:
        event_dates = list_event_dates_in_range(
            session, from_date=from_date, to_date=to_date
        )
    else:
        event_dates = list_event_dates_in_range_for_audiences(
            session,
            from_date=from_date,
            to_date=to_date,
            audiences=audiences,
        )
    return duty_dates, event_dates
