"""Build and send member push reminders for bookings and loans."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.library_sessions import format_pickup_label, is_library_session_day, library_now, loan_return_session_date
from app.models.booking import BOOKING_STATUS_PENDING, Booking
from app.models.duty_session import DutySession
from app.models.library_event import EventBooking, EventTimeSlot, LibraryEvent
from app.models.loan import LOAN_STATUS_ACTIVE, Loan
from app.models.profile import Profile
from app.models.push_notification_log import PushNotificationLog
from app.repositories.device_token_repo import list_tokens_for_user
from app.services.fcm_client import firebase_configured, send_push_notification
from app.services.loan_service import loan_is_overdue

EVE_REMINDER_HOUR = 18
DUTY_EVE_REMINDER_HOUR = 17
MORNING_REMINDER_HOUR = 9

# Allow cron to run within the first 45 minutes of the slot hour.
SLOT_MINUTE_WINDOW = 45


@dataclass(frozen=True)
class PushReminder:
    user_id: uuid.UUID
    dedupe_key: str
    title: str
    body: str


def _toy_label(toy_name: str | None, toy_id: str) -> str:
    cleaned = (toy_name or "").strip()
    return cleaned or toy_id


def _active_reminder_slot(now: datetime) -> str | None:
    if now.minute >= SLOT_MINUTE_WINDOW:
        return None
    hour = now.hour
    if hour == DUTY_EVE_REMINDER_HOUR:
        return "duty_eve"
    if hour == EVE_REMINDER_HOUR:
        return "eve"
    if hour == MORNING_REMINDER_HOUR:
        return "morning"
    return None


def collect_due_push_reminders(
    session: Session,
    *,
    now: datetime | None = None,
) -> list[PushReminder]:
    clock = now or library_now()
    slot = _active_reminder_slot(clock)
    if slot is None:
        return []

    today = clock.date()
    tomorrow = today + timedelta(days=1)
    reminders: list[PushReminder] = []

    if slot == "duty_eve":
        reminders.extend(_duty_eve_reminders(session, session_date=tomorrow))
        reminders.extend(_event_eve_reminders(session, event_date=tomorrow))
    elif slot == "eve":
        reminders.extend(
            _booking_reminders(
                session,
                pickup_date=tomorrow,
                kind="pickup_eve",
                title="Toy pickup tomorrow",
                body_for=lambda toy, label: (
                    f"Pick up {toy} ({label})."
                    if label
                    else f"Pick up {toy} on the next library session."
                ),
            )
        )
        reminders.extend(
            _loan_reminders(
                session,
                session_date=tomorrow,
                kind="return_eve",
                title="Toy return tomorrow",
                body_for=lambda toy: f"Return {toy} on the next library session.",
            )
        )
        reminders.extend(_overdue_session_eve_reminders(session, today=today))
    elif slot == "morning":
        reminders.extend(
            _booking_reminders(
                session,
                pickup_date=today,
                kind="pickup_day",
                title="Toy pickup today",
                body_for=lambda toy, label: (
                    f"Pick up {toy} ({label}) at the library."
                    if label
                    else f"Pick up {toy} at the library today."
                ),
            )
        )
        reminders.extend(
            _loan_reminders(
                session,
                session_date=today,
                kind="return_day",
                title="Toy return due today",
                body_for=lambda toy: f"Return {toy} at the library today.",
            )
        )
    return reminders


def _overdue_session_eve_reminders(
    session: Session,
    *,
    today: date,
) -> list[PushReminder]:
    """6 pm the evening before each library session, while the loan is overdue."""
    tomorrow = today + timedelta(days=1)
    if not is_library_session_day(tomorrow):
        return []

    rows = session.scalars(
        select(Loan)
        .options(joinedload(Loan.toy), joinedload(Loan.profile))
        .where(Loan.status == LOAN_STATUS_ACTIVE)
    ).unique().all()

    session_label = format_pickup_label(tomorrow)
    out: list[PushReminder] = []
    for loan in rows:
        if not loan_is_overdue(loan, today=today):
            continue
        if not _user_wants_reminders(loan.profile):
            continue
        toy = _toy_label(loan.toy.name if loan.toy else None, loan.toy_id)
        out.append(
            PushReminder(
                user_id=loan.user_id,
                dedupe_key=f"loan:{loan.id}:overdue_eve:{tomorrow.isoformat()}",
                title="Toy overdue",
                body=f"{toy} is overdue. Please return it tomorrow ({session_label}).",
            )
        )
    return out


def _format_duty_time(value: time) -> str:
    hour = value.hour
    minute = value.minute
    period = "pm" if hour >= 12 else "am"
    display_hour = hour % 12 or 12
    if minute == 0:
        return f"{display_hour} {period}"
    return f"{display_hour}:{minute:02d} {period}"


def _duty_eve_reminders(
    session: Session,
    *,
    session_date: date,
) -> list[PushReminder]:
    """5 pm the day before a booked volunteer duty shift."""
    rows = session.scalars(
        select(DutySession)
        .options(joinedload(DutySession.volunteer))
        .where(
            DutySession.session_date == session_date,
            DutySession.volunteer_id.is_not(None),
        )
        .order_by(DutySession.start_time)
    ).unique().all()

    date_label = format_pickup_label(session_date)
    out: list[PushReminder] = []
    for duty in rows:
        if duty.volunteer_id is None:
            continue
        if not _user_wants_reminders(duty.volunteer):
            continue
        start = _format_duty_time(duty.start_time)
        end = _format_duty_time(duty.end_time)
        out.append(
            PushReminder(
                user_id=duty.volunteer_id,
                dedupe_key=f"duty:{duty.id}:eve:{session_date.isoformat()}",
                title="Volunteer duty tomorrow",
                body=(
                    f"You're on duty tomorrow ({date_label}), "
                    f"{start}–{end}. Thank you for volunteering!"
                ),
            )
        )
    return out


def _event_eve_reminders(
    session: Session,
    *,
    event_date: date,
) -> list[PushReminder]:
    """5 pm the day before a booked library event."""
    rows = session.scalars(
        select(EventBooking)
        .join(EventTimeSlot, EventBooking.slot_id == EventTimeSlot.id)
        .join(LibraryEvent, EventTimeSlot.event_id == LibraryEvent.id)
        .options(
            joinedload(EventBooking.user),
            joinedload(EventBooking.slot).joinedload(EventTimeSlot.event),
        )
        .where(
            LibraryEvent.is_published.is_(True),
            LibraryEvent.event_date == event_date,
        )
        .order_by(LibraryEvent.name, EventTimeSlot.start_time)
    ).unique().all()

    date_label = format_pickup_label(event_date)
    out: list[PushReminder] = []
    for booking in rows:
        if not _user_wants_reminders(booking.user):
            continue
        slot = booking.slot
        event = slot.event if slot is not None else None
        if event is None:
            continue
        start = _format_duty_time(slot.start_time)
        end = _format_duty_time(slot.end_time)
        out.append(
            PushReminder(
                user_id=booking.user_id,
                dedupe_key=(
                    f"event_booking:{booking.id}:eve:{event_date.isoformat()}"
                ),
                title="Library event tomorrow",
                body=(
                    f"{event.name} is tomorrow ({date_label}), "
                    f"{start}–{end}."
                ),
            )
        )
    return out


def _booking_reminders(
    session: Session,
    *,
    pickup_date: date,
    kind: str,
    title: str,
    body_for,
) -> list[PushReminder]:
    rows = session.scalars(
        select(Booking)
        .options(joinedload(Booking.toy), joinedload(Booking.profile))
        .where(
            Booking.status == BOOKING_STATUS_PENDING,
            Booking.pickup_date == pickup_date,
        )
    ).unique().all()

    out: list[PushReminder] = []
    for booking in rows:
        if not _user_wants_reminders(booking.profile):
            continue
        toy = _toy_label(booking.toy.name if booking.toy else None, booking.toy_id)
        label = (
            format_pickup_label(booking.pickup_date)
            if booking.pickup_date
            else None
        )
        out.append(
            PushReminder(
                user_id=booking.user_id,
                dedupe_key=f"booking:{booking.id}:{kind}:{pickup_date.isoformat()}",
                title=title,
                body=body_for(toy, label),
            )
        )
    return out


def _loan_reminders(
    session: Session,
    *,
    session_date: date,
    kind: str,
    title: str,
    body_for,
) -> list[PushReminder]:
    rows = session.scalars(
        select(Loan)
        .options(joinedload(Loan.toy), joinedload(Loan.profile))
        .where(Loan.status == LOAN_STATUS_ACTIVE)
    ).unique().all()

    out: list[PushReminder] = []
    for loan in rows:
        if loan_return_session_date(loan.due_date) != session_date:
            continue
        if not _user_wants_reminders(loan.profile):
            continue
        toy = _toy_label(loan.toy.name if loan.toy else None, loan.toy_id)
        out.append(
            PushReminder(
                user_id=loan.user_id,
                dedupe_key=f"loan:{loan.id}:{kind}:{session_date.isoformat()}",
                title=title,
                body=body_for(toy),
            )
        )
    return out


def _user_wants_reminders(profile: Profile | None) -> bool:
    return profile is not None and profile.text_reminders_consent is True


def send_due_member_push_reminders(
    session: Session,
    *,
    now: datetime | None = None,
) -> dict[str, int | str | bool]:
    clock = now or library_now()
    slot = _active_reminder_slot(clock) or "none"
    reminders = collect_due_push_reminders(session, now=clock)

    sent = 0
    skipped = 0
    failed = 0

    if not reminders:
        return {
            "slot": slot,
            "reminders_found": 0,
            "sent": 0,
            "skipped_already_sent": 0,
            "failed": 0,
            "firebase_configured": firebase_configured(),
        }

    for reminder in reminders:
        existing = session.get(PushNotificationLog, reminder.dedupe_key)
        if existing is not None:
            skipped += 1
            continue

        tokens = list_tokens_for_user(session, reminder.user_id)
        if not tokens:
            skipped += 1
            continue

        success, failure = send_push_notification(
            tokens,
            title=reminder.title,
            body=reminder.body,
        )
        if success <= 0:
            failed += 1
            continue

        session.add(
            PushNotificationLog(
                dedupe_key=reminder.dedupe_key,
                user_id=reminder.user_id,
            )
        )
        sent += success
        failed += failure

    session.commit()
    return {
        "slot": slot,
        "reminders_found": len(reminders),
        "sent": sent,
        "skipped_already_sent": skipped,
        "failed": failed,
        "firebase_configured": firebase_configured(),
    }
