"""Authenticated caller context after Supabase JWT + profile lookup."""

from __future__ import annotations

import uuid

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.roles import Role
from app.schemas.registration_validation import (
    validate_address_line,
    validate_email,
    validate_free_text,
    validate_full_name,
    validate_nz_phone,
    validate_optional_address_line,
    validate_optional_free_text,
    validate_optional_full_name,
    validate_optional_nz_phone,
    validate_person_name,
    validate_suburb,
)


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


class ProfileContactOut(BaseModel):
    parent_b_name: str | None = None
    address_line1: str | None = None
    address_line2: str | None = None
    suburb: str | None = None
    mobile_phone: str | None = None
    alt_contact_name: str | None = None
    alt_contact_address: str | None = None
    alt_contact_phone: str | None = None
    heard_about_us: str | None = None
    skills: str | None = None
    text_reminders_consent: bool | None = None
    terms_accepted_at: datetime | None = None
    registered_at: date | None = None


class MeOut(ProfileContactOut):
    user_id: uuid.UUID
    email: str | None = None
    role: Role
    full_name: str | None = None
    membership_tier: str | None = None
    volunteer_confirmed: bool = False
    kids: list[KidProfile] = Field(default_factory=list)
    kids_names: list[str] = Field(default_factory=list)
    avatar_path: str | None = None


class ProfileUpdateIn(ProfileContactOut):
    kids: list[KidProfile] | None = None
    avatar_path: str | None = None


class RegistrationCompleteIn(BaseModel):
    """Paper membership form submitted during app registration."""

    full_name: str = Field(min_length=1, max_length=100, description="Parent A full name")
    parent_b_name: str | None = Field(default=None, max_length=100)
    address_line1: str | None = Field(default=None, max_length=120)
    address_line2: str | None = Field(default=None, max_length=120)
    suburb: str | None = Field(default=None, max_length=80)
    mobile_phone: str | None = Field(default=None, max_length=20)
    alt_contact_name: str | None = Field(default=None, max_length=100)
    alt_contact_address: str | None = Field(default=None, max_length=120)
    alt_contact_phone: str | None = Field(default=None, max_length=20)
    heard_about_us: str | None = Field(default=None, max_length=500)
    skills: str | None = Field(default=None, max_length=500)
    kids: list[KidProfile] = Field(default_factory=list)
    membership_tier: Literal["casual", "non_duty", "duty"]
    text_reminders_consent: bool | None = None
    registered_at: date | None = None
    terms_accepted: bool = False
    liability_accepted: bool = False

    @field_validator("full_name")
    @classmethod
    def _validate_full_name(cls, value: str) -> str:
        return validate_full_name(value)

    @field_validator("parent_b_name")
    @classmethod
    def _validate_parent_b_name(cls, value: str | None) -> str | None:
        return validate_optional_full_name(value)

    @field_validator("address_line1")
    @classmethod
    def _validate_address_line1(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter your street address.")
        return validate_address_line(value)

    @field_validator("address_line2")
    @classmethod
    def _validate_address_line2(cls, value: str | None) -> str | None:
        return validate_optional_address_line(value)

    @field_validator("suburb")
    @classmethod
    def _validate_suburb(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter your suburb.")
        return validate_suburb(value)

    @field_validator("mobile_phone")
    @classmethod
    def _validate_mobile_phone(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter your mobile phone number.")
        return validate_nz_phone(value)

    @field_validator("alt_contact_name")
    @classmethod
    def _validate_alt_contact_name(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter the alternative contact full name.")
        return validate_full_name(value)

    @field_validator("alt_contact_address")
    @classmethod
    def _validate_alt_contact_address(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter the alternative contact address.")
        return validate_address_line(value)

    @field_validator("alt_contact_phone")
    @classmethod
    def _validate_alt_contact_phone(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Enter the alternative contact phone number.")
        return validate_nz_phone(value)

    @field_validator("heard_about_us")
    @classmethod
    def _validate_heard_about_us(cls, value: str | None) -> str:
        if value is None or not value.strip():
            raise ValueError("Tell us how you heard about the library.")
        return validate_free_text(value)

    @field_validator("skills")
    @classmethod
    def _validate_skills(cls, value: str | None) -> str | None:
        return validate_optional_free_text(value)

    @field_validator("kids")
    @classmethod
    def _validate_kids(cls, value: list[KidProfile]) -> list[KidProfile]:
        if len(value) > 4:
            raise ValueError("You can add up to 4 children on the form.")
        for kid in value:
            validate_person_name(kid.name)
            if kid.birth_date is None:
                raise ValueError("Enter each child's date of birth.")
        return value

    @model_validator(mode="after")
    def _require_agreements(self) -> "RegistrationCompleteIn":
        if not self.terms_accepted or not self.liability_accepted:
            raise ValueError("Membership terms and liability waiver must be accepted.")
        return self
