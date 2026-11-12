#!/usr/bin/env python3
"""Bundles the last published OSM export with the app.

The OSM export (`osm_spots.json.gz`, see update_osm.py) is published weekly
to the release `opendata`. App builds copy it to
assets/opendata/osm_spots.json first, so a fresh installation shows all OSM
spots on the first start without network. Only replaces the bundled file
when the published one is newer; network errors keep it.

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
URL = ("https://github.com/c0deltin/smokingareas/releases/download/opendata/"
       "osm_spots.json.gz")


def newer(published: dict, bundled: dict | None) -> bool:
    return bundled is None or str(published.get("generated", "")) > str(
        bundled.get("generated", ""))


def main() -> int:
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
