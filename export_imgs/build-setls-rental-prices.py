"""
Scrape SETLS item pages for rental price and write setls_rental_prices.csv.

Uses toy_id -> setls_internal_id from toy_photo_map_by_description.csv.

  cd export_imgs   # or repo root
  python export_imgs/build-setls-rental-prices.py

Requires export_imgs/.env with SETLS_SESSION_COOKIE and SETLS_REMEMBER_TOKEN
(same as export-imgs.py).
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
PHOTO_MAP_CSV = SCRIPT_DIR / "toy_photo_map_by_description.csv"
OUT_CSV = SCRIPT_DIR / "setls_rental_prices.csv"
BASE_URL = "https://cctoylibrary.setls.co.nz"
REQUEST_DELAY_S = 0.25

RENTAL_RE = re.compile(
    r"Rental\s+price:\s*\$([0-9]+(?:\.[0-9]{1,2})?)",
    re.IGNORECASE,
)


def _load_env_file(path: Path, *, override: bool = False) -> None:
    if not path.is_file():
        return
    with path.open(encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].strip()
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and (override or key not in os.environ):
                os.environ[key] = value


def _make_session() -> requests.Session:
    session_value = os.environ.get("SETLS_SESSION_COOKIE", "").strip()
    remember_token = os.environ.get("SETLS_REMEMBER_TOKEN", "").strip()
    if not session_value or not remember_token:
        print(
            "Missing SETLS cookies. Copy export_imgs/.env.example to export_imgs/.env "
            "and paste SETLS_SESSION_COOKIE / SETLS_REMEMBER_TOKEN.",
            file=sys.stderr,
        )
        sys.exit(1)

    session = requests.Session()
    session.cookies.set("_mymibase_app_session", session_value, domain="cctoylibrary.setls.co.nz")
    session.cookies.set("remember_token", remember_token, domain="cctoylibrary.setls.co.nz")
    session.headers.update(
        {
            "User-Agent": "toy-library-app/setls-rental-prices",
            "Accept": "text/html,application/xhtml+xml",
        }
    )
    return session


def _dollars_to_cents(raw: str) -> int:
    return int(round(float(raw) * 100))


def _parse_rental_price(html: str) -> int | None:
    # SETLS markup splits label and amount across tags, e.g.
    # <strong>Rental price:</strong> $0.50 — so flatten text before matching.
    soup = BeautifulSoup(html, "html.parser")
    page_text = soup.get_text(" ", strip=True)
    match = RENTAL_RE.search(page_text)
    if match:
        return _dollars_to_cents(match.group(1))
    return None


def _load_rows(limit: int | None) -> list[dict[str, str]]:
    if not PHOTO_MAP_CSV.is_file():
        print(f"Missing photo map: {PHOTO_MAP_CSV}", file=sys.stderr)
        sys.exit(1)

    rows: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    with PHOTO_MAP_CSV.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            toy_id = (row.get("toy_id") or "").strip()
            setls_id = (row.get("setls_internal_id") or "").strip()
            if not toy_id or not setls_id or toy_id in seen_ids:
                continue
            seen_ids.add(toy_id)
            rows.append(
                {
                    "toy_id": toy_id,
                    "toy_name": (row.get("toy_name") or "").strip(),
                    "setls_internal_id": setls_id,
                }
            )
            if limit is not None and len(rows) >= limit:
                break
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape SETLS rental prices into CSV.")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Only fetch this many toys (for testing).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-fetch all rows even if OUT CSV already has a price.",
    )
    args = parser.parse_args()

    _load_env_file(REPO_ROOT / ".env")
    _load_env_file(SCRIPT_DIR / ".env", override=True)

    existing: dict[str, int] = {}
    if OUT_CSV.is_file() and not args.force:
        with OUT_CSV.open(encoding="utf-8-sig", newline="") as f:
            for row in csv.DictReader(f):
                toy_id = (row.get("toy_id") or "").strip()
                cents_raw = (row.get("rental_price_cents") or "").strip()
                if toy_id and cents_raw.isdigit():
                    existing[toy_id] = int(cents_raw)

    rows = _load_rows(args.limit)
    session = _make_session()

    results: list[dict[str, str]] = []
    ok = 0
    missing = 0
    errors = 0

    for i, row in enumerate(rows, start=1):
        toy_id = row["toy_id"]
        setls_id = row["setls_internal_id"]
        if not args.force and toy_id in existing:
            results.append(
                {
                    "toy_id": toy_id,
                    "toy_name": row["toy_name"],
                    "setls_internal_id": setls_id,
                    "rental_price_cents": str(existing[toy_id]),
                    "fetch_status": "cached",
                }
            )
            ok += 1
            continue

        url = f"{BASE_URL}/items/{setls_id}"
        try:
            resp = session.get(url, timeout=45)
        except requests.RequestException as exc:
            print(f"[{i}/{len(rows)}] {toy_id} request error: {exc}")
            errors += 1
            results.append(
                {
                    "toy_id": toy_id,
                    "toy_name": row["toy_name"],
                    "setls_internal_id": setls_id,
                    "rental_price_cents": "",
                    "fetch_status": "error",
                }
            )
            time.sleep(REQUEST_DELAY_S)
            continue

        if resp.status_code != 200:
            print(f"[{i}/{len(rows)}] {toy_id} HTTP {resp.status_code} ({url})")
            errors += 1
            results.append(
                {
                    "toy_id": toy_id,
                    "toy_name": row["toy_name"],
                    "setls_internal_id": setls_id,
                    "rental_price_cents": "",
                    "fetch_status": f"http_{resp.status_code}",
                }
            )
            time.sleep(REQUEST_DELAY_S)
            continue

        cents = _parse_rental_price(resp.text)
        if cents is None:
            print(f"[{i}/{len(rows)}] {toy_id} no rental price on page")
            missing += 1
            status = "no_price"
        else:
            ok += 1
            status = "ok"
            print(f"[{i}/{len(rows)}] {toy_id} -> ${cents / 100:.2f}")

        results.append(
            {
                "toy_id": toy_id,
                "toy_name": row["toy_name"],
                "setls_internal_id": setls_id,
                "rental_price_cents": str(cents) if cents is not None else "",
                "fetch_status": status,
            }
        )
        time.sleep(REQUEST_DELAY_S)

    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "toy_id",
                "toy_name",
                "setls_internal_id",
                "rental_price_cents",
                "fetch_status",
            ],
        )
        writer.writeheader()
        writer.writerows(results)

    print(
        f"Wrote {OUT_CSV} ({len(results)} rows: {ok} with price, "
        f"{missing} missing, {errors} errors)."
    )


if __name__ == "__main__":
    main()
