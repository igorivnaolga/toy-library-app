"""Authenticated caller context after Supabase JWT + profile lookup."""

from __future__ import annotations

import uuid

from datetime import date

from pydantic import BaseModel, Field

from app.core.roles import Role


class KidProfile(BaseModel):
    name: str
    birth_date: date | None = None


class Principal(BaseModel):
    """Maps a verified Supabase user + row in `public.profiles`."""

    id: uuid.UUID = Field(description="Same as `auth.users.id` / JWT `sub`.")
    email: str | None = None
    role: Role
    full_name: str | None = None
    membership_tier: str | None = None
    volunteer_confirmed: bool = False
    kids: list[KidProfile] = Field(default_factory=list)
    kids_names: list[str] = Field(default_factory=list)
    avatar_path: str | None = None

    model_config = {"frozen": True}


class MeOut(BaseModel):
    user_id: uuid.UUID
    email: str | None = None
    role: Role
    full_name: str | None = None
    membership_tier: str | None = None
    volunteer_confirmed: bool = False
    kids: list[KidProfile] = Field(default_factory=list)
    kids_names: list[str] = Field(default_factory=list)
    avatar_path: str | None = None


class ProfileUpdateIn(BaseModel):
    full_name: str | None = None
    kids: list[KidProfile] | None = None
    avatar_path: str | None = None
