"""Shared string formatting helpers."""


def capitalize_first_letter(value: str) -> str:
    """Ensure the first character is uppercase; leave the rest unchanged."""
    if not value:
        return value
    return value[0].upper() + value[1:]
