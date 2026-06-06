"""Per-toy learning from confirmed check-in photos."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

from sqlalchemy.orm import Session

from app.models.toy import Toy

_SAMPLES_PATH = (
    Path(__file__).resolve().parents[2] / "data" / "toy_cv_samples.jsonl"
)
_EMA_ALPHA = 0.35
_MIN_SAMPLES_FOR_TRUST = 2

try:
    from sklearn.ensemble import RandomForestRegressor
    import numpy as np

    _HAS_SKLEARN = True
except ImportError:
    RandomForestRegressor = None  # type: ignore[misc, assignment]
    np = None  # type: ignore[assignment]
    _HAS_SKLEARN = False

_MODEL_CACHE: dict[str, RandomForestRegressor] = {}


@dataclass(frozen=True)
class PhotoFeatures:
    fg_pixels: int
    peak_count: int
    subdiv_count: int
    fg_ratio: float = 0.0
    blob_count: int = 0
    layout: tuple[float, ...] = ()

    def as_vector(self) -> list[float]:
        peak = max(1, self.peak_count)
        vector = [
            float(self.fg_pixels),
            float(self.peak_count),
            float(self.subdiv_count),
            float(self.fg_pixels) / peak,
            self.fg_ratio,
            float(self.blob_count),
        ]
        vector.extend(self.layout)
        return vector


def effective_piece_count(toy: Toy) -> int | None:
    """Catalog total, or learned count when we have enough samples."""
    if (
        toy.cv_learn_piece_count is not None
        and (toy.cv_learn_samples or 0) >= _MIN_SAMPLES_FOR_TRUST
    ):
        return toy.cv_learn_piece_count
    return toy.total_pieces


def predict_from_baseline(toy: Toy, features: PhotoFeatures) -> int | None:
    if (
        toy.cv_learn_fg_pixels is None
        or toy.cv_learn_piece_count is None
        or toy.cv_learn_fg_pixels <= 0
    ):
        return None
    ratio = features.fg_pixels / toy.cv_learn_fg_pixels
    return max(1, int(round(ratio * toy.cv_learn_piece_count)))


def predict_from_model(toy_id: str, features: PhotoFeatures) -> int | None:
    if not _HAS_SKLEARN:
        return None
    model = _get_or_train_model(toy_id)
    if model is None:
        return None
    pred = float(model.predict([features.as_vector()])[0])
    return max(1, int(round(pred)))


def learn_from_photo(
    session: Session,
    toy_id: str,
    image_bytes: bytes,
    confirmed_piece_count: int,
) -> Toy | None:
    from app.services.desk_cv_service import extract_photo_features

    toy = session.get(Toy, toy_id.strip())
    if toy is None or confirmed_piece_count <= 0:
        return None

    features = extract_photo_features(image_bytes)
    if features is None:
        return None

    samples = toy.cv_learn_samples or 0
    alpha = 1.0 if samples == 0 else _EMA_ALPHA

    if toy.cv_learn_fg_pixels is None:
        toy.cv_learn_fg_pixels = features.fg_pixels
        toy.cv_learn_peak_count = features.peak_count
        toy.cv_learn_piece_count = confirmed_piece_count
    else:
        toy.cv_learn_fg_pixels = _ema(toy.cv_learn_fg_pixels, features.fg_pixels, alpha)
        toy.cv_learn_peak_count = _ema(
            toy.cv_learn_peak_count or features.peak_count,
            features.peak_count,
            alpha,
        )
        toy.cv_learn_piece_count = _ema(
            toy.cv_learn_piece_count or confirmed_piece_count,
            confirmed_piece_count,
            alpha,
        )

    toy.cv_learn_samples = samples + 1
    session.flush()

    from app.services.toy_cv_reference import maybe_update_reference_from_checkin

    maybe_update_reference_from_checkin(
        session,
        toy,
        features,
        confirmed_piece_count,
    )

    _append_sample(toy_id, features, confirmed_piece_count)
    _MODEL_CACHE.pop(toy_id, None)
    return toy


def _ema(previous: int, current: int, alpha: float) -> int:
    return int(round((1 - alpha) * previous + alpha * current))


def _append_sample(toy_id: str, features: PhotoFeatures, label: int) -> None:
    _SAMPLES_PATH.parent.mkdir(parents=True, exist_ok=True)
    row = {
        "toy_id": toy_id,
        "label": label,
        **asdict(features),
        "layout": list(features.layout),
    }
    with _SAMPLES_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row) + "\n")


def _load_samples(toy_id: str) -> tuple[list[list[float]], list[int]]:
    if not _SAMPLES_PATH.is_file():
        return [], []
    xs: list[list[float]] = []
    ys: list[int] = []
    with _SAMPLES_PATH.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            if row.get("toy_id") != toy_id:
                continue
            feat = PhotoFeatures(
                fg_pixels=int(row["fg_pixels"]),
                peak_count=int(row["peak_count"]),
                subdiv_count=int(row["subdiv_count"]),
                fg_ratio=float(row.get("fg_ratio", 0.0)),
                blob_count=int(row.get("blob_count", 0)),
                layout=tuple(float(v) for v in row.get("layout", [])),
            )
            xs.append(feat.as_vector())
            ys.append(int(row["label"]))
    return xs, ys


def _get_or_train_model(toy_id: str) -> RandomForestRegressor | None:
    if not _HAS_SKLEARN:
        return None
    if toy_id in _MODEL_CACHE:
        return _MODEL_CACHE[toy_id]

    xs, ys = _load_samples(toy_id)
    if len(xs) < 5:
        return None

    model = RandomForestRegressor(
        n_estimators=40,
        random_state=0,
        min_samples_leaf=1,
    )
    model.fit(np.array(xs), np.array(ys))
    _MODEL_CACHE[toy_id] = model
    return model


def learn_from_photo_service(
    toy_id: str,
    image_bytes: bytes,
    confirmed_piece_count: int,
) -> tuple[int, int | None] | None:
    """Persist a confirmed count and return (samples, learned_piece_count)."""
    from app.db.session import get_engine, session_scope

    if get_engine() is None:
        return None

    session = session_scope()
    try:
        toy = learn_from_photo(session, toy_id, image_bytes, confirmed_piece_count)
        if toy is None:
            return None
        session.commit()
        return toy.cv_learn_samples, toy.cv_learn_piece_count
    finally:
        session.close()
