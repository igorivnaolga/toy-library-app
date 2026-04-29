# toy-library-app

## Project Theme
AI-assisted mobile Toy Library Management System for community libraries, designed to improve catalog access, booking and lending workflows, and inventory control through role-based user journeys and computer-vision-assisted check-in.

## Project Purpose
This diploma project aims to design and implement a mobile-first information system that replaces fragmented manual toy library operations with a centralized digital platform.
The system enables guests, members, and administrators to work with the toy catalog and lending workflows efficiently, while adding AI-assisted inventory verification to reduce check-in errors during toy returns.

## Completed Steps

- Step 1: Backend bootstrap added (`FastAPI` app entrypoint, API router, health endpoint, `requirements.txt`, `.env.example`).
- Step 2: Backend architecture scaffold added (`core`, `db`, `models`, `schemas`, `repositories`, `services`, `scripts`, `tests`).
- Step 3: API endpoint stubs added and wired for `GET /toys`, `GET /toys/{toy_id}`, and `GET /categories`.
- Step 4: Mobile Flutter scaffold added (`mobile/` structure with `core` and feature folders for `catalog`, `auth`, `bookings`, `admin`).
- Step 5: Diploma-oriented project theme and purpose added to `README.md`.

## Next Steps

- Implement real database models and migrations for toys, categories, users, bookings, and loans.
- Implement CSV seed import from `export_imgs/toy_photo_map_by_description.csv`.
- Replace API stubs with real search, filter, and pagination logic.
- Connect Flutter catalog screens to backend API endpoints.

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