#!/usr/bin/env python3
"""
Scrapes airport viewing park / spotting locations from spotterguide.net.
Extracts coordinates from embedded Google My Maps KML exports.

Output: tools/viewing_parks.json
  {
    "EDDM": {
      "name": "Munich Franz Josef Strauss",
      "url": "https://www.spotterguide.net/planespotting/.../",
      "spots": [
        {"name": "Visitors Hill", "lat": 48.362, "lon": 11.788},
        {"name": "Spot 2", "lat": 48.361, "lon": 11.790}
      ]
    }
  }

  Spots are ordered: Tier 1 (official venues) first, then Tier 2
  (semi-official), then generic numbered spots. Empty list = guide only.

Usage:
  pip3 install requests beautifulsoup4 lxml
  python3 tools/scrape_viewing_parks.py

Resumes automatically if interrupted (uses progress cache).
"""

import requests
import re
import json
import time
import os
import math
import xml.etree.ElementTree as ET
from bs4 import BeautifulSoup
from pathlib import Path

BASE = "https://www.spotterguide.net"
OUTPUT = Path(__file__).parent / "viewing_parks.json"
PROGRESS = Path(__file__).parent / "viewing_parks_progress.json"
DELAY = 1.2  # seconds between requests — be polite

HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; ATC-Frequencies-App-Bot/1.0)"
}

KML_NS = {'kml': 'http://www.opengis.net/kml/2.2'}

# Names that indicate parking/infrastructure rather than spotting spots
# Style colors used by spotterguide.net — only used to skip parking/amenity pins
# Blue=parking, Amber=amenities. Red is USED for actual spots on some airports (JFK, EHAM).
# So we only skip blue/amber; everything else may be a spot.
_SKIP_STYLE_COLORS = {
    '0288D1',  # blue = parking / transport
    'F9A825',  # amber = amenities (food, hotels, fuel)
    'FF5252',  # coral/red = warnings / no-go zones
}

# Non-spot name keywords — skip these regardless of style color
SKIP_KEYWORDS = {
    'car park', 'carpark', 'car-park',
    'hotel', 'hostel', 'motel', 'inn',
    'restaurant', 'mcdonald', 'food', 'café', 'cafe', 'supermarket',
    'fuel station', 'petrol', 'gas station',
    'entrance by car', 'no longer available', 'not available anymore',
    'toilet', ' wc ', 'restroom',
    'walking route', 'walkingroute', 'route to spot',
    'don`t use', "don't use", 'closed by', 'section control', 'cctv',
    'private property', 'private land', 'no trespassing', 'trespass',
}

# Two-tier preference for primary coordinate selection.
# Tier 1 = official paid/designated venues (beat everything else)
# Tier 2 = semi-official free spots (beat generic numbered spots)
TIER1_KEYWORDS = {
    'runway visitor', 'visitor park', 'visitors park',
    'observation deck', 'observation hill', 'observation tower',
    'besucherpark', 'besucherhügel',          # German visitor parks
    'spotterplaats',                           # Dutch official areas
    'airport park', 'visitor centre', 'visitor center',
    'viewing terrace', 'planespotter terrace',
}
TIER2_KEYWORDS = {
    'viewing area', 'viewing park',
    'spotters hill', 'spotters mound', 'spotting hill', 'spotting mound',
}

# Continent category paths on spotterguide.net
CONTINENTS = [
    'europe',
    'north-america',
    'south-america',
    'asia',
    'middle-east',
    'africa',
    'australasia',
    'oceania',
]


DEDUP_RADIUS_M = 200  # treat spots closer than this as the same physical location


# ── Helpers ────────────────────────────────────────────────────────────────────


def _haversine_m(lat1, lon1, lat2, lon2):
    R = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _dedup_spots(spots):
    """Drop spots within DEDUP_RADIUS_M of an already-kept (higher-tier) spot."""
    kept = []
    for s in spots:
        if not any(_haversine_m(s['lat'], s['lon'], k['lat'], k['lon']) < DEDUP_RADIUS_M for k in kept):
            kept.append(s)
    return kept

def get(url, retries=3):
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=HEADERS, timeout=20)
            if r.status_code == 200:
                return r
            if r.status_code == 404:
                return None
        except requests.RequestException as e:
            print(f"    Request error ({e}), attempt {attempt+1}/{retries}")
            time.sleep(3)
    return None


def icao_from_slug(slug):
    """
    Extract ICAO from slug like 'munich-muc-eddm' or 'new-york-jfk-kjfk'.
    ICAO is always the last dash-separated segment; IATA the second-to-last.
    """
    parts = slug.rstrip('/').split('-')
    if len(parts) >= 2:
        return parts[-1].upper()
    return None


def _style_color(style_url):
    """Extract hex color from a style URL like '#icon-1499-DB4436-nodesc-normal'."""
    m = re.search(r'icon-\d+-([A-F0-9]{6})', style_url, re.IGNORECASE)
    return m.group(1).upper() if m else None


def _is_infrastructure(name, style_url=''):
    """True if this placemark is clearly parking, food, or a no-go warning."""
    color = _style_color(style_url)
    if color and color in _SKIP_STYLE_COLORS:
        return True
    n = ' ' + name.lower().strip() + ' '
    # Standalone 'parking N' pattern
    if re.match(r'^parking\s', name.lower()):
        return True
    return any(kw in n for kw in SKIP_KEYWORDS)


def _tier(name):
    """Return 1 (official venue), 2 (semi-official), or 0 (generic spot)."""
    n = name.lower()
    if any(kw in n for kw in TIER1_KEYWORDS):
        return 1
    if any(kw in n for kw in TIER2_KEYWORDS):
        return 2
    return 0


def parse_kml(kml_text):
    """
    Parse Google My Maps KML and return ALL non-infrastructure placemarks,
    ordered: Tier 1 (official venues) → Tier 2 (semi-official) → generic spots.

    KML coordinate order is lon,lat,alt.
    Returns empty list if no usable points found.
    """
    try:
        root = ET.fromstring(kml_text)
    except ET.ParseError:
        return []

    tier1 = []
    tier2 = []
    tier3 = []

    for pm in root.findall('.//kml:Placemark', KML_NS):
        name = (pm.findtext('kml:name', '', KML_NS) or '').strip()
        style_url = pm.findtext('kml:styleUrl', '', KML_NS) or ''
        point = pm.find('.//kml:Point/kml:coordinates', KML_NS)
        if point is None or not point.text:
            continue
        parts = point.text.strip().split(',')
        if len(parts) < 2:
            continue
        try:
            lon = float(parts[0])
            lat = float(parts[1])
        except ValueError:
            continue
        if _is_infrastructure(name, style_url):
            continue
        entry = {'name': name, 'lat': round(lat, 6), 'lon': round(lon, 6)}
        t = _tier(name)
        if t == 1:
            tier1.append(entry)
        elif t == 2:
            tier2.append(entry)
        else:
            tier3.append(entry)

    return _dedup_spots(tier1 + tier2 + tier3)


def get_spots(page_url):
    """
    Fetch an airport page and extract all spotting coordinates via KML.
    Returns a list of {name, lat, lon} dicts (empty if no map / no usable points).
    """
    r = get(page_url)
    if not r:
        return []

    # Use regex on raw HTML — BS4 iframe detection is unreliable with lazy-load attrs
    m = re.search(r'maps/d/embed\?mid=([A-Za-z0-9_-]+)', r.text)
    mid = m.group(1) if m else None

    if not mid:
        return []

    kml_url = f"https://www.google.com/maps/d/kml?mid={mid}&forcekml=1"
    time.sleep(DELAY)
    kr = get(kml_url)
    if not kr:
        return []

    return parse_kml(kr.text)


# ── Crawl airport URLs ─────────────────────────────────────────────────────────

def get_country_urls(continent_url):
    """Get country category URLs from a continent page — only those under this continent."""
    r = get(continent_url)
    if not r:
        return []
    # Extract continent slug from the URL (e.g. 'europe' from .../europe/)
    continent_slug = continent_url.rstrip('/').split('/')[-1]
    # Match only country URLs scoped to this continent
    pattern = re.compile(
        r'href=["\']([^"\']*category/planespotting/' + re.escape(continent_slug) + r'/[^/]+/)["\']'
    )
    urls = set()
    for m in pattern.finditer(r.text):
        href = m.group(1)
        if href.count('/') >= 6:
            urls.add(href)
    return list(urls)


def get_airport_urls_from_country(country_url):
    """Get all airport page URLs from a country category page (with pagination)."""
    urls = set()
    page = 1
    while True:
        url = country_url if page == 1 else f"{country_url.rstrip('/')}/page/{page}/"
        r = get(url)
        if not r:
            break
        soup = BeautifulSoup(r.text, 'html.parser')
        found = set()
        for a in soup.find_all('a', href=True):
            href = a['href']
            # Airport pages: /planespotting/continent/country/city-IATA-ICAO/
            if re.match(r'.*/planespotting/[^/]+/[^/]+/[^/]+-[A-Z0-9]{3,4}/$', href, re.IGNORECASE):
                if '#' not in href:
                    found.add(href.rstrip('/') + '/')
        if not found:
            break
        urls.update(found)
        page += 1
        time.sleep(DELAY)
    return list(urls)


def discover_all_airports():
    """Walk continent → country → airport pages and return all airport URLs."""
    all_urls = []
    for continent in CONTINENTS:
        continent_url = f"{BASE}/category/planespotting/{continent}/"
        print(f"\nCrawling continent: {continent}")
        country_urls = get_country_urls(continent_url)
        if not country_urls:
            # Some continents have airports directly on the continent page
            airport_urls = get_airport_urls_from_country(continent_url)
            all_urls.extend(airport_urls)
            print(f"  Direct airports: {len(airport_urls)}")
            time.sleep(DELAY)
            continue

        print(f"  Countries: {len(country_urls)}")
        for country_url in country_urls:
            airport_urls = get_airport_urls_from_country(country_url)
            all_urls.extend(airport_urls)
            print(f"    {country_url.rstrip('/').split('/')[-1]}: {len(airport_urls)} airports")
            time.sleep(DELAY)

    # Deduplicate
    return list(set(all_urls))


# ── Main ───────────────────────────────────────────────────────────────────────

def load_progress():
    if PROGRESS.exists():
        with open(PROGRESS) as f:
            return json.load(f)
    return {'done': [], 'results': {}}


def save_progress(progress):
    with open(PROGRESS, 'w') as f:
        json.dump(progress, f, indent=2)


def main():
    print("ATC Frequencies — Airport Viewing Parks Scraper")
    print("Source: spotterguide.net\n")

    progress = load_progress()
    done_urls = set(progress['done'])
    results = progress['results']

    # Step 1: discover all airport URLs (or load from progress)
    if 'airport_urls' not in progress:
        print("Step 1: Discovering airport URLs...")
        airport_urls = discover_all_airports()
        progress['airport_urls'] = airport_urls
        save_progress(progress)
        print(f"\nTotal airports found: {len(airport_urls)}")
    else:
        airport_urls = progress['airport_urls']
        print(f"Loaded {len(airport_urls)} airport URLs from progress cache.")

    # Step 2: scrape each airport page for spotting coordinates
    todo = [u for u in airport_urls if u not in done_urls]
    print(f"\nStep 2: Scraping {len(todo)} remaining airports ({len(done_urls)} already done)...\n")

    for i, url in enumerate(todo, 1):
        slug = url.rstrip('/').split('/')[-1]
        icao = icao_from_slug(slug)
        if not icao:
            done_urls.add(url)
            continue

        print(f"[{i}/{len(todo)}] {icao} — {slug}")
        spots = get_spots(url)

        name_parts = slug.split('-')[:-2]  # remove IATA and ICAO at end
        display_name = ' '.join(p.capitalize() for p in name_parts)

        results[icao] = {
            'name': display_name,
            'url': url,
            'spots': spots,
        }

        if spots:
            print(f"  → {len(spots)} spot(s): {spots[0]['name']}")
        else:
            print(f"  → guide only (no KML map)")

        done_urls.add(url)
        progress['done'] = list(done_urls)
        progress['results'] = results

        # Save progress every 10 airports
        if i % 10 == 0:
            save_progress(progress)

        time.sleep(DELAY)

    save_progress(progress)

    # Step 3: write final output
    print(f"\nWriting {len(results)} airports with viewing parks to {OUTPUT}")
    with open(OUTPUT, 'w') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    # Summary stats
    with_spots = sum(1 for v in results.values() if v.get('spots'))
    guide_only = sum(1 for v in results.values() if not v.get('spots'))
    total_spots = sum(len(v.get('spots', [])) for v in results.values())
    print(f"\nDone.")
    print(f"  Airports total: {len(results)}")
    print(f"  With spot coordinates: {with_spots} ({total_spots} spots total)")
    print(f"  Guide only (no KML map): {guide_only}")
    print(f"  Output: {OUTPUT}")


if __name__ == '__main__':
    main()
