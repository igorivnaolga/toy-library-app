"""Authenticated caller context after Supabase JWT + profile lookup."""

from __future__ import annotations

import uuid

from pydantic import BaseModel, Field

from app.core.roles import Role


class Principal(BaseModel):
    """Maps a verified Supabase user + row in `public.profiles`."""

    id: uuid.UUID = Field(description="Same as `auth.users.id` / JWT `sub`.")
    email: str | None = None
    role: Role
    full_name: str | None = None
    membership_tier: str | None = None
    volunteer_confirmed: bool = False

    model_config = {"frozen": True}


class MeOut(BaseModel):
    user_id: uuid.UUID
    email: str | None = None
    role: Role
    full_name: str | None = None
    membership_tier: str | None = None
    volunteer_confirmed: bool = False
