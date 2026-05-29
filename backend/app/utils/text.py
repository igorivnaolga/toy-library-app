"""Shared string formatting helpers."""


def capitalize_first_letter(value: str) -> str:
    """Ensure the first character is uppercase; leave the rest unchanged."""
    if not value:
        return value
    return value[0].upper() + value[1:]


def visible_member_name(
    full_name: str | None,
    email: str | None = None,
) -> str | None:
    """Prefer profile full name; otherwise use the full email address."""
    if full_name and full_name.strip():
        return full_name.strip()
    if email and email.strip():
        return email.strip()
    return None
