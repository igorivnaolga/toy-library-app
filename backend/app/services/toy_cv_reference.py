"""Per-toy reference photo comparison for piece counting."""

from __future__ import annotations

import json
import statistics
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.models.toy import Toy
from app.services.toy_cv_learner import PhotoFeatures
from app.services.toy_photo import read_toy_photo_bytes

_LAYOUT_GRID = 8
_REF_EMA = 0.35
_COMPLETE_TOLERANCE = 1


@dataclass(frozen=True)
class ReferencePrediction:
    estimated: int
    confidence: float
    layout_similarity: float
    source: str


def layout_similarity(
    reference: tuple[float, ...],
    current: tuple[float, ...],
) -> float:
    """Cosine similarity between normalized 8x8 layout signatures."""
    if not reference or not current or len(reference) != len(current):
        return 0.0
    dot = sum(a * b for a, b in zip(reference, current, strict=True))
    ref_norm = sum(a * a for a in reference) ** 0.5
    cur_norm = sum(b * b for b in current) ** 0.5
    if ref_norm <= 0 or cur_norm <= 0:
        return 0.0
    return max(0.0, min(1.0, dot / (ref_norm * cur_norm)))


def parse_layout(raw: str | None) -> tuple[float, ...]:
    if not raw:
        return ()
    try:
        values = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return ()
    if not isinstance(values, list):
        return ()
    return tuple(float(v) for v in values)


def has_reference(toy: Toy | None) -> bool:
    return (
        toy is not None
        and toy.cv_ref_piece_count is not None
        and toy.cv_ref_fg_pixels is not None
        and toy.cv_ref_fg_pixels > 0
    )


def predict_from_reference(
    toy: Toy,
    features: PhotoFeatures,
    expected: int | None,
) -> ReferencePrediction | None:
    """Estimate count by comparing the desk photo to the toy reference."""
    if not has_reference(toy):
        return None

    ref_count = toy.cv_ref_piece_count or 1
    ref_fg = toy.cv_ref_fg_pixels or 1
    ref_peak = max(1, toy.cv_ref_peak_count or 1)
    ref_blob = toy.cv_ref_blob_count or 0
    ref_layout = parse_layout(toy.cv_ref_layout)
    ref_fg_ratio = _reference_fg_ratio(toy)
    source = (toy.cv_ref_source or "setls").lower()

    layout_sim = (
        layout_similarity(ref_layout, features.layout)
        if ref_layout and features.layout
        else 0.0
    )

    ratio_estimates: list[float] = [
        (features.fg_pixels / ref_fg) * ref_count,
        (features.peak_count / ref_peak) * ref_count,
    ]
    if ref_blob > 0 and features.blob_count > 0:
        ratio_estimates.append((features.blob_count / ref_blob) * ref_count)

    estimated = max(1, int(round(statistics.median(ratio_estimates))))
    confidence = _reference_confidence(layout_sim, source)

    if (
        layout_sim >= 0.78
        and ref_fg_ratio is not None
        and abs(features.fg_ratio - ref_fg_ratio) <= 0.12
    ):
        estimated = ref_count
        confidence = 0.9 if source == "checkin" else 0.8
    elif (
        source == "checkin"
        and layout_sim >= 0.45
        and ref_fg_ratio is not None
        and abs(features.fg_ratio - ref_fg_ratio) <= 0.18
    ):
        estimated = ref_count
        confidence = 0.86
    elif layout_sim >= 0.68 and ratio_estimates:
        spread = max(ratio_estimates) - min(ratio_estimates)
        if spread <= max(2.5, ref_count * 0.12):
            estimated = max(1, int(round(statistics.mean(ratio_estimates))))
            confidence = min(0.88, confidence + 0.06)

    if expected is not None:
        estimated = min(estimated, expected)

    return ReferencePrediction(
        estimated=estimated,
        confidence=confidence,
        layout_similarity=layout_sim,
        source=source,
    )


def ensure_catalog_reference(session: Session, toy: Toy) -> bool:
    """Seed a weak reference from the SETLS catalog photo when none exists."""
    if (toy.cv_ref_source or "").lower() == "checkin":
        return False
    if has_reference(toy):
        return False

    photo_bytes = read_toy_photo_bytes(toy.toy_id)
    if photo_bytes is None:
        return False

    from app.services.desk_cv_service import extract_photo_features

    features = extract_photo_features(photo_bytes)
    piece_count = toy.cv_learn_piece_count or toy.total_pieces
    if features is None or not piece_count:
        return False

    _write_reference(session, toy, features, piece_count, "setls", ema=False)
    return True


def ensure_catalog_reference_service(toy_id: str) -> None:
    from app.db.session import get_engine, session_scope

    if get_engine() is None:
        return

    session = session_scope()
    try:
        from app.repositories.toy_repo import resolve_toy_orm

        toy = resolve_toy_orm(session, toy_id)
        if toy is None:
            return
        if ensure_catalog_reference(session, toy):
            session.commit()
    finally:
        session.close()


def is_complete_return(toy: Toy, confirmed_piece_count: int) -> bool:
    """True when the volunteer returned the full catalog set."""
    target = toy.total_pieces
    if target is None or target <= 0:
        return False
    return confirmed_piece_count >= target - _COMPLETE_TOLERANCE


def should_trust_catalog_reference(toy: Toy) -> bool:
    """SETLS photos are often boxed product shots — skip once we have desk learning."""
    if not has_reference(toy):
        return False
    if (toy.cv_ref_source or "").lower() != "setls":
        return True
    return (toy.cv_learn_samples or 0) == 0


def maybe_update_reference_from_checkin(
    session: Session,
    toy: Toy,
    features: PhotoFeatures,
    confirmed_piece_count: int,
    *,
    volunteer_complete: bool = False,
) -> None:
    """Store or refine a check-in reference when the volunteer confirms a full set."""
    if not volunteer_complete and not is_complete_return(toy, confirmed_piece_count):
        return

    current_source = (toy.cv_ref_source or "").lower()
    # Replace a weak SETLS box photo with the first real desk spread.
    ema = current_source == "checkin" and has_reference(toy)
    _write_reference(
        session,
        toy,
        features,
        confirmed_piece_count,
        "checkin",
        ema=ema,
    )


def _reference_fg_ratio(toy: Toy) -> float | None:
    area = toy.cv_ref_image_area
    fg = toy.cv_ref_fg_pixels
    if not area or not fg:
        return None
    return fg / area


def _reference_confidence(layout_sim: float, source: str) -> float:
    if layout_sim >= 0.75:
        base = 0.84 if source == "checkin" else 0.72
    elif layout_sim >= 0.55:
        base = 0.76 if source == "checkin" else 0.64
    elif layout_sim >= 0.4:
        base = 0.66 if source == "checkin" else 0.56
    else:
        base = 0.52 if source == "checkin" else 0.45
    return min(0.9, base + layout_sim * 0.08)


def _write_reference(
    session: Session,
    toy: Toy,
    features: PhotoFeatures,
    piece_count: int,
    source: str,
    *,
    ema: bool,
) -> None:
    alpha = _REF_EMA
    if ema and toy.cv_ref_fg_pixels:
        toy.cv_ref_fg_pixels = _ema_int(toy.cv_ref_fg_pixels, features.fg_pixels, alpha)
        toy.cv_ref_peak_count = _ema_int(
            toy.cv_ref_peak_count or features.peak_count,
            features.peak_count,
            alpha,
        )
        toy.cv_ref_blob_count = _ema_int(
            toy.cv_ref_blob_count or features.blob_count,
            features.blob_count,
            alpha,
        )
        toy.cv_ref_piece_count = _ema_int(
            toy.cv_ref_piece_count or piece_count,
            piece_count,
            alpha,
        )
        toy.cv_ref_layout = json.dumps(
            list(_ema_layout(parse_layout(toy.cv_ref_layout), features.layout, alpha))
        )
    else:
        toy.cv_ref_fg_pixels = features.fg_pixels
        toy.cv_ref_peak_count = features.peak_count
        toy.cv_ref_blob_count = features.blob_count
        toy.cv_ref_piece_count = piece_count
        toy.cv_ref_layout = json.dumps(list(features.layout))

    toy.cv_ref_image_area = _image_area_from_fg_ratio(features)
    toy.cv_ref_source = source
    session.flush()


def _image_area_from_fg_ratio(features: PhotoFeatures) -> int:
    if features.fg_ratio <= 0:
        return features.fg_pixels
    return max(1, int(round(features.fg_pixels / features.fg_ratio)))


def _ema_int(previous: int, current: int, alpha: float) -> int:
    return int(round((1 - alpha) * previous + alpha * current))


def _ema_layout(
    previous: tuple[float, ...],
    current: tuple[float, ...],
    alpha: float,
) -> tuple[float, ...]:
    if not previous or len(previous) != len(current):
        return current
    merged = [
        (1 - alpha) * a + alpha * b for a, b in zip(previous, current, strict=True)
    ]
    total = sum(merged) or 1.0
    return tuple(value / total for value in merged)
