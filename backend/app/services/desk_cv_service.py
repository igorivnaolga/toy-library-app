"""Advisory piece-count estimate from a returned-toy photo.

The estimate is deliberately conservative and marked low/medium confidence:
volunteers always confirm the final missing-piece count at check-in. The blob
counter below is intentionally simple (Pillow only) so it has no heavy native
dependencies; swap ``_estimate_count`` for a detector model to improve accuracy.
"""

from __future__ import annotations

import io
from collections import deque

from app.schemas.desk_cv import PieceCountEstimate
from app.services.toy_service import get_toy_service

try:
    from PIL import Image
except ImportError:  # Pillow is optional at runtime; flow degrades gracefully.
    Image = None  # type: ignore[assignment]

_MAX_DIM = 256
_MIN_BLOB_FRACTION = 0.0008


def estimate_pieces_service(
    toy_id: str,
    image_bytes: bytes,
) -> PieceCountEstimate | None:
    """Return a piece-count estimate for ``toy_id``, or None if the toy is unknown."""
    toy = get_toy_service(toy_id)
    if toy is None:
        return None

    expected = toy.total_pieces
    estimated, confidence = _estimate_count(image_bytes, expected)

    suggested_missing = None
    if expected is not None and estimated is not None:
        suggested_missing = max(0, expected - estimated)

    return PieceCountEstimate(
        toy_id=toy.toy_id,
        expected_total=expected,
        estimated_count=estimated,
        suggested_missing=suggested_missing,
        confidence=confidence,
        message=_message(expected, estimated, suggested_missing),
    )


def _estimate_count(
    image_bytes: bytes,
    expected: int | None,
) -> tuple[int | None, float]:
    if Image is None:
        return None, 0.0
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("L")
    except Exception:
        return None, 0.0

    img.thumbnail((_MAX_DIM, _MAX_DIM))
    width, height = img.size
    pixels = list(img.getdata())
    total = len(pixels)
    if total == 0:
        return None, 0.0

    threshold = _otsu_threshold(pixels)
    below = sum(1 for p in pixels if p <= threshold)
    foreground_is_dark = below <= (total - below)

    mask = bytearray(total)
    for i, p in enumerate(pixels):
        is_dark = p <= threshold
        mask[i] = 1 if (is_dark == foreground_is_dark) else 0

    min_area = max(8, int(total * _MIN_BLOB_FRACTION))
    count = _count_components(mask, width, height, min_area)

    confidence = 0.3
    if expected and count and abs(count - expected) / expected <= 0.25:
        confidence = 0.55
    return count, confidence


def _otsu_threshold(pixels: list[int]) -> int:
    hist = [0] * 256
    for p in pixels:
        hist[p] += 1
    total = len(pixels)
    sum_all = sum(i * hist[i] for i in range(256))

    sum_b = 0.0
    w_b = 0
    max_var = -1.0
    threshold = 127
    for t in range(256):
        w_b += hist[t]
        if w_b == 0:
            continue
        w_f = total - w_b
        if w_f == 0:
            break
        sum_b += t * hist[t]
        mean_b = sum_b / w_b
        mean_f = (sum_all - sum_b) / w_f
        var_between = w_b * w_f * (mean_b - mean_f) ** 2
        if var_between > max_var:
            max_var = var_between
            threshold = t
    return threshold


def _count_components(
    mask: bytearray,
    width: int,
    height: int,
    min_area: int,
) -> int:
    seen = bytearray(len(mask))
    count = 0
    for start in range(len(mask)):
        if not mask[start] or seen[start]:
            continue
        seen[start] = 1
        area = 0
        queue: deque[int] = deque((start,))
        while queue:
            idx = queue.popleft()
            area += 1
            x = idx % width
            y = idx // width
            if x > 0 and mask[idx - 1] and not seen[idx - 1]:
                seen[idx - 1] = 1
                queue.append(idx - 1)
            if x < width - 1 and mask[idx + 1] and not seen[idx + 1]:
                seen[idx + 1] = 1
                queue.append(idx + 1)
            if y > 0 and mask[idx - width] and not seen[idx - width]:
                seen[idx - width] = 1
                queue.append(idx - width)
            if y < height - 1 and mask[idx + width] and not seen[idx + width]:
                seen[idx + width] = 1
                queue.append(idx + width)
        if area >= min_area:
            count += 1
    return count


def _message(
    expected: int | None,
    estimated: int | None,
    suggested_missing: int | None,
) -> str:
    if estimated is None:
        return "Could not analyse the photo. Enter missing pieces manually."
    if expected is None:
        return (
            f"Detected about {estimated} item(s). "
            "No expected count on file - please verify manually."
        )
    if suggested_missing == 0:
        return (
            f"Looks complete: detected ~{estimated} of {expected}. "
            "Please verify before checking in."
        )
    return (
        f"May be short: detected ~{estimated} of {expected}. "
        "Please verify before checking in."
    )
