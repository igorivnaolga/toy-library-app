from pathlib import Path


def main() -> None:
    csv_path = Path(__file__).resolve().parents[3] / "export_imgs" / "toy_photo_map_by_description.csv"
    print(f"Seed placeholder. Source: {csv_path}")


if __name__ == "__main__":
    main()
