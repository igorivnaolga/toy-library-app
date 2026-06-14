"""Admin-only maintenance and panel data."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin
from app.core.config import get_settings
from app.db.session import get_db
from app.repositories.category_repo import update_category_label
from app.repositories.duty_repo import (
    count_completed_duty_sessions,
    list_todays_unconfirmed_duty_sessions,
    list_volunteer_booked_duty_sessions,
)
from app.repositories.profile_repo import (
    RECENT_MEMBERS_DAYS,
    approve_duty_volunteer,
    count_pending_duty_members,
    count_recent_members,
    get_profile_by_id,
    get_user_email,
    kids_from_profile,
    list_members_for_admin,
    list_pending_duty_members,
    list_recent_members_for_admin,
    update_member_for_admin,
    update_membership_tier_for_admin,
)
from app.schemas.admin import (
    AdminBookingsListResponse,
    AdminMemberDetailOut,
    AdminMemberOut,
    AdminMembersListResponse,
    AdminMembershipUpdateIn,
    AdminMemberUpdateIn,
    AdminNotificationsOut,
)
from app.schemas.booking import booking_out_from_model
from app.schemas.category import CategoryOut, CategoryUpdateIn
from app.schemas.duty import (
    DutySessionOut,
    VolunteerDutyProfileOut,
    duty_session_out_from_model,
)
from app.schemas.notification import MemberPushRemindersResult
from app.models.category import Category
from app.models.toy import Toy
from app.schemas.loan import LoanOut, LoansListResponse, loan_out_from_model
from app.schemas.principal import Principal, ProfileContactOut
from app.schemas.toy import ToyCreate, ToyOut, ToyUpdate
from app.services.booking_service import list_bookings_for_admin_service
from app.services.duty_service import split_volunteer_duty_sessions
from app.services.loan_service import list_my_loans_service, renewals_remaining_for_loan
from app.services.payment_service import (
    balance_summary,
    membership_payment_summary,
    refresh_membership_payments_for_tier,
)
from app.services.toy_photo_upload import upload_toy_photo_service
from app.services.toy_service import create_toy_service, delete_toy_service, update_toy_service

router = APIRouter()


class PendingDutyVolunteerOut(BaseModel):
    user_id: str = Field(description="Supabase auth user id")
    email: str = ""
    full_name: str = ""


class PendingDutyVolunteersOut(BaseModel):
    data: list[PendingDutyVolunteerOut]


class TodaysDutyShiftsOut(BaseModel):
    data: list[DutySessionOut]


@router.post(
    "/notifications/send-member-reminders",
    response_model=MemberPushRemindersResult,
)
def send_member_push_reminders(
    db: Session = Depends(get_db),
    principal: Principal = Depends(require_admin),
) -> MemberPushRemindersResult:
    """
    Send due booking/loan push reminders (admin or cron).

    Schedule this endpoint around 6:00 and 9:00 Pacific/Auckland.
    """
    _ = principal
    result = send_due_member_push_reminders(db)
    return MemberPushRemindersResult(**result)


@router.post(
    "/notifications/send-member-reminders/cron",
    response_model=MemberPushRemindersResult,
    include_in_schema=False,
)
def send_member_push_reminders_cron(
    db: Session = Depends(get_db),
    cron_secret: str | None = Header(default=None, alias="X-Cron-Secret"),
) -> MemberPushRemindersResult:
    """Cron entry point protected by ``CRON_SECRET`` env."""
    expected = get_settings().cron_secret
    if not expected or cron_secret != expected:
        raise HTTPException(status_code=403, detail="Invalid cron secret")
    result = send_due_member_push_reminders(db)
    return MemberPushRemindersResult(**result)


@router.get("/notifications", response_model=AdminNotificationsOut)
def admin_notifications(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminNotificationsOut:
    return AdminNotificationsOut(
        pending_volunteer_approvals=count_pending_duty_members(db),
        pending_duty_confirmations=0,
        new_members_count=count_recent_members(db),
    )


@router.get("/todays-duty-shifts", response_model=TodaysDutyShiftsOut)
def todays_duty_shifts(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> TodaysDutyShiftsOut:
    """Booked duty shifts today that still need admin confirmation."""
    rows = list_todays_unconfirmed_duty_sessions(db)
    return TodaysDutyShiftsOut(
        data=[duty_session_out_from_model(row, db) for row in rows],
    )


@router.get("/recent-members", response_model=AdminMembersListResponse)
def recent_members(
    days: int = Query(
        RECENT_MEMBERS_DAYS,
        ge=1,
        le=90,
        description="Include members whose account was created within this many days.",
    ),
    limit: int = Query(50, ge=1, le=200),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMembersListResponse:
    rows = list_recent_members_for_admin(db, days=days, limit=limit)
    return AdminMembersListResponse(
        data=[AdminMemberOut.model_validate(row) for row in rows],
    )


@router.get("/pending-duty-volunteers", response_model=PendingDutyVolunteersOut)
def pending_duty_volunteers(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PendingDutyVolunteersOut:
    rows = list_pending_duty_members(db)
    return PendingDutyVolunteersOut(
        data=[PendingDutyVolunteerOut.model_validate(r) for r in rows],
    )


@router.post("/users/{user_id}/approve-volunteer")
def approve_volunteer(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> dict[str, str | bool]:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.membership_tier != "duty":
        raise HTTPException(
            status_code=400,
            detail="User is not on duty tier; nothing to approve as volunteer.",
        )
    if profile.volunteer_confirmed and profile.role == "volunteer":
        return {"ok": True, "user_id": str(user_id), "already_approved": True}
    try:
        approve_duty_volunteer(db, profile)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    db.commit()
    return {"ok": True, "user_id": str(user_id), "already_approved": False}


@router.get("/bookings", response_model=AdminBookingsListResponse)
def list_all_bookings(
    pickup_from: date | None = Query(None, description="Earliest pickup day."),
    pickup_to: date | None = Query(None, description="Latest pickup day."),
    user_id: uuid.UUID | None = Query(None, description="Filter by member profile id."),
    q: str | None = Query(None, description="Search toy, member name, or email."),
    limit: int = Query(200, ge=1, le=500),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminBookingsListResponse:
    rows = list_bookings_for_admin_service(
        db,
        pickup_from=pickup_from,
        pickup_to=pickup_to,
        user_id=user_id,
        q=q,
        limit=limit,
    )
    return AdminBookingsListResponse(
        data=[
            booking_out_from_model(booking, member_email=email)
            for booking, email in rows
        ],
    )


@router.get("/members", response_model=AdminMembersListResponse)
def list_members(
    membership_tier: str | None = Query(
        None,
        description="casual | non_duty | duty",
    ),
    started_from: date | None = Query(None, description="Membership started on/after."),
    started_to: date | None = Query(None, description="Membership started on/before."),
    ending_from: date | None = Query(None, description="Membership ends on/after."),
    ending_to: date | None = Query(None, description="Membership ends on/before."),
    q: str | None = Query(None, description="Search name, email, or profile id."),
    limit: int = Query(200, ge=1, le=500),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMembersListResponse:
    rows = list_members_for_admin(
        db,
        membership_tier=membership_tier,
        started_from=started_from,
        started_to=started_to,
        ending_from=ending_from,
        ending_to=ending_to,
        q=q,
        limit=limit,
    )
    return AdminMembersListResponse(
        data=[AdminMemberOut.model_validate(row) for row in rows],
    )


def _member_detail_out(session: Session, profile) -> AdminMemberDetailOut:
    created_row = session.execute(
        text("select created_at from auth.users where id = :id"),
        {"id": profile.id},
    ).scalar_one_or_none()
    membership_started_at = created_row
    membership_ends_at = None
    if created_row is not None:
        membership_ends_at = created_row + timedelta(days=365)
    kids = kids_from_profile(profile)
    payment_summary = membership_payment_summary(session, profile.id)
    account_balance = balance_summary(session, profile.id)
    loan_rows = list_my_loans_service(session, profile.id)
    contact = ProfileContactOut.model_validate(profile)
    return AdminMemberDetailOut(
        user_id=str(profile.id),
        email=get_user_email(session, profile.id) or "",
        full_name=profile.full_name or "",
        role=profile.role,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
        membership_started_at=membership_started_at,
        membership_ends_at=membership_ends_at,
        duty_sessions_completed=count_completed_duty_sessions(session, profile.id),
        kids=kids,
        avatar_path=profile.avatar_path,
        admin_notes=profile.admin_notes,
        membership_due_cents=payment_summary.due_cents,
        membership_fees_paid=payment_summary.fees_paid,
        balance_due_cents=account_balance.balance_due_cents,
        credit_balance_cents=account_balance.credit_balance_cents,
        loans=[_admin_loan_out(session, row) for row in loan_rows],
        **contact.model_dump(),
    )


@router.get("/users/{user_id}", response_model=AdminMemberDetailOut)
def get_member_detail(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    return _member_detail_out(db, profile)


def _admin_volunteer_duty_profile_out(
    db: Session,
    volunteer_id: uuid.UUID,
) -> VolunteerDutyProfileOut:
    rows = list_volunteer_booked_duty_sessions(db, volunteer_id)
    upcoming, completed = split_volunteer_duty_sessions(rows)
    return VolunteerDutyProfileOut(
        upcoming=[duty_session_out_from_model(row, db) for row in upcoming],
        completed=[duty_session_out_from_model(row, db) for row in completed],
    )


@router.get("/users/{user_id}/duty-sessions", response_model=VolunteerDutyProfileOut)
def get_member_duty_sessions(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> VolunteerDutyProfileOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    return _admin_volunteer_duty_profile_out(db, user_id)


def _admin_loan_out(db: Session, loan) -> LoanOut:
    toy = loan.toy
    if toy is None:
        toy = db.get(Toy, loan.toy_id)
    max_renewals = None
    if toy is not None and toy.category_id is not None:
        category = db.get(Category, toy.category_id)
        if category is not None:
            max_renewals = category.max_renewals
    return loan_out_from_model(
        loan,
        max_renewals=max_renewals,
        renewals_remaining=renewals_remaining_for_loan(db, loan, max_renewals),
    )


@router.get("/users/{user_id}/loans", response_model=LoansListResponse)
def list_member_loans(
    user_id: uuid.UUID,
    active_only: bool = Query(False, description="Return only active loans."),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> LoansListResponse:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    rows = list_my_loans_service(db, user_id, active_only=active_only)
    return LoansListResponse(data=[_admin_loan_out(db, row) for row in rows])


@router.patch("/users/{user_id}/membership", response_model=AdminMemberDetailOut)
def update_member_membership(
    user_id: uuid.UUID,
    body: AdminMembershipUpdateIn,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    try:
        update_membership_tier_for_admin(db, profile, body.membership_tier)
        refresh_membership_payments_for_tier(db, profile.id, body.membership_tier)
    except ValueError as e:
        code = str(e)
        if code == "cannot_change_admin":
            raise HTTPException(
                status_code=400,
                detail="Cannot change membership for admin accounts.",
            ) from e
        raise HTTPException(status_code=400, detail="Invalid membership tier.") from e
    db.commit()
    db.refresh(profile)
    return _member_detail_out(db, profile)


@router.patch("/users/{user_id}", response_model=AdminMemberDetailOut)
def update_member_profile(
    user_id: uuid.UUID,
    body: AdminMemberUpdateIn,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    update_member_for_admin(
        db,
        profile,
        kids=body.kids,
        admin_notes=body.admin_notes,
        admin_notes_set="admin_notes" in payload,
    )
    db.commit()
    db.refresh(profile)
    return _member_detail_out(db, profile)


@router.patch("/categories/{code}", response_model=CategoryOut)
def rename_category(
    code: str,
    body: CategoryUpdateIn,
    _: Principal = Depends(require_admin),
) -> CategoryOut:
    """Rename a catalog category and update toys that use the old label."""
    try:
        updated = update_category_label(code, body.label)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Category not found or catalog is not loaded in the database yet.",
        )
    return updated


@router.post("/toys", response_model=ToyOut, status_code=201)
def create_toy(
    body: ToyCreate,
    _: Principal = Depends(require_admin),
) -> ToyOut:
    """Add a new toy to the DB-backed catalog."""
    created = create_toy_service(
        name=body.name,
        category=body.category,
        age_range=body.age_range,
        status=body.status,
        manufacturer=body.manufacturer,
        description=body.description,
        total_pieces=body.total_pieces,
        missing_pieces=body.missing_pieces,
        rental_price_cents=body.rental_price_cents,
    )
    if created is None:
        raise HTTPException(
            status_code=503,
            detail="Catalog database is not configured; cannot create toys.",
        )
    return created


@router.patch("/toys/{toy_id}", response_model=ToyOut)
def update_toy(
    toy_id: str,
    body: ToyUpdate,
    _: Principal = Depends(require_admin),
) -> ToyOut:
    """Edit catalog metadata for a toy (requires DB-backed catalog)."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    updated = update_toy_service(
        toy_id,
        name=payload.get("name"),
        category=payload.get("category"),
        age_range=payload.get("age_range"),
        status=payload.get("status"),
        manufacturer=payload.get("manufacturer"),
        description=payload.get("description"),
        total_pieces=payload.get("total_pieces"),
        missing_pieces=payload.get("missing_pieces"),
        rental_price_cents=payload.get("rental_price_cents"),
    )
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return updated


@router.delete("/toys/{toy_id}")
def delete_toy(
    toy_id: str,
    _: Principal = Depends(require_admin),
) -> dict[str, bool | str]:
    """Remove a toy from the DB-backed catalog."""
    deleted = delete_toy_service(toy_id)
    if deleted is None:
        raise HTTPException(
            status_code=503,
            detail="Catalog database is not configured; cannot delete toys.",
        )
    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return {"deleted": True, "toy_id": toy_id.strip()}


@router.post("/toys/{toy_id}/photo", response_model=ToyOut)
async def upload_toy_photo(
    toy_id: str,
    image: UploadFile = File(...),
    _: Principal = Depends(require_admin),
) -> ToyOut:
    """Upload or replace the catalog photo for a toy."""
    data = await image.read()
    try:
        updated = upload_toy_photo_service(
            toy_id,
            data,
            content_type=image.content_type,
        )
    except ValueError as exc:
        status = 413 if "too large" in str(exc).lower() else 422
        raise HTTPException(status_code=status, detail=str(exc)) from exc
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return updated
