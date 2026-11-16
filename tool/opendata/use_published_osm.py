#!/usr/bin/env python3
"""Bundles the last published OSM exports with the app.

The OSM exports (see update_osm.py) are published weekly to the release
`opendata`. App builds copy them first, so a fresh installation shows OSM
spots on the first start without network:

  osm_tiles.txt.gz  -> assets/opendata/osm_tiles.txt.gz (all of Japan;
                       the repository holds an empty placeholder)
  osm_spots.json.gz -> assets/opendata/osm_spots.json (cities only; used
                       until the tiles are installed)

Only replaces a bundled file when the published one is newer; network
errors keep it.

Run: python3 tool/opendata/use_published_osm.py
"""

from __future__ import annotations

import gzip
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "assets" / "opendata" / "osm_spots.json"
RELEASE = "https://github.com/c0deltin/smokingareas/releases/download/opendata/"
URL = RELEASE + "osm_spots.json.gz"
BUNDLED_TILES = ROOT / "assets" / "opendata" / "osm_tiles.txt.gz"
TILES_URL = RELEASE + "osm_tiles.txt.gz"


def newer(published: dict, bundled: dict | None) -> bool:
    return bundled is None or str(published.get("generated", "")) > str(
        bundled.get("generated", ""))


def tiles_header(gz: bytes) -> dict | None:
    """Header (first line) of a tiles file, None when empty or unreadable."""
    try:
        first = gzip.decompress(gz).split(b"\n", 1)[0]
        return json.loads(first.decode("utf-8"))
    except Exception:  # noqa: BLE001
        return None


def bundle_tiles() -> None:
    bundled = tiles_header(BUNDLED_TILES.read_bytes()) if BUNDLED_TILES.exists() else None
    try:
        req = urllib.request.Request(TILES_URL, headers={"User-Agent": "smokingareas-opendata/1.0"})
        with urllib.request.urlopen(req, timeout=120) as r:
            gz = r.read()
    except Exception as e:  # noqa: BLE001
        print(f"bundled OSM tiles unchanged ({e})")
        return
    published = tiles_header(gz)
    if not published or not published.get("count"):
        print("published OSM tiles are empty or unreadable – bundled file unchanged")
        return
    if newer(published, bundled):
        BUNDLED_TILES.write_bytes(gz)
        print(f"bundled OSM tiles: {published['generated']} "
              f"({published['count']} elements in {published.get('tiles')} tiles)")
    else:
        print(f"bundled OSM tiles are current ({bundled.get('generated')})")


def main() -> int:
    bundle_tiles()
    bundled = json.loads(BUNDLED.read_text(encoding="utf-8")) if BUNDLED.exists() else None
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "smokingareas-opendata/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            published = json.loads(gzip.decompress(r.read()).decode("utf-8"))
    except Exception as e:  # noqa: BLE001
        print(f"bundled OSM export unchanged ({e})")
        return 0
    if not published.get("elements"):
        print("published OSM export is empty – bundled file unchanged")
        return 0
    if newer(published, bundled):
        BUNDLED.write_text(
            json.dumps(published, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8")
        print(f"bundled OSM export: {published['generated']} "
              f"({len(published['elements'])} elements)")
    else:
        print(f"bundled OSM export is current ({bundled.get('generated')})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
