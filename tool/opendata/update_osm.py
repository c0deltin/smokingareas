#!/usr/bin/env python3
"""Exports the OpenStreetMap smoking areas and public toilets of all cities
the app covers, for in-app data updates.

Instead of every installed app querying the public Overpass API, CI queries
it once (weekly and with every app release, a few requests with pauses in
between) and publishes the result next to the official snapshot:

  osm_spots.json.gz   {"format", "generated", "elements": [...]}
                      elements in Overpass JSON form (type, id, lat, lon,
                      tags – only the tags the app uses)
  osm-manifest.json   {format, generated, count, size, sha256}

`generated` only changes when the data changes. When a request fails or the
result looks incomplete, nothing is written and the published data stays.

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
PUBLISHED = ("https://github.com/c0deltin/smokingareas/releases/download/"
             "opendata/osm-manifest.json")
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
USER_AGENT = "smokingareas/1.0 (+https://github.com/c0deltin/smokingareas)"
FORMAT = 1
CITIES_PER_QUERY = 8
PAUSE_SECONDS = 10

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


def build_query(boxes: list[tuple[float, float, float, float]]) -> str:
    parts = []
    for s, w, n, e in boxes:
        bbox = f"{s:.5f},{w:.5f},{n:.5f},{e:.5f}"
        parts += [
            f'  nwr["amenity"~"^(smoking_area|smoking_room)$"]({bbox});',
            f'  nwr["smoking"="dedicated"]({bbox});',
            f'  nwr["amenity"="toilets"]["access"!~"^(private|no|customers|permit)$"]({bbox});',
        ]
    return "[out:json][timeout:180];\n(\n" + "\n".join(parts) + "\n);\nout center tags;"


def normalize(elements: list[dict]) -> list[dict]:
    """Point coordinates (centre for ways/relations), only used tags,
    no duplicates, stable order."""
    out: dict[tuple[str, int], dict] = {}
    for e in elements:
        lat, lon = e.get("lat"), e.get("lon")
        if (lat is None or lon is None) and isinstance(e.get("center"), dict):
            lat, lon = e["center"].get("lat"), e["center"].get("lon")
        if lat is None or lon is None or "type" not in e or "id" not in e:
            continue
        tags = {k: str(v) for k, v in (e.get("tags") or {}).items() if k in KEEP_TAGS}
        out[(e["type"], int(e["id"]))] = {
            "type": e["type"],
            "id": int(e["id"]),
            "lat": round(float(lat), 6),
            "lon": round(float(lon), 6),
            "tags": dict(sorted(tags.items())),
        }
    return [out[k] for k in sorted(out)]


def content_hash(elements: list[dict]) -> str:
    return hashlib.sha256(
        json.dumps(elements, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def overpass(query: str) -> list[dict]:
    body = urllib.parse.urlencode({"data": query}).encode()
    last = None
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=body, headers={
                "User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=240) as r:
                data = json.loads(r.read().decode("utf-8"))
            if "remark" in data and "error" in str(data["remark"]).lower():
                raise RuntimeError(data["remark"])
            return data.get("elements", [])
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(PAUSE_SECONDS)
    raise RuntimeError(f"Overpass unreachable: {last}")


def published_manifest() -> dict | None:
    try:
        req = urllib.request.Request(PUBLISHED, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:  # noqa: BLE001
        return None


def build(elements: list[dict], previous: dict | None, now: datetime) -> tuple[dict, dict]:
    """Snapshot and manifest; keeps the previous version when nothing changed."""
    digest = content_hash(elements)
    generated = (previous.get("generated")
                 if previous and previous.get("content") == digest
                 else now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    snapshot = {"format": FORMAT, "generated": generated, "elements": elements}
    manifest = {"format": FORMAT, "generated": generated, "count": len(elements),
                "content": digest}
    return snapshot, manifest


def plausible(count: int, previous: dict | None) -> bool:
    """Refuses suspiciously small results (partial Overpass answers)."""
    return count > 0 and (previous is None or count >= 0.8 * previous.get("count", 0))


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "opendata"
    cities = city_bounds(CITIES.read_text(encoding="utf-8"))
    raw: list[dict] = []
    try:
        for i in range(0, len(cities), CITIES_PER_QUERY):
            chunk = cities[i:i + CITIES_PER_QUERY]
            if i:
                time.sleep(PAUSE_SECONDS)  # be gentle with the public servers
            raw += overpass(build_query([b for _, b in chunk]))
            print(f"OSM: {', '.join(c for c, _ in chunk)} – {len(raw)} elements so far")
    except Exception as e:  # noqa: BLE001
        print(f"OSM export skipped, published data stays: {e}")
        return 0

    elements = normalize(raw)
    previous = published_manifest()
    if not plausible(len(elements), previous):
        print(f"OSM export skipped: only {len(elements)} elements "
              f"(published: {previous and previous.get('count')})")
        return 0
    snapshot, manifest = build(elements, previous, datetime.now(timezone.utc))
    data = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")).encode()
    gz = gzip.compress(data, compresslevel=9, mtime=0)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "osm_spots.json.gz").write_bytes(gz)
    manifest["size"] = len(gz)
    (out_dir / "osm-manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"OSM export: {len(elements)} elements, {len(gz)} bytes, "
          f"version {manifest['generated']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
