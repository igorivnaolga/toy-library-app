import os
import re
import sys
import time
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup

# Directory containing this script; repo root may also hold a .env file.
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.abspath(os.path.join(_SCRIPT_DIR, ".."))


def _load_env_file(path: str, *, override: bool = False) -> None:
    # Parse KEY=value lines from .env without adding python-dotenv.
    if not os.path.isfile(path):
        return
    with open(path, encoding="utf-8") as f:
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


_load_env_file(os.path.join(_REPO_ROOT, ".env"))
_load_env_file(os.path.join(_SCRIPT_DIR, ".env"), override=True)

# --- cookies / login ---
# Values come from an authenticated browser session; store them in .env (see .env.example).
# Do not commit real cookie values to version control.

SESSION_VALUE = os.environ.get("SETLS_SESSION_COOKIE", "").strip()
REMEMBER_TOKEN = os.environ.get("SETLS_REMEMBER_TOKEN", "").strip()

BASE_URL = "https://cctoylibrary.setls.co.nz"
# Primary URL first; second URL used when the first returns an error or no extractable images.
PICTURE_INDEX_URLS = [
    f"{BASE_URL}/items_with_pictures",
    f"{BASE_URL}/toy_picture_index",
]
ITEMS_LIST_URL = f"{BASE_URL}/items"

OUTPUT_FOLDER = "toy_library_photos"
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


def normalize_url(raw_url):
    if not raw_url:
        return None
    if raw_url.startswith("//"):
        return "https:" + raw_url
    if raw_url.startswith("/"):
        return BASE_URL + raw_url
    return raw_url


def get_image_url(img_tag):
    # Lazy-loaded images: URL often appears in data-original instead of src.
    for attr in ("data-original", "data-src", "src"):
        value = img_tag.get(attr)
        if value:
            return normalize_url(value)
    return None


def get_toy_id_from_href(href):
    if not href:
        return None
    match = re.search(r"/items/(\d+)", href)
    return match.group(1) if match else None


def save_image_for_toy(session, toy_id, img_url):
    # Download one image; filename is toy_id plus file extension.
    if not img_url or not toy_id:
        return False

    parsed = urlparse(img_url)
    _, ext = os.path.splitext(parsed.path)
    if not ext:
        ext = ".jpg"

    file_path = os.path.join(OUTPUT_FOLDER, f"{toy_id}{ext}")
    if os.path.exists(file_path):
        print(f"Already exists: {os.path.basename(file_path)}")
        return True

    resp = session.get(img_url, timeout=45)
    if resp.status_code != 200:
        print(f"Failed download for {toy_id} (HTTP {resp.status_code})")
        return False

    with open(file_path, "wb") as f:
        f.write(resp.content)

    print(f"Saved: {os.path.basename(file_path)}")
    return True


def scrape_index_page(session):
    # Walk picture index pages and collect (toy_id, image_url) pairs.
    for url in PICTURE_INDEX_URLS:
        resp = session.get(url, timeout=45)
        print(f"Index URL: {url} -> HTTP {resp.status_code}")
        if resp.status_code != 200:
            continue

        soup = BeautifulSoup(resp.text, "html.parser")
        image_tags = soup.select("img")
        print(f"Found {len(image_tags)} img tags on {url}")

        pairs = []
        for img_tag in image_tags:
            link = img_tag.find_parent("a")
            href = link.get("href", "") if link else ""
            toy_id = get_toy_id_from_href(href)
            img_url = get_image_url(img_tag)
            if toy_id and img_url:
                pairs.append((toy_id, img_url))

        if pairs:
            print(f"Extracted {len(pairs)} toy/image pairs from index page.")
            return pairs

    return []


def scrape_item_pages(session):
    # Slower fallback: request each /items/<id> page when index scraping returns nothing.
    print("Falling back to item page scraping...")
    resp = session.get(ITEMS_LIST_URL, timeout=45)
    if resp.status_code != 200:
        print(f"Cannot load items list page (HTTP {resp.status_code})")
        return []

    soup = BeautifulSoup(resp.text, "html.parser")
    item_links = set()
    for a in soup.select('a[href*="/items/"]'):
        toy_id = get_toy_id_from_href(a.get("href", ""))
        if toy_id:
            item_links.add((toy_id, normalize_url(a.get("href", ""))))

    print(f"Found {len(item_links)} item links in /items page.")
    pairs = []
    for toy_id, item_url in sorted(item_links):
        try:
            item_resp = session.get(item_url, timeout=45)
            if item_resp.status_code != 200:
                continue
            item_soup = BeautifulSoup(item_resp.text, "html.parser")
            img = item_soup.select_one("img")
            if not img:
                continue
            img_url = get_image_url(img)
            if img_url:
                pairs.append((toy_id, img_url))
            time.sleep(0.1)
        except Exception:
            # Ignore individual page errors so the run can continue.
            continue

    print(f"Extracted {len(pairs)} toy/image pairs from item pages.")
    return pairs


def main():
    if not SESSION_VALUE or not REMEMBER_TOKEN:
        print(
            "Missing SETLS_SESSION_COOKIE or SETLS_REMEMBER_TOKEN.\n"
            f"Checked: {_REPO_ROOT}/.env then {_SCRIPT_DIR}/.env\n"
            "Copy export_imgs/.env.example to one of those paths, add values, or set the variables in the shell."
        )
        sys.exit(1)

    session = requests.Session()
    session.cookies.set(
        "_mymibase_app_session", SESSION_VALUE, domain="cctoylibrary.setls.co.nz"
    )
    session.cookies.set(
        "remember_token", REMEMBER_TOKEN, domain="cctoylibrary.setls.co.nz"
    )
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0",
            "Accept": "text/html,application/xhtml+xml",
        }
    )

    print("Loading toy pictures...")
    toy_image_pairs = scrape_index_page(session)
    if not toy_image_pairs:
        toy_image_pairs = scrape_item_pages(session)

    if not toy_image_pairs:
        print("No toy images found. Cookies may be expired; sign in again and update .env.")
        return

    saved = 0
    failed = 0
    seen = set()
    for toy_id, img_url in toy_image_pairs:
        if toy_id in seen:
            continue  # One file per toy_id.
        seen.add(toy_id)
        if save_image_for_toy(session, toy_id, img_url):
            saved += 1
        else:
            failed += 1
        time.sleep(0.15)

    print(f"\nDone! Saved {saved} images, failed {failed}.")


if __name__ == "__main__":
    main()
