"""Member device tokens and push reminder hooks."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_principal, require_roles
from app.core.roles import Role
from app.db.session import get_db
from app.repositories.device_token_repo import delete_device_token, upsert_device_token
from app.schemas.notification import (
    DeviceTokenOut,
    DeviceTokenRegisterIn,
    DeviceTokenUnregisterIn,
)
from app.schemas.principal import Principal

router = APIRouter()

_require_member = require_roles(Role.MEMBER, Role.VOLUNTEER)


@router.post("/device", response_model=DeviceTokenOut)
def register_device_token(
    body: DeviceTokenRegisterIn,
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> DeviceTokenOut:
    """Save the phone's FCM token for push reminders."""
    platform = (body.platform or "android").strip().lower() or "android"
    upsert_device_token(
        db,
        user_id=uuid.UUID(principal.id),
        token=body.token,
        platform=platform,
    )
    db.commit()
    return DeviceTokenOut(registered=True)


@router.post("/device/unregister", response_model=DeviceTokenOut)
def unregister_device_token(
    body: DeviceTokenUnregisterIn,
    db: Session = Depends(get_db),
    principal: Principal = Depends(get_current_principal),
) -> DeviceTokenOut:
    """Remove an FCM token (e.g. on sign-out)."""
    delete_device_token(
        db,
        user_id=uuid.UUID(principal.id),
        token=body.token,
    )
    db.commit()
    return DeviceTokenOut(registered=False)
