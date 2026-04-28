"""
Map SETLS-downloaded photos (usually named by SETLS *internal* numeric id) to your
CSV *toy_id* (e.g. J108) using fuzzy text match: SETLS page title vs toy name + description.

Workflow:
  1) python export_imgs/export-imgs.py          # download images; filenames = SETLS /items/<id>
  2) python export_imgs/match-setls-photos-by-description.py
  3) Optional: use --copy-matched to write copies named {matched_toy_id}.ext into
     toy_library_photos_matched/ for high-confidence rows only.

Inputs (under export_imgs/):
  - Toys-list.csv          (columns ID, Name, ...)
  - Descriptions*.csv      optional; column "Toy" like "1002: Brainbox ...", "Description"

Outputs:
  - setls_photo_description_match.csv   one row per image file + best CSV toy + score
  - toy_photo_map_by_description.csv    toys from Toys-list + best matching photo file

Requires .env cookies (same as export-imgs / enrich-photo-map).
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import shutil
import sys
import time
from difflib import SequenceMatcher
from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
TOYS_CSV = SCRIPT_DIR / "Toys-list.csv"
PHOTOS_DIR = REPO_ROOT / "toy_library_photos"
OUT_MATCH = SCRIPT_DIR / "setls_photo_description_match.csv"
OUT_MAP = SCRIPT_DIR / "toy_photo_map_by_description.csv"
OUT_COPY_DIR = REPO_ROOT / "toy_library_photos_matched"

# Auto-copy only when best score is at least this (still review collisions manually).
HIGH_CONFIDENCE = 0.78
REQUEST_DELAY_S = 0.2


def norm(s: str) -> str:
    if s is None or (isinstance(s, float) and pd.isna(s)):
        return ""
    s = str(s).lower().strip()
    return re.sub(r"\s+", " ", s)


def score(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, norm(a), norm(b)).ratio()


def load_enrich_module():
    path = SCRIPT_DIR / "enrich-photo-map.py"
    spec = importlib.util.spec_from_file_location("enrich_photo_map", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def infer_photo_id(stem: str) -> str | None:
    stem = stem.strip()
    if not stem:
        return None
    m = re.fullmatch(r"(?i)j(\d+)", stem)
    if m:
        return "J" + m.group(1)
    if stem.isdigit():
        return stem
    m = re.search(r"(\d+)", stem)
    return m.group(1) if m else None


def find_descriptions_csv() -> Path | None:
    for p in SCRIPT_DIR.glob("Descriptions*.csv"):
        return p
    return None


def load_toys_with_descriptions() -> pd.DataFrame:
    if not TOYS_CSV.is_file():
        print(f"Missing {TOYS_CSV} — add Toys-list.csv under export_imgs/.")
        sys.exit(1)
    toys = pd.read_csv(TOYS_CSV)
    toys = toys.rename(columns={"ID": "toy_id", "Name": "toy_name"})
    toys["toy_id"] = toys["toy_id"].astype(str).str.strip()
    toys["toy_name"] = toys["toy_name"].astype(str).str.strip()
    toys["description"] = ""

    desc_path = find_descriptions_csv()
    if desc_path and desc_path.is_file():
        desc = pd.read_csv(desc_path)
        # Expected columns: Toy, Description
        col_toy = [c for c in desc.columns if c.lower().strip() == "toy"]
        col_desc = [c for c in desc.columns if "description" in c.lower()]
        if col_toy and col_desc:
            tcol, dcol = col_toy[0], col_desc[0]
            rows = []
            for _, r in desc.iterrows():
                raw = str(r[tcol]).strip().strip('"')
                m = re.match(r"^([Jj]?\d+)\s*:\s*(.*)$", raw, re.DOTALL)
                if not m:
                    continue
                tid = m.group(1)
                if tid.lower().startswith("j"):
                    tid = "J" + tid[1:].lstrip("j").lstrip("J")
                else:
                    tid = str(int(tid)) if tid.isdigit() else tid
                rows.append(
                    {
                        "toy_id": tid,
                        "long_description": str(r[dcol]).strip(),
                    }
                )
            ddf = pd.DataFrame(rows)
            if len(ddf):
                ddf = ddf.groupby("toy_id", as_index=False).agg(
                    long_description=(
                        "long_description",
                        lambda s: " ".join(s.dropna().astype(str).str.strip()),
                    )
                )
                toys = toys.merge(ddf, on="toy_id", how="left")
                toys["description"] = toys["long_description"].fillna("")
                toys = toys.drop(columns=["long_description"], errors="ignore")
        else:
            print(f"Note: could not find Toy + Description columns in {desc_path.name}, skipping.")
    return toys


def best_csv_toy_for_setls_title(
    setls_title: str, toys: pd.DataFrame
) -> tuple[str, str, float, str]:
    """Return (toy_id, toy_name, best_score, matched_on name|description|both)."""
    best_id, best_name, best_s, reason = "", "", 0.0, ""
    for row in toys.itertuples(index=False):
        tid = str(row.toy_id)
        tname = str(row.toy_name)
        desc = str(getattr(row, "description", "") or "")
        sn = score(setls_title, tname)
        sd = score(setls_title, desc) if desc else 0.0
        s = max(sn, sd)
        if s > best_s:
            best_s = s
            best_id = tid
            best_name = tname
            if sn <= 0 and sd <= 0:
                reason = ""
            elif abs(sn - sd) < 1e-9:
                reason = "both"
            elif sn >= sd:
                reason = "name"
            else:
                reason = "description"
    return best_id, best_name, best_s, reason


def main() -> None:
    parser = argparse.ArgumentParser(description="Match SETLS photos to CSV toys by description.")
    parser.add_argument(
        "--copy-matched",
        action="store_true",
        help=f"Copy high-confidence matches (score>={HIGH_CONFIDENCE}) to {OUT_COPY_DIR.name}/ as {{toy_id}}{{ext}}",
    )
    args = parser.parse_args()

    enrich = load_enrich_module()
    enrich.load_env_candidates()
    session = enrich.make_session()

    probe_raw, probe_parsed, probe_st = enrich.fetch_item_page(session, "10")
    if probe_st == "auth_required":
        print(
            "SETLS returned login wall on /items/10. Update SETLS_SESSION_COOKIE and "
            "SETLS_REMEMBER_TOKEN in .env, then re-run."
        )
        sys.exit(1)

    title_cache: dict[str, tuple[str | None, str | None, str]] = {}
    if probe_st in ("ok", "not_found", "no_title"):
        title_cache["10"] = (probe_raw, probe_parsed, probe_st)

    def get_page(item_id: str) -> tuple[str | None, str | None, str]:
        if item_id in title_cache:
            return title_cache[item_id]
        t = enrich.fetch_item_page(session, item_id)
        title_cache[item_id] = t
        time.sleep(REQUEST_DELAY_S)
        return t

    toys = load_toys_with_descriptions()
    image_ext = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG", ".WEBP"}

    rows = []
    if not PHOTOS_DIR.is_dir():
        print(f"Missing photos folder: {PHOTOS_DIR}")
        sys.exit(1)

    files = sorted(p for p in PHOTOS_DIR.iterdir() if p.is_file() and p.suffix in image_ext)
    print(f"Scanning {len(files)} images in {PHOTOS_DIR} ...")

    for i, path in enumerate(files):
        stem = path.stem.strip()
        setls_item_id = infer_photo_id(stem)
        if not setls_item_id:
            rows.append(
                {
                    "photo_file": path.name,
                    "setls_item_id": "",
                    "setls_h1_raw": "",
                    "setls_title": "",
                    "fetch_status": "bad_filename",
                    "matched_toy_id": "",
                    "matched_toy_name": "",
                    "match_score": 0.0,
                    "matched_on": "",
                }
            )
            continue

        raw, parsed, st = get_page(setls_item_id)
        if st != "ok" or not parsed:
            rows.append(
                {
                    "photo_file": path.name,
                    "setls_item_id": setls_item_id,
                    "setls_h1_raw": raw or "",
                    "setls_title": parsed or "",
                    "fetch_status": st,
                    "matched_toy_id": "",
                    "matched_toy_name": "",
                    "match_score": 0.0,
                    "matched_on": "",
                }
            )
            continue

        mid, mname, ms, mon = best_csv_toy_for_setls_title(parsed, toys)
        id_match = setls_item_id == mid
        rows.append(
            {
                "photo_file": path.name,
                "setls_item_id": setls_item_id,
                "setls_h1_raw": raw or "",
                "setls_title": parsed,
                "fetch_status": st,
                "matched_toy_id": mid,
                "matched_toy_name": mname,
                "match_score": round(ms, 4),
                "matched_on": mon,
                "filename_same_as_csv_id": id_match,
            }
        )
        if i and i % 40 == 0:
            print(f"  ... {i}/{len(files)}")

    match_df = pd.DataFrame(rows)
    match_df.to_csv(OUT_MATCH, index=False)
    print(f"Saved: {OUT_MATCH}")

    # Best photo per CSV toy (highest score wins)
    ok = match_df[match_df["fetch_status"] == "ok"].copy()
    if len(ok):
        ok = ok.sort_values("match_score", ascending=False).drop_duplicates(
            subset=["matched_toy_id"], keep="first"
        )
        ok["photo_path_desc"] = ok["photo_file"].map(lambda f: str(PHOTOS_DIR / f))
        right = ok.rename(
            columns={
                "photo_file": "photo_file_desc",
                "photo_path_desc": "photo_path_desc",
                "match_score": "desc_match_score",
                "setls_item_id": "setls_internal_id",
                "setls_title": "setls_title_for_photo",
            }
        )
        toy_map = toys.merge(
            right,
            left_on="toy_id",
            right_on="matched_toy_id",
            how="left",
        )
        toy_map = toy_map.drop(columns=["matched_toy_id"], errors="ignore")
    else:
        toy_map = toys.copy()
    toy_map.to_csv(OUT_MAP, index=False)
    print(f"Saved: {OUT_MAP}")

    high = match_df[(match_df["fetch_status"] == "ok") & (match_df["match_score"] >= HIGH_CONFIDENCE)]
    print(
        f"High-confidence rows (score>={HIGH_CONFIDENCE}): {len(high)} — review for collisions before trusting copies."
    )

    if args.copy_matched:
        OUT_COPY_DIR.mkdir(parents=True, exist_ok=True)
        used: set[str] = set()
        n = 0
        for _, r in high.iterrows():
            tid = str(r["matched_toy_id"])
            if tid in used:
                continue
            used.add(tid)
            src = PHOTOS_DIR / str(r["photo_file"])
            if not src.is_file():
                continue
            dst = OUT_COPY_DIR / f"{tid}{src.suffix.lower()}"
            shutil.copy2(src, dst)
            n += 1
        print(f"Copied {n} files to {OUT_COPY_DIR}")


if __name__ == "__main__":
    main()
