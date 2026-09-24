"""
Tiny in-process rate limiter for unauthenticated endpoints.

Production runs a single gunicorn worker, so per-process state is enough. With
more workers or replicas, move this to a shared store (e.g. Redis).
"""

from __future__ import annotations

import threading
import time
from collections import deque

from fastapi import HTTPException, Request


def client_ip(request: Request) -> str:
    """
    Best-effort caller IP.

    Uses the right-most ``X-Forwarded-For`` entry (the one appended by our own
    proxy), not the left-most one, which the client controls.
    """
    forwarded = request.headers.get("x-forwarded-for", "")
    parts = [p.strip() for p in forwarded.split(",") if p.strip()]
    if parts:
        return parts[-1]
    return request.client.host if request.client else "unknown"


class RateLimiter:
    """Sliding-window limit: at most ``max_calls`` per ``window_seconds`` per key."""

    def __init__(self, max_calls: int, window_seconds: float) -> None:
        self.max_calls = max_calls
        self.window_seconds = window_seconds
        self._hits: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def check(self, key: str, *, now: float | None = None) -> bool:
        """Record a hit; False when the key is over its limit."""
        now = time.monotonic() if now is None else now
        cutoff = now - self.window_seconds
        with self._lock:
            hits = self._hits.setdefault(key, deque())
            while hits and hits[0] <= cutoff:
                hits.popleft()
            if len(hits) >= self.max_calls:
                return False
            hits.append(now)
            # Drop idle keys occasionally so memory stays bounded.
            if len(self._hits) > 10_000:
                for stale in [k for k, v in self._hits.items() if not v or v[-1] <= cutoff]:
                    del self._hits[stale]
            return True

    def dependency(self):
        """FastAPI dependency raising 429 when the caller's IP is over the limit."""

        def _guard(request: Request) -> None:
            if not self.check(client_ip(request)):
                raise HTTPException(
                    status_code=429,
                    detail="Too many requests. Please wait a minute and try again.",
                )

        return _guard
