from __future__ import annotations

from pathlib import Path

import pandas as pd

SCRIPT_DIR = Path(__file__).resolve().parent
INPUT_CSV = SCRIPT_DIR / "toy_photo_map_by_description.csv"
OUTPUT_CSV = SCRIPT_DIR / "toy_seed_canonical.csv"
OUTPUT_JSON = SCRIPT_DIR / "toy_seed_canonical.json"


def to_str(value: object) -> str:
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return ""
    return str(value).strip()


def build_photo_url(filename: str) -> str:
    if not filename:
        return ""
    # Seed-stage URL convention for backend static serving.
    return f"/photos/{filename}"


def main() -> None:
    if not INPUT_CSV.is_file():
        raise FileNotFoundError(f"Missing input file: {INPUT_CSV}")

    df = pd.read_csv(INPUT_CSV)

    out = pd.DataFrame(
        {
            "toy_id": df["toy_id"].map(to_str),
            "name": df["toy_name"].map(to_str),
            "category": df["Category"].map(to_str),
            "age_range": df["Age Range"].map(to_str),
            "status": df["Status"].map(to_str),
            "manufacturer": df["Manufacturer"].map(to_str),
            "description": df["description"].map(to_str),
            "photo_file": df["photo_file_desc"].map(to_str),
        }
    )
    out["photo_url"] = out["photo_file"].map(build_photo_url)

    # Required contract order.
    out = out[
        [
            "toy_id",
            "name",
            "category",
            "age_range",
            "status",
            "manufacturer",
            "description",
            "photo_url",
            "photo_file",
        ]
    ]

    out.to_csv(OUTPUT_CSV, index=False)
    out.to_json(OUTPUT_JSON, orient="records", force_ascii=False, indent=2)

    print(f"Saved: {OUTPUT_CSV}")
    print(f"Saved: {OUTPUT_JSON}")
    print(f"Rows: {len(out)}")
    print(f"Rows with photo_file: {(out['photo_file'] != '').sum()}")


if __name__ == "__main__":
    main()
