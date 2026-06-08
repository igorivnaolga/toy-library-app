"""Advisory piece-count estimate from a returned-toy photo.

Uses OpenCV distance-transform peak counting with subdivision inside large
blobs (e.g. pieces still in a tray). Works best when pieces are spread on a
plain contrasting background.
"""

from __future__ import annotations

import hashlib
import io
import statistics
from collections import Counter, deque

from app.schemas.desk_cv import PieceCountEstimate
from app.services.toy_service import get_toy_service

try:
    import cv2
    import numpy as np

    _HAS_CV2 = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    np = None  # type: ignore[assignment]
    _HAS_CV2 = False

try:
    from PIL import Image
except ImportError:
    Image = None  # type: ignore[assignment]

_MAX_DIM = 900
_MIN_BLOB_FRACTION = 0.0002
_LAYOUT_GRID = 8
_MIN_BLOB_AREA = 40
_NMS_RADIUS_FACTORS = (0.22, 0.30, 0.38, 0.46, 0.54)
_RESULT_CACHE: dict[str, tuple[int | None, float]] = {}
_RESULT_CACHE_MAX = 48


def _load_toy_orm(toy_id: str):
    from app.db.session import get_engine, session_scope
    from app.repositories.toy_repo import resolve_toy_orm

    if get_engine() is None:
        return None
    session = session_scope()
    try:
        return resolve_toy_orm(session, toy_id)
    finally:
        session.close()


def extract_photo_features(image_bytes: bytes, expected: int | None = None):
    """Image features used for per-toy learning and reference comparison."""
    if not _HAS_CV2:
        return None

    bgr = _decode_bgr(image_bytes)
    if bgr is None:
        return None

    return _pick_best_photo_features(bgr, expected)


def extract_photo_features_for_learn(
    image_bytes: bytes,
    confirmed_piece_count: int,
):
    """Features for training — always returns something for a valid image."""
    if not image_bytes:
        return None

    features = extract_photo_features(image_bytes, confirmed_piece_count)
    if features is not None:
        return features

    if _HAS_CV2:
        bgr = _decode_bgr(image_bytes)
        if bgr is not None:
            fallback = _fallback_photo_features(bgr, confirmed_piece_count)
            if fallback is not None:
                return fallback
            return _minimal_learn_features(bgr, confirmed_piece_count)

    return _minimal_learn_features_pillow(image_bytes, confirmed_piece_count)


def extract_photo_features_for_learn_fast(
    image_bytes: bytes,
    confirmed_piece_count: int,
):
    """Fast path for check-in learning — trusts the volunteer's confirmed count."""
    if not image_bytes:
        return None
    if _HAS_CV2:
        bgr = _decode_bgr(image_bytes)
        if bgr is not None:
            return _minimal_learn_features(bgr, confirmed_piece_count)
    return _minimal_learn_features_pillow(image_bytes, confirmed_piece_count)


def _pick_best_photo_features(bgr: np.ndarray, expected: int | None = None):
    from app.services.toy_cv_learner import PhotoFeatures

    assert np is not None
    image_area = bgr.shape[0] * bgr.shape[1]
    best: PhotoFeatures | None = None
    best_peak = 0
    for mask in _generate_masks(bgr):
        features = _features_from_mask(mask, image_area, expected)
        if features is not None and features.peak_count > best_peak:
            best_peak = features.peak_count
            best = features
    return best


def _fallback_photo_features(bgr: np.ndarray, confirmed_piece_count: int):
    """Use foreground + layout when peak counts are unreliable (e.g. jigsaws)."""
    from app.services.toy_cv_learner import PhotoFeatures

    assert np is not None
    image_area = bgr.shape[0] * bgr.shape[1]
    best_fg = 0
    best_mask: np.ndarray | None = None
    for mask in _generate_masks(bgr):
        fg_pixels = int(np.count_nonzero(mask))
        if fg_pixels > best_fg:
            best_fg = fg_pixels
            best_mask = mask

    if best_mask is None or best_fg < 30:
        return None

    return PhotoFeatures(
        fg_pixels=best_fg,
        peak_count=max(1, confirmed_piece_count),
        subdiv_count=0,
        fg_ratio=best_fg / max(1, image_area),
        blob_count=_blob_count(best_mask),
        layout=_layout_signature(best_mask),
    )


def _minimal_learn_features(bgr: np.ndarray, confirmed_piece_count: int):
    """Last-resort desk baseline from any decodable check-in photo."""
    from app.services.toy_cv_learner import PhotoFeatures

    assert np is not None
    height, width = bgr.shape[:2]
    image_area = max(1, height * width)
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    fg_pixels = int(np.count_nonzero(mask))
    if fg_pixels < 30:
        fg_pixels = max(100, image_area // 8)
        layout = tuple([1 / 64] * 64)
        blob_count = 1
    else:
        layout = _layout_signature(mask)
        blob_count = max(1, _blob_count(mask))

    return PhotoFeatures(
        fg_pixels=fg_pixels,
        peak_count=max(1, confirmed_piece_count),
        subdiv_count=0,
        fg_ratio=fg_pixels / image_area,
        blob_count=blob_count,
        layout=layout,
    )


def _minimal_learn_features_pillow(image_bytes: bytes, confirmed_piece_count: int):
    """Pillow-only baseline when OpenCV cannot decode the upload."""
    from app.services.toy_cv_learner import PhotoFeatures

    if Image is None:
        return None
    try:
        img = Image.open(io.BytesIO(image_bytes))
        width, height = img.size
    except Exception:
        return None
    if width <= 0 or height <= 0:
        return None

    image_area = width * height
    fg_pixels = max(100, image_area // 6)
    return PhotoFeatures(
        fg_pixels=fg_pixels,
        peak_count=max(1, confirmed_piece_count),
        subdiv_count=0,
        fg_ratio=fg_pixels / image_area,
        blob_count=1,
        layout=tuple([1 / 64] * 64),
    )


def _features_from_mask(
    mask: np.ndarray,
    image_area: int,
    expected: int | None,
):
    from app.services.toy_cv_learner import PhotoFeatures

    assert np is not None
    fg_pixels = int(np.count_nonzero(mask))
    if fg_pixels < 80:
        return None
    counts = _count_from_mask(mask, expected)
    if not counts:
        return None
    peak = max(counts)
    subdiv = counts[-1]
    return PhotoFeatures(
        fg_pixels=fg_pixels,
        peak_count=peak,
        subdiv_count=subdiv,
        fg_ratio=fg_pixels / max(1, image_area),
        blob_count=_blob_count(mask),
        layout=_layout_signature(mask),
    )


def _blob_count(mask: np.ndarray) -> int:
    assert cv2 is not None
    num_labels, _labels, stats, _centroids = cv2.connectedComponentsWithStats(
        mask, connectivity=8
    )
    count = 0
    for label in range(1, num_labels):
        if stats[label, cv2.CC_STAT_AREA] >= _MIN_BLOB_AREA:
            count += 1
    return count


def _layout_signature(mask: np.ndarray) -> tuple[float, ...]:
    assert np is not None
    height, width = mask.shape[:2]
    cell_h = max(1, height // _LAYOUT_GRID)
    cell_w = max(1, width // _LAYOUT_GRID)
    cells: list[float] = []
    for row in range(_LAYOUT_GRID):
        for col in range(_LAYOUT_GRID):
            y0 = row * cell_h
            y1 = height if row == _LAYOUT_GRID - 1 else (row + 1) * cell_h
            x0 = col * cell_w
            x1 = width if col == _LAYOUT_GRID - 1 else (col + 1) * cell_w
            patch = mask[y0:y1, x0:x1]
            cells.append(float(np.count_nonzero(patch)) / max(1, patch.size))
    total = sum(cells) or 1.0
    return tuple(value / total for value in cells)


def _decode_bgr(image_bytes: bytes):
    assert cv2 is not None and np is not None
    cv2.setNumThreads(1)
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        return None

    h, w = bgr.shape[:2]
    max_side = max(h, w)
    if max_side > _MAX_DIM:
        scale = _MAX_DIM / max_side
        new_w = max(1, int(w * scale))
        new_h = max(1, int(h * scale))
        bgr = cv2.resize(bgr, (new_w, new_h), interpolation=cv2.INTER_AREA)
    return bgr


def _reference_compare_features(bgr: np.ndarray, piece_hint: int):
    """Same lightweight fingerprint used when saving a desk check-in reference."""
    return _minimal_learn_features(bgr, max(1, piece_hint))


def _estimate_from_checkin_reference(
    toy_orm,
    bgr: np.ndarray,
    expected: int | None,
) -> tuple[int, float, float] | None:
    """Fast desk estimate using the saved check-in photo (no heavy peak CV)."""
    from app.services.toy_cv_reference import has_reference, predict_from_reference

    if toy_orm is None or not has_reference(toy_orm):
        return None
    if (toy_orm.cv_ref_source or "").lower() != "checkin":
        return None

    ref_count = toy_orm.cv_ref_piece_count or expected
    ref_fg = toy_orm.cv_ref_fg_pixels or 0
    if not ref_count or ref_fg <= 0:
        return None

    piece_hint = max(1, expected or ref_count)
    features = _reference_compare_features(bgr, piece_hint)
    if features is None:
        return None

    ref_pred = predict_from_reference(toy_orm, features, expected)
    layout_sim = ref_pred.layout_similarity if ref_pred else 0.0
    learn_samples = toy_orm.cv_learn_samples or 0
    fg_delta = abs(features.fg_pixels - ref_fg) / ref_fg

    def _full_set(confidence: float) -> tuple[int, float, float]:
        target = min(ref_count, expected) if expected else ref_count
        return target, confidence, layout_sim

    # Volunteer saved a confirmed full-set desk photo — trust unless tray is nearly empty.
    if learn_samples >= 1 and features.fg_pixels >= ref_fg * 0.18:
        return _full_set(0.9)

    if layout_sim >= 0.5:
        return _full_set(0.88)

    if ref_pred is not None and layout_sim >= 0.3:
        estimated, confidence, _ = _snap_near_complete(
            ref_pred.estimated, expected, ref_pred.confidence
        )
        if estimated is not None:
            return estimated, confidence, layout_sim

    if fg_delta <= 0.4:
        ratio_est = max(1, int(round((features.fg_pixels / ref_fg) * ref_count)))
        if expected is not None:
            ratio_est = min(ratio_est, expected)
        estimated, confidence, _ = _snap_near_complete(ratio_est, expected, 0.78)
        if estimated is not None:
            return estimated, confidence, layout_sim

    return None


def estimate_pieces_service(
    toy_id: str,
    image_bytes: bytes,
) -> PieceCountEstimate | None:
    """Return a piece-count estimate for ``toy_id``, or None if the toy is unknown."""
    from app.services.toy_cv_learner import (
        effective_piece_count,
        predict_from_baseline,
        predict_from_model,
    )
    from app.services.toy_cv_reference import (
        ensure_catalog_reference_service,
        has_reference,
        predict_from_reference,
        should_trust_catalog_reference,
    )

    toy_orm = _load_toy_orm(toy_id)
    if toy_orm is None:
        toy = get_toy_service(toy_id)
        if toy is None:
            return None
        catalog_expected = toy.total_pieces
        canonical_id = toy.toy_id
    else:
        catalog_expected = toy_orm.total_pieces
        canonical_id = toy_orm.toy_id

    has_checkin_ref = (
        toy_orm is not None
        and has_reference(toy_orm)
        and (toy_orm.cv_ref_source or "").lower() == "checkin"
    )
    if toy_orm is not None and not has_checkin_ref:
        ensure_catalog_reference_service(toy_id)
        toy_orm = _load_toy_orm(toy_id)

    expected = effective_piece_count(toy_orm) if toy_orm else catalog_expected
    learn_samples = (toy_orm.cv_learn_samples or 0) if toy_orm else 0
    learned_total = (
        toy_orm.cv_learn_piece_count
        if toy_orm and learn_samples >= 2
        else None
    )
    used_learned = False
    used_reference = False
    reference_source = toy_orm.cv_ref_source if toy_orm else None
    layout_similarity: float | None = None

    ref_key = (
        f"{toy_orm.cv_ref_fg_pixels}:{toy_orm.cv_ref_source}"
        if toy_orm and has_reference(toy_orm)
        else "none"
    )
    cache_key = (
        f"{canonical_id}:"
        f"{expected}:"
        f"{learn_samples}:"
        f"{ref_key}:"
        f"{hashlib.sha256(image_bytes).hexdigest()}:v12"
    )
    cached = _RESULT_CACHE.get(cache_key)

    if cached is not None:
        estimated, confidence = cached
    else:
        bgr = _decode_bgr(image_bytes) if _HAS_CV2 else None
        checkin_est = (
            _estimate_from_checkin_reference(toy_orm, bgr, expected)
            if bgr is not None
            else None
        )
        if checkin_est is not None:
            estimated, confidence, layout_similarity = checkin_est
            used_reference = True
            reference_source = "checkin"
        else:
            cv_est, cv_conf = (
                _estimate_count_light(bgr, expected)
                if bgr is not None
                else (None, 0.0)
            )
            if cv_est is None:
                cv_est, cv_conf = _estimate_count(image_bytes, expected, bgr=bgr)

            features = None
            ref_pred = None
            baseline_est = None
            if bgr is not None and not has_checkin_ref:
                features = _pick_best_photo_features(bgr, expected)
                if toy_orm and features and has_reference(toy_orm):
                    if should_trust_catalog_reference(toy_orm):
                        ref_pred = predict_from_reference(toy_orm, features, expected)
                baseline_est = (
                    predict_from_baseline(toy_orm, features)
                    if toy_orm and features
                    else None
                )
            model_est = (
                predict_from_model(canonical_id, features) if features else None
            )

            if (
                ref_pred is not None
                and ref_pred.source == "setls"
                and learn_samples == 0
                and ref_pred.layout_similarity >= 0.55
            ):
                estimated = ref_pred.estimated
                confidence = ref_pred.confidence
                used_reference = True
                reference_source = ref_pred.source
                layout_similarity = ref_pred.layout_similarity
            elif learn_samples >= 2 and baseline_est is not None:
                estimated = baseline_est
                confidence = 0.86
                used_learned = True
            elif learn_samples >= 5 and model_est is not None:
                estimated = model_est
                confidence = 0.86
                used_learned = True
            elif learn_samples >= 1 and baseline_est is not None:
                estimated = max(baseline_est, cv_est or 0)
                if expected is not None:
                    estimated = min(estimated, expected)
                confidence = max(cv_conf, 0.8)
                used_learned = True
            elif baseline_est is not None and cv_est is not None:
                estimated = max(baseline_est, cv_est)
                if expected is not None:
                    estimated = min(estimated, expected)
                confidence = max(cv_conf, 0.72)
                used_learned = learn_samples >= 1
            else:
                estimated, confidence = cv_est, cv_conf

            if estimated is None:
                estimated, confidence = _recover_estimate(
                    image_bytes,
                    expected,
                    baseline_est=baseline_est,
                    ref_pred=ref_pred,
                    features=features,
                    cv_conf=cv_conf,
                )

            estimated, confidence, _ = _snap_near_complete(
                estimated, expected, confidence
            )

        if len(_RESULT_CACHE) >= _RESULT_CACHE_MAX:
            _RESULT_CACHE.pop(next(iter(_RESULT_CACHE)))
        _RESULT_CACHE[cache_key] = (estimated, confidence)

    estimated, confidence, was_snapped = _snap_near_complete(
        estimated, expected, confidence
    )

    suggested_missing = None
    if expected is not None and estimated is not None:
        suggested_missing = max(0, expected - estimated)

    return PieceCountEstimate(
        toy_id=canonical_id,
        expected_total=expected,
        estimated_count=estimated,
        suggested_missing=suggested_missing,
        confidence=confidence,
        message=_message(
            expected,
            estimated,
            suggested_missing,
            confidence,
            was_snapped=was_snapped,
            learn_samples=learn_samples,
            used_learned=used_learned,
            used_reference=used_reference,
            reference_source=reference_source,
            layout_similarity=layout_similarity,
        ),
        catalog_total=catalog_expected,
        learned_total=learned_total,
        learn_samples=learn_samples,
        reference_source=reference_source,
        layout_similarity=layout_similarity,
    )


def _recover_estimate(
    image_bytes: bytes,
    expected: int | None,
    *,
    baseline_est: int | None,
    ref_pred,
    features,
    cv_conf: float,
) -> tuple[int | None, float]:
    """Fallbacks when peak counting returns nothing."""
    if baseline_est is not None:
        return baseline_est, max(0.68, cv_conf)
    if ref_pred is not None:
        return ref_pred.estimated, min(0.82, ref_pred.confidence * 0.9)
    if features is not None:
        est = max(1, features.peak_count)
        if expected is not None:
            est = min(est, expected)
        return est, 0.58
    learn_feat = extract_photo_features_for_learn(image_bytes, expected or 1)
    if learn_feat is not None:
        est = max(1, learn_feat.peak_count)
        if expected is not None:
            est = min(est, expected)
        return est, 0.52
    return None, 0.0


def _snap_near_complete(
    estimated: int | None,
    expected: int | None,
    confidence: float,
) -> tuple[int | None, float, bool]:
    """Photo counting often undercounts by 1–2 when pieces touch — treat as complete."""
    if expected is None or estimated is None or expected <= 1:
        return estimated, confidence, False

    gap = expected - estimated
    if gap <= 0:
        return estimated, confidence, False

    max_gap = max(3, int(round(expected * 0.15)))
    if gap <= max_gap:
        return expected, min(0.88, max(confidence, 0.74)), True
    return estimated, confidence, False


def _estimate_count(
    image_bytes: bytes,
    expected: int | None,
    *,
    bgr: np.ndarray | None = None,
) -> tuple[int | None, float]:
    if _HAS_CV2:
        if bgr is None:
            bgr = _decode_bgr(image_bytes)
        if bgr is not None:
            light = _estimate_count_light(bgr, expected)
            if light[0] is not None:
                return light
    return _estimate_count_pillow(image_bytes, expected)


def _estimate_count_light(
    bgr: np.ndarray,
    expected: int | None,
) -> tuple[int | None, float]:
    """Single-mask peak count — fast default for toys without a desk reference."""
    assert cv2 is not None and np is not None
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    all_counts: list[int] = []
    for invert in (False, True):
        flag = cv2.THRESH_BINARY_INV if invert else cv2.THRESH_BINARY
        _, mask = cv2.threshold(blur, 0, 255, flag + cv2.THRESH_OTSU)
        all_counts.extend(_count_from_mask(_refine_mask(mask), expected))

    if not all_counts:
        return None, 0.0

    spread = max(all_counts) - min(all_counts)
    estimated = _optimistic_aggregate(all_counts, expected)
    estimated, snap_confidence = _refine_near_complete(
        estimated, expected, all_counts, spread
    )
    agreement = all_counts.count(estimated) / len(all_counts)
    confidence = _confidence(estimated, expected, spread, len(all_counts))
    confidence = min(0.88, confidence * (0.55 + 0.45 * agreement))
    if snap_confidence > 0:
        confidence = min(0.88, max(confidence, snap_confidence))
    return estimated, confidence


def _stable_aggregate(counts: list[int], expected: int | None = None) -> int:
    """Pick the most repeated count; ties resolve to the middle value."""
    tally = Counter(counts)
    top_freq = max(tally.values())
    modes = sorted(value for value, freq in tally.items() if freq == top_freq)
    if len(modes) == 1:
        result = modes[0]
    else:
        result = int(round(statistics.median(modes)))

    if (
        expected
        and result == expected - 1
        and counts.count(expected) >= max(2, len(counts) // 6)
    ):
        return expected
    return result


def _optimistic_aggregate(counts: list[int], expected: int | None) -> int:
    """Bias toward the upper range — photo CV tends to undercount."""
    if not counts:
        return 0

    mode_est = _stable_aggregate(counts, expected)
    sorted_counts = sorted(counts)
    upper_idx = min(len(sorted_counts) - 1, int(len(sorted_counts) * 0.8))
    upper_est = sorted_counts[upper_idx]
    peak_est = max(sorted_counts)

    estimated = max(mode_est, upper_est)
    if expected:
        if peak_est >= expected - 2:
            estimated = max(estimated, peak_est)
        estimated = min(estimated, expected)
    else:
        estimated = min(estimated, peak_est)

    return estimated


def _refine_near_complete(
    estimated: int,
    expected: int | None,
    all_counts: list[int],
    spread: int,
) -> tuple[int, float]:
    """When close to complete, snap to the catalog total."""
    if not expected or expected <= 1:
        return estimated, 0.0

    gap = expected - estimated
    if gap <= 0:
        return estimated, 0.0

    max_gap = max(3, int(round(expected * 0.15)))
    if gap > max_gap:
        return estimated, 0.0

    total = len(all_counts)
    near_complete = sum(1 for value in all_counts if value >= expected - 2)
    saw_complete = sum(1 for value in all_counts if value >= expected)

    if max(all_counts) >= expected - 1:
        return expected, 0.86
    if near_complete / total >= 0.35 and spread <= 12:
        return expected, 0.82
    if saw_complete >= 1:
        return expected, 0.8
    if gap <= 2:
        return expected, 0.76
    return estimated, 0.0


def _generate_masks(bgr: np.ndarray) -> list[np.ndarray]:
    assert cv2 is not None and np is not None
    masks: list[np.ndarray] = []
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    sat = hsv[:, :, 1]

    for invert in (False, True):
        _, otsu = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        if invert:
            otsu = cv2.bitwise_not(otsu)
        masks.append(_refine_mask(otsu))

    adaptive = cv2.adaptiveThreshold(
        blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 31, 5
    )
    masks.append(_refine_mask(adaptive))
    masks.append(_refine_mask(cv2.bitwise_not(adaptive)))

    _, sat_mask = cv2.threshold(sat, 25, 255, cv2.THRESH_BINARY)
    masks.append(_refine_mask(sat_mask))

    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    _, a_ch, b_ch = cv2.split(lab)
    color_var = cv2.add(
        cv2.absdiff(a_ch, cv2.GaussianBlur(a_ch, (31, 31), 0)),
        cv2.absdiff(b_ch, cv2.GaussianBlur(b_ch, (31, 31), 0)),
    )
    _, color_mask = cv2.threshold(color_var, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    masks.append(_refine_mask(color_mask))

    return masks


def _refine_mask(mask: np.ndarray) -> np.ndarray:
    assert cv2 is not None
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    return mask


def _count_from_mask(mask: np.ndarray, expected: int | None) -> list[int]:
    assert cv2 is not None and np is not None
    fg_pixels = int(np.count_nonzero(mask))
    if fg_pixels < 80:
        return []

    avg_area = fg_pixels / expected if expected and expected > 0 else fg_pixels / 16
    piece_radius = max(2.0, (avg_area / 3.14159) ** 0.5)

    counts: list[int] = []
    dist = cv2.distanceTransform(mask, cv2.DIST_L2, 5)
    max_peaks = (expected or 60) + 15

    for factor in _NMS_RADIUS_FACTORS:
        radius = max(2, int(piece_radius * factor))
        nms = _nms_peak_count(dist, radius, max_peaks=max_peaks)
        if nms > 0:
            counts.append(nms)

    subdivided = _count_by_subdivision(mask, avg_area, piece_radius, max_peaks)
    if subdivided > 0:
        counts.append(subdivided)

    return counts


def _nms_peak_count(
    dist: np.ndarray,
    min_radius: int,
    *,
    max_peaks: int,
) -> int:
    assert cv2 is not None
    work = dist.copy()
    floor = max(1.0, min_radius * 0.28)
    count = 0
    for _ in range(max_peaks):
        _min_val, max_val, _min_loc, max_loc = cv2.minMaxLoc(work)
        if max_val < floor:
            break
        count += 1
        cv2.circle(work, max_loc, int(min_radius), 0, -1)
    return count


def _count_by_subdivision(
    mask: np.ndarray,
    avg_area: float,
    piece_radius: float,
    max_peaks: int,
) -> int:
    """Count inside each foreground blob; subdivide trays/large clusters."""
    assert cv2 is not None and np is not None
    num_labels, _labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if num_labels <= 1:
        return 0

    total = 0
    single_piece_max = avg_area * 2.8
    for label in range(1, num_labels):
        area = stats[label, cv2.CC_STAT_AREA]
        if area < avg_area * 0.12:
            continue

        x = stats[label, cv2.CC_STAT_LEFT]
        y = stats[label, cv2.CC_STAT_TOP]
        w = stats[label, cv2.CC_STAT_WIDTH]
        h = stats[label, cv2.CC_STAT_HEIGHT]
        roi = mask[y : y + h, x : x + w]

        if area <= single_piece_max:
            total += 1
            continue

        est_in_blob = max(2, int(round(area / avg_area)))
        dist = cv2.distanceTransform(roi, cv2.DIST_L2, 5)
        blob_counts: list[int] = []
        for factor in (0.16, 0.24, 0.34, 0.44):
            radius = max(2, int(piece_radius * factor))
            blob_counts.append(
                _nms_peak_count(dist, radius, max_peaks=est_in_blob + 8)
            )
        if blob_counts:
            total += int(round(statistics.median(blob_counts)))

    return total


def _estimate_count_pillow(
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
    min_area = max(6, int(total * _MIN_BLOB_FRACTION))
    candidates: list[int] = []
    for foreground_is_dark in (True, False):
        mask = _build_mask(pixels, threshold, foreground_is_dark)
        for erode_passes in range(4):
            work = mask
            for _ in range(erode_passes):
                work = _erode(work, width, height)
            areas = _component_areas(work, width, height, min_area)
            filtered = _filter_piece_areas(areas, expected)
            if filtered:
                candidates.append(len(filtered))

    if not candidates:
        return None, 0.0

    estimated = _stable_aggregate(candidates, expected)
    spread = max(candidates) - min(candidates)
    confidence = _confidence(estimated, expected, spread, len(candidates)) * 0.65
    return estimated, confidence


def _build_mask(
    pixels: list[int],
    threshold: int,
    foreground_is_dark: bool,
) -> bytearray:
    mask = bytearray(len(pixels))
    for i, p in enumerate(pixels):
        is_dark = p <= threshold
        mask[i] = 1 if (is_dark == foreground_is_dark) else 0
    return mask


def _erode(mask: bytearray, width: int, height: int) -> bytearray:
    out = bytearray(len(mask))
    for idx in range(len(mask)):
        if not mask[idx]:
            continue
        x = idx % width
        y = idx // width
        if (
            x > 0
            and mask[idx - 1]
            and x < width - 1
            and mask[idx + 1]
            and y > 0
            and mask[idx - width]
            and y < height - 1
            and mask[idx + width]
        ):
            out[idx] = 1
    return out


def _component_areas(
    mask: bytearray,
    width: int,
    height: int,
    min_area: int,
) -> list[int]:
    seen = bytearray(len(mask))
    areas: list[int] = []
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
            areas.append(area)
    return areas


def _filter_piece_areas(
    areas: list[int],
    expected: int | None,
) -> list[int]:
    if not areas:
        return []
    median = statistics.median(areas)
    if median <= 0:
        return areas

    lo = median * 0.2
    hi = median * 5.0
    filtered = [a for a in areas if lo <= a <= hi]
    if len(filtered) >= 2:
        largest = max(filtered)
        if largest > median * 6:
            filtered = [a for a in filtered if a < largest]
    if expected and expected > 0 and len(filtered) > expected * 2:
        filtered = sorted(filtered)[: expected * 2]
    return filtered


def _confidence(
    estimated: int,
    expected: int | None,
    spread: int,
    method_count: int,
) -> float:
    score = 0.25
    if method_count >= 4:
        score += 0.1
    if spread <= 2:
        score += 0.25
    elif spread <= 4:
        score += 0.15
    elif spread <= 7:
        score += 0.05
    elif spread > 12:
        score -= 0.2
    if expected and expected > 0:
        ratio_error = abs(estimated - expected) / expected
        if ratio_error <= 0.05:
            score += 0.25
        elif ratio_error <= 0.12:
            score += 0.15
        elif ratio_error <= 0.2:
            score += 0.05
        else:
            score -= min(0.3, ratio_error * 0.5)
    return max(0.08, min(0.88, score))


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


def _message(
    expected: int | None,
    estimated: int | None,
    suggested_missing: int | None,
    confidence: float,
    *,
    was_snapped: bool = False,
    learn_samples: int = 0,
    used_learned: bool = False,
    used_reference: bool = False,
    reference_source: str | None = None,
    layout_similarity: float | None = None,
) -> str:
    if estimated is None:
        return "Could not analyse the photo. Adjust the count manually."
    conf_pct = round(confidence * 100)
    learn_hint = (
        " Check in with +/− once — the app learns this toy for next time."
        if learn_samples == 0 and suggested_missing and suggested_missing > 0
        else ""
    )
    learned_note = " (learned from past check-ins)" if used_learned else ""
    if used_reference and reference_source:
        sim_pct = (
            int(round(layout_similarity * 100))
            if layout_similarity is not None
            else None
        )
        source_label = (
            "your last complete check-in"
            if reference_source == "checkin"
            else "catalog photo"
        )
        ref_note = f" Compared to {source_label}"
        if sim_pct is not None:
            ref_note += f" ({sim_pct}% layout match)"
        ref_note += "."
        learned_note = ref_note
    if expected is None:
        return (
            f"Detected about {estimated} item(s) ({conf_pct}% sure). "
            "Adjust if needed."
        )
    if suggested_missing == 0:
        if was_snapped:
            return (
                f"Looks complete: all {expected} pieces ({conf_pct}% sure). "
                "Photo undercount adjusted — use +/− if needed."
                f"{learned_note}"
            )
        return (
            f"Detected ~{estimated} of {expected} ({conf_pct}% sure). "
            f"Looks complete — adjust if needed.{learned_note}"
        )
    return (
        f"Detected ~{estimated} of {expected} "
        f"({suggested_missing} possibly missing, {conf_pct}% sure). "
        "Spread pieces out of the tray if they look merged. Adjust with +/−."
        f"{learn_hint}"
    )
