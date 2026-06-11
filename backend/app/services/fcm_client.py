"""Firebase Cloud Messaging delivery (optional — requires service account JSON)."""

from __future__ import annotations

import logging
from pathlib import Path

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_firebase_ready = False


def firebase_configured() -> bool:
    path = get_settings().firebase_credentials_path
    return bool(path and Path(path).expanduser().is_file())


def ensure_firebase_initialized() -> bool:
    global _firebase_ready
    if _firebase_ready:
        return True

    cred_path = get_settings().firebase_credentials_path
    if not cred_path:
        return False
    resolved = Path(cred_path).expanduser().resolve()
    if not resolved.is_file():
        logger.warning("Firebase credentials file not found: %s", resolved)
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(resolved))
            firebase_admin.initialize_app(cred)
        _firebase_ready = True
        return True
    except Exception:
        logger.exception("Failed to initialize Firebase Admin SDK")
        return False


def send_push_notification(
    tokens: list[str],
    *,
    title: str,
    body: str,
) -> tuple[int, int]:
    """
    Send the same notification to many device tokens.

    Returns (success_count, failure_count).
    """
    cleaned = [token.strip() for token in tokens if token and token.strip()]
    if not cleaned:
        return 0, 0
    if not ensure_firebase_initialized():
        return 0, len(cleaned)

    from firebase_admin import messaging

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        tokens=cleaned,
    )
    try:
        batch = messaging.send_each_for_multicast(message)
    except Exception:
        logger.exception("FCM multicast send failed")
        return 0, len(cleaned)

    stale: list[str] = []
    for idx, response in enumerate(batch.responses):
        if response.success:
            continue
        error_code = getattr(response.exception, "code", None)
        if error_code in {
            "registration-token-not-registered",
            "invalid-argument",
            "invalid-registration-token",
        }:
            stale.append(cleaned[idx])

    if stale:
        logger.info("FCM reported %s stale token(s)", len(stale))

    return batch.success_count, batch.failure_count
