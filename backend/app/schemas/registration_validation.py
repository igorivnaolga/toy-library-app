"""Regex validation for the membership registration form."""

from __future__ import annotations

import re

FULL_NAME_RE = re.compile(
    r"^[A-Za-z][A-Za-z\s'.-]{2,98}\s+[A-Za-z][A-Za-z\s'.-]{1,99}$"
)
PERSON_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z\s'.-]{1,99}$")
EMAIL_RE = re.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
ADDRESS_LINE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9\s,.#/''-]{2,119}$")
SUBURB_RE = re.compile(r"^[A-Za-z][A-Za-z\s'.-]{1,79}$")
FREE_TEXT_RE = re.compile(r"^[\s\S]{0,500}$")
PHONE_CHARS_RE = re.compile(r"^[\d\s()+\-.]{7,20}$")


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def validate_full_name(value: str) -> str:
    cleaned = value.strip()
    if not FULL_NAME_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid full name (first and last name).")
    return cleaned


def validate_optional_full_name(value: str | None) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    if not FULL_NAME_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid full name (first and last name).")
    return cleaned


def validate_person_name(value: str) -> str:
    cleaned = value.strip()
    if not cleaned:
        raise ValueError("Enter a valid name.")
    if not PERSON_NAME_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid name.")
    return cleaned


def validate_optional_person_name(value: str | None) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    return validate_person_name(cleaned)


def validate_email(value: str) -> str:
    cleaned = value.strip()
    if not EMAIL_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid email address.")
    return cleaned


def validate_address_line(value: str) -> str:
    cleaned = value.strip()
    if not ADDRESS_LINE_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid address.")
    return cleaned


def validate_optional_address_line(value: str | None) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    if not ADDRESS_LINE_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid address.")
    return cleaned


def validate_suburb(value: str) -> str:
    cleaned = value.strip()
    if not SUBURB_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid suburb.")
    return cleaned


def validate_nz_phone(value: str) -> str:
    cleaned = value.strip()
    if not PHONE_CHARS_RE.fullmatch(cleaned):
        raise ValueError("Enter a valid phone number.")
    digits = re.sub(r"\D", "", cleaned)
    if digits.startswith("64"):
        digits = digits[2:]
    if digits.startswith("0"):
        digits = digits[1:]
    if not 8 <= len(digits) <= 11:
        raise ValueError("Enter a valid New Zealand phone number.")
    return cleaned


def validate_optional_nz_phone(value: str | None) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    return validate_nz_phone(cleaned)


def validate_free_text(value: str) -> str:
    cleaned = value.strip()
    if not FREE_TEXT_RE.fullmatch(cleaned):
        raise ValueError("Enter up to 500 characters.")
    if len(cleaned) < 2:
        raise ValueError("Enter at least 2 characters.")
    return cleaned


def validate_optional_free_text(value: str | None) -> str | None:
    cleaned = _clean_optional(value)
    if cleaned is None:
        return None
    if not FREE_TEXT_RE.fullmatch(cleaned):
        raise ValueError("Enter up to 500 characters.")
    return cleaned
