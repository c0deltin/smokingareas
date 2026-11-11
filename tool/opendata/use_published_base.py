#!/usr/bin/env python3
"""Uses the last published snapshot (release `opendata`) as the importer's
base when it is newer than the committed one.

Ids and aliases are carried over from the *previous* snapshot
(`carry_aliases`). Installed apps may already have the published snapshot –
and community data keyed by its ids – so a refresh must start from it, not
from an older committed file. Network errors are ignored (the committed file
stays the base).
"""

from __future__ import annotations

import gzip
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "assets" / "opendata" / "official_smoking_areas.json"
URL = ("https://github.com/c0deltin/smokingareas/releases/download/opendata/"
       "official_smoking_areas.json.gz")


def main() -> int:
    committed = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "smokingareas-opendata/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            published_raw = gzip.decompress(r.read()).decode("utf-8")
        published = json.loads(published_raw)
    except Exception as e:  # noqa: BLE001
        print(f"no published snapshot used ({e})")
        return 0
    if str(published.get("generated", "")) > str(committed.get("generated", "")):
        SNAPSHOT.write_text(published_raw, encoding="utf-8")
        print(f"base: published snapshot {published['generated']} "
              f"(committed {committed.get('generated')})")
    else:
        print(f"base: committed snapshot {committed.get('generated')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
