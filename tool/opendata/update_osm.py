#!/usr/bin/env python3
"""Exports the OpenStreetMap smoking areas and public toilets of all of
Japan, for in-app data updates.

Instead of every installed app querying the public Overpass API, CI queries
it once a week – one request per region (a group of prefectures), with
pauses in between – and publishes the result next to the official snapshot:

  osm_tiles.txt.gz         all of Japan in tiles of 1° × 1° (format 2):
                           line 1: {"format", "generated", "count", "tiles"}
                           then one line per tile: "<lat>_<lon>\t[elements]"
                           so apps can split it without parsing it whole
  osm-tiles-manifest.json  {format, generated, count, content, size, tiles}
  osm_spots.json.gz        only the areas of the cities in cities.dart
                           (format 1, for app versions before tiles)
  osm-manifest.json        its manifest

Elements are in Overpass JSON form (type, id, lat, lon, tags – only the tags
the app uses; tiles also carry the region code "p"). `generated` only
changes when the data changes. A region that still fails after all
retries keeps its elements of the last published export; without one, or
when the result looks incomplete, nothing is written and the published data
stays.

Run: python3 tool/opendata/update_osm.py [out_dir]
Data © OpenStreetMap contributors, ODbL.
"""

from __future__ import annotations

import gzip
import hashlib
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CITIES = ROOT / "lib" / "data" / "cities.dart"
RELEASE = "https://github.com/c0deltin/smokingareas/releases/download/opendata/"
PUBLISHED = RELEASE + "osm-manifest.json"
PUBLISHED_TILES = RELEASE + "osm_tiles.txt.gz"
PUBLISHED_TILES_MANIFEST = RELEASE + "osm-tiles-manifest.json"
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
USER_AGENT = "smokingareas/1.0 (+https://github.com/c0deltin/smokingareas)"
FORMAT = 1
TILES_FORMAT = 2
# ISO 3166-2 codes JP-01 (Hokkaidō) … JP-47 (Okinawa).
PREFECTURES = [f"{i:02d}" for i in range(1, 48)]
# One Overpass request per region: area filters take about a minute each,
# so 47 single prefectures did not fit into the time budget.
REGIONS = {
    "hokkaido": ["01"],
    "tohoku": ["02", "03", "04", "05", "06", "07"],
    "kanto": ["08", "09", "10", "11", "12", "13", "14"],
    "chubu": ["15", "16", "17", "18", "19", "20", "21", "22", "23"],
    "kinki": ["24", "25", "26", "27", "28", "29", "30"],
    "chugoku": ["31", "32", "33", "34", "35"],
    "shikoku": ["36", "37", "38", "39"],
    "kyushu": ["40", "41", "42", "43", "44", "45", "46", "47"],
}
PAUSE_SECONDS = 10
# Busy public servers answer with 429/504 now and then: retry each request
# a few times with growing pauses before giving up.
RETRIES = 3
RETRY_PAUSE_SECONDS = 30
# Server-side query timeout and client timeout per request (seconds).
QUERY_TIMEOUT = 300
# Stop querying after this long (the CI step has a hard limit of 80 min);
# remaining regions then count as failed.
DEADLINE_SECONDS = 70 * 60
REQUEST_TIMEOUT = 330

# Tags the app reads (lib/models/smoking_area.dart); everything else is
# dropped to keep the download small.
KEEP_TAGS = {
    "name", "name:en", "name:ja", "amenity", "smoking", "indoor", "covered",
    "access", "access:note", "opening_hours", "fee", "operator", "wheelchair",
    "changing_table", "description", "note", "level", "unisex", "female",
    "male", "addr:full", "check_date", "disused:amenity",
}


def city_bounds(dart_source: str) -> list[tuple[str, tuple[float, float, float, float]]]:
    """(id, (south, west, north, east)) of every city, like GeoBounds.around."""
    out = []
    pattern = re.compile(
        r"City\(id: '([^']+)'.*?center: LatLng\(([-\d.]+), ([-\d.]+)\), "
        r"radiusKm: ([\d.]+)")
    for m in pattern.finditer(dart_source):
        cid, lat, lon, radius = m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4))
        d_lat = radius / 111.32
        d_lon = radius / (111.32 * math.cos(math.radians(lat)))
        out.append((cid, (lat - d_lat, lon - d_lon, lat + d_lat, lon + d_lon)))
    return out


def build_query(region: str) -> str:
    """Smoking areas and public toilets of the prefectures of a region."""
    codes = "|".join(REGIONS[region])
    return (
        f"[out:json][timeout:{QUERY_TIMEOUT}];\n"
        f'area["ISO3166-2"~"^JP-({codes})$"]->.a;\n'
        "(\n"
        '  nwr["amenity"~"^(smoking_area|smoking_room)$"](area.a);\n'
        '  nwr["smoking"="dedicated"](area.a);\n'
        '  nwr["amenity"="toilets"]["access"!~"^(private|no|customers|permit)$"](area.a);\n'
        ");\nout center tags;"
    )


def tile_of(element: dict) -> str:
    """Tile id "<lat>_<lon>" of the 1° × 1° cell (south-west corner)."""
    return f"{math.floor(element['lat'])}_{math.floor(element['lon'])}"


def normalize(elements: list[dict]) -> list[dict]:
    """Point coordinates (centre for ways/relations), only used tags,
    no duplicates (the first prefecture wins), stable order."""
    out: dict[tuple[str, int], dict] = {}
    for e in elements:
        lat, lon = e.get("lat"), e.get("lon")
        if (lat is None or lon is None) and isinstance(e.get("center"), dict):
            lat, lon = e["center"].get("lat"), e["center"].get("lon")
        if lat is None or lon is None or "type" not in e or "id" not in e:
            continue
        key = (e["type"], int(e["id"]))
        if key in out:
            continue
        tags = {k: str(v) for k, v in (e.get("tags") or {}).items() if k in KEEP_TAGS}
        item = {
            "type": e["type"],
            "id": int(e["id"]),
            "lat": round(float(lat), 6),
            "lon": round(float(lon), 6),
            "tags": dict(sorted(tags.items())),
        }
        if e.get("p"):
            item["p"] = e["p"]
        out[key] = item
    return [out[k] for k in sorted(out)]


def content_hash(elements: list[dict]) -> str:
    return hashlib.sha256(
        json.dumps(elements, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def overpass(query: str, sleep=time.sleep, fetch=None) -> list[dict]:
    body = urllib.parse.urlencode({"data": query}).encode()

    def default_fetch(url: str) -> dict:
        req = urllib.request.Request(url, data=body, headers={
            "User-Agent": USER_AGENT, "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8"))

    fetch = fetch or default_fetch
    last = None
    for attempt in range(RETRIES):
        if attempt:
            sleep(RETRY_PAUSE_SECONDS * attempt)
        for url in ENDPOINTS:
            try:
                data = fetch(url)
                if "remark" in data and "error" in str(data["remark"]).lower():
                    raise RuntimeError(data["remark"])
                return data.get("elements", [])
            except Exception as e:  # noqa: BLE001
                last = e
                sleep(PAUSE_SECONDS)
    raise RuntimeError(f"Overpass unreachable: {last}")


def _download(url: str, timeout: int = 60) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def parse_tiles(text: str) -> tuple[dict, list[dict]]:
    """Header and elements of an osm_tiles.txt file."""
    lines = text.split("\n")
    header = json.loads(lines[0])
    elements: list[dict] = []
    for line in lines[1:]:
        if line.strip():
            _, data = line.split("\t", 1)
            elements += json.loads(data)
    return header, elements


def published_tiles() -> list[dict]:
    """Elements of the last published Japan export ([] when there is none)."""
    try:
        _, elements = parse_tiles(gzip.decompress(_download(PUBLISHED_TILES)).decode("utf-8"))
        return elements
    except Exception:  # noqa: BLE001
        return []


def collect(regions, query, previous, clock=time.monotonic) -> list[dict]:
    """Queries region by region and marks every element with its region
    ("p"). A region that still fails after all retries keeps its elements
    of the last published export; without a published export the whole run
    is given up (raises)."""
    raw: list[dict] = []
    old: list[dict] | None = None
    deadline = clock() + DEADLINE_SECONDS
    for i, pref in enumerate(regions):
        if i:
            time.sleep(PAUSE_SECONDS)  # be gentle with the public servers
        try:
            if clock() > deadline:
                raise TimeoutError("time budget used up")
            got = query(build_query(pref))
            raw += [{**e, "p": pref} for e in got]
            print(f"OSM: {pref} – {len(got)} elements", flush=True)
        except Exception as e:  # noqa: BLE001
            if old is None:
                old = previous()
            if not old:
                raise
            kept = [el for el in old if el.get("p") == pref]
            raw += kept
            print(f"OSM: {pref} failed ({e}) – kept {len(kept)} published "
                  f"elements", flush=True)
    return raw


def inside(element: dict, boxes: list[tuple[float, float, float, float]]) -> bool:
    lat, lon = element.get("lat"), element.get("lon")
    return lat is not None and any(
        s <= lat <= n and w <= lon <= e for s, w, n, e in boxes)


def published_manifest(url: str = PUBLISHED) -> dict | None:
    try:
        return json.loads(_download(url, timeout=30).decode("utf-8"))
    except Exception:  # noqa: BLE001
        return None


def build(elements: list[dict], previous: dict | None, now: datetime,
          fmt: int = FORMAT) -> tuple[dict, dict]:
    """Snapshot and manifest; keeps the previous version when nothing changed."""
    digest = content_hash(elements)
    generated = (previous.get("generated")
                 if previous and previous.get("content") == digest
                 else now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    snapshot = {"format": fmt, "generated": generated, "elements": elements}
    manifest = {"format": fmt, "generated": generated, "count": len(elements),
                "content": digest}
    return snapshot, manifest


def tiles_text(snapshot: dict) -> str:
    """The tiles file: header line, then one line per tile (sorted)."""
    tiles: dict[str, list[dict]] = {}
    for e in snapshot["elements"]:
        tiles.setdefault(tile_of(e), []).append(e)
    header = {"format": snapshot["format"], "generated": snapshot["generated"],
              "count": len(snapshot["elements"]), "tiles": len(tiles)}
    lines = [json.dumps(header, separators=(",", ":"))]
    for tile in sorted(tiles):
        lines.append(tile + "\t" + json.dumps(
            tiles[tile], ensure_ascii=False, separators=(",", ":")))
    return "\n".join(lines) + "\n"


def tile_counts(elements: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for e in elements:
        counts[tile_of(e)] = counts.get(tile_of(e), 0) + 1
    return dict(sorted(counts.items()))


def plausible(count: int, previous: dict | None) -> bool:
    """Refuses suspiciously small results (partial Overpass answers)."""
    return count > 0 and (previous is None or count >= 0.8 * previous.get("count", 0))


def city_elements(elements: list[dict], cities) -> list[dict]:
    """The format-1 export: elements inside the city areas, without "p"."""
    boxes = [b for _, b in cities]
    return [{k: v for k, v in e.items() if k != "p"}
            for e in elements if inside(e, boxes)]


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "opendata"
    cities = city_bounds(CITIES.read_text(encoding="utf-8"))
    try:
        raw = collect(list(REGIONS), overpass, published_tiles)
    except Exception as e:  # noqa: BLE001
        print(f"OSM export skipped, published data stays: {e}", flush=True)
        return 0

    elements = normalize(raw)
    now = datetime.now(timezone.utc)
    out_dir.mkdir(parents=True, exist_ok=True)

    # All of Japan, in tiles.
    previous = published_manifest(PUBLISHED_TILES_MANIFEST)
    if plausible(len(elements), previous):
        snapshot, manifest = build(elements, previous, now, TILES_FORMAT)
        gz = gzip.compress(tiles_text(snapshot).encode(), compresslevel=9, mtime=0)
        (out_dir / "osm_tiles.txt.gz").write_bytes(gz)
        manifest["size"] = len(gz)
        manifest["tiles"] = tile_counts(elements)
        (out_dir / "osm-tiles-manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
        by_type = {}
        for e in elements:
            kind = e["tags"].get("amenity", "smoking=dedicated")
            by_type[kind] = by_type.get(kind, 0) + 1
        print(f"OSM Japan: {len(elements)} elements in {len(manifest['tiles'])} "
              f"tiles, {len(gz)} bytes, version {manifest['generated']} – {by_type}")
    else:
        print(f"OSM Japan export skipped: only {len(elements)} elements "
              f"(published: {previous and previous.get('count')})")

    # The cities only, for app versions before tiles.
    city = city_elements(elements, cities)
    previous = published_manifest(PUBLISHED)
    if not plausible(len(city), previous):
        print(f"OSM city export skipped: only {len(city)} elements "
              f"(published: {previous and previous.get('count')})")
        return 0
    snapshot, manifest = build(city, previous, now)
    data = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")).encode()
    gz = gzip.compress(data, compresslevel=9, mtime=0)
    (out_dir / "osm_spots.json.gz").write_bytes(gz)
    manifest["size"] = len(gz)
    (out_dir / "osm-manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"OSM cities: {len(city)} elements, {len(gz)} bytes, "
          f"version {manifest['generated']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
