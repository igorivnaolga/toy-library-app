# toy-library-app

Clean data workspace for the Toy Library app build.

## Kept files

- `export_imgs/Toys-list.csv` - main toy list (`ID`, name, status, category, age, manufacturer).
- `export_imgs/Toys-categories.csv` - category metadata.
- `export_imgs/Descriptions on items  Church Corner Toy Library (1).csv` - per-toy free-text description.
- `export_imgs/export-imgs.py` - download photos from SETLS (uses `.env` cookies).
- `export_imgs/match-setls-photos-by-description.py` - match downloaded photos to CSV toy IDs by SETLS title + description/name similarity.
- `export_imgs/setls_photo_description_match.csv` - per-photo matching result.
- `export_imgs/toy_photo_map_by_description.csv` - toy-centric mapping table for backend import.
- `export_imgs/.env.example` - cookie variable template.
- `toy_library_photos/` - downloaded source photos.

## Quick workflow

1. Copy `export_imgs/.env.example` to `.env` (repo root or `export_imgs/.env`) and fill:
   - `SETLS_SESSION_COOKIE`
   - `SETLS_REMEMBER_TOKEN`
2. Download photos:
   - `python export_imgs/export-imgs.py`
3. Build mapping from photos to CSV toy IDs:
   - `python export_imgs/match-setls-photos-by-description.py`

Optional:

- `python export_imgs/match-setls-photos-by-description.py --copy-matched`
  - creates `toy_library_photos_matched/` with files renamed to matched `toy_id`.