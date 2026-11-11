#!/usr/bin/env python3
"""Packages the official snapshot for over-the-air data updates.

Writes to dist/opendata/ (not committed):
  official_smoking_areas.json.gz   gzip-compressed snapshot
  opendata-manifest.json           {format, generated, count, size, sha256}

CI publishes both files as assets of the GitHub release with tag `opendata`;
the app polls the small manifest and downloads the snapshot only when it is
newer than the data it already has.

Run: python3 tool/opendata/package_snapshot.py [out_dir]
"""

from __future__ import annotations

import gzip
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "assets" / "opendata" / "official_smoking_areas.json"


def package(out_dir: Path) -> dict:
    raw = SNAPSHOT.read_bytes()
    data = json.loads(raw)
    out_dir.mkdir(parents=True, exist_ok=True)
    gz = gzip.compress(raw, compresslevel=9, mtime=0)  # reproducible
    (out_dir / "official_smoking_areas.json.gz").write_bytes(gz)
    manifest = {
        "format": data.get("format", 1),
        "generated": data["generated"],
        "count": len(data["areas"]),
        "size": len(gz),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }
    (out_dir / "opendata-manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    return manifest


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "opendata"
    print(json.dumps(package(out)))
