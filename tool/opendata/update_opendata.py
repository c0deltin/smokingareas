#!/usr/bin/env python3
"""Builds assets/opendata/official_smoking_areas.json from official sources.

Official (municipal) lists of public smoking areas are published in very
different formats: CSV files with coordinates, HTML pages with addresses,
form-based download portals. Fetching and parsing all of them on the phone
would be fragile, so this script normalises them once into a single JSON
snapshot that is bundled with the app. The app merges the snapshot with the
live OpenStreetMap data and removes duplicates.

Run:  python3 tool/opendata/update_opendata.py
Only the Python standard library is used. If a source fails, the entries of
the previous snapshot for that source are kept, so a temporary outage never
removes data. Addresses without coordinates are geocoded with the GSI
(Geospatial Information Authority of Japan) address search; results are cached
in tool/opendata/geocode_cache.json.
"""

from __future__ import annotations

import csv
import datetime as dt
import html
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "opendata" / "official_smoking_areas.json"
GEOCODE_CACHE = Path(__file__).resolve().parent / "geocode_cache.json"
USER_AGENT = "smokingareas-opendata/1.0 (+https://github.com/c0deltin/smokingareas)"

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


def fetch(url: str, *, data: dict | None = None, timeout: int = 60, attempts: int = 4) -> bytes:
    """GET (or POST with form [data]); retries transient network errors."""
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    for attempt in range(attempts):
        req = urllib.request.Request(url, data=body, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            if attempt == attempts - 1:
                raise
            time.sleep(2 ** (attempt + 1))
    raise AssertionError("unreachable")


def decode(raw: bytes) -> str:
    for enc in ("utf-8-sig", "cp932"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            pass
    return raw.decode("utf-8", errors="replace")


def text_of(fragment: str) -> str:
    t = re.sub(r"<br\s*/?>", "\n", fragment)
    t = re.sub(r"<[^>]+>", "", t)
    t = html.unescape(t).replace("\xa0", " ")
    return re.sub(r"[ \t　]+", " ", t).strip()


_geocode_cache: dict[str, list[float] | None] = {}


def geocode(address: str, must_contain: str) -> tuple[float, float] | None:
    """GSI address search. Returns (lat, lon) or None."""
    if address in _geocode_cache:
        hit = _geocode_cache[address]
        return (hit[0], hit[1]) if hit else None
    url = "https://msearch.gsi.go.jp/address-search/AddressSearch?q=" + urllib.parse.quote(address)
    try:
        results = json.loads(fetch(url, timeout=30))
    except Exception as e:  # noqa: BLE001
        print(f"   geocode failed for {address}: {e}", file=sys.stderr)
        return None
    time.sleep(0.3)  # be polite
    for r in results:
        title = r["properties"]["title"]
        if must_contain in title:
            lon, lat = r["geometry"]["coordinates"]
            _geocode_cache[address] = [lat, lon]
            return lat, lon
    _geocode_cache[address] = None
    return None


_KANJI_NUM = str.maketrans("０１２３４５６７８９－ー―‐", "0123456789----")
_KANJI_DIGITS = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}


def _kanji_chome(m: re.Match) -> str:
    s = m.group(1)
    if s == "十":
        n = 10
    elif s.startswith("十"):
        n = 10 + _KANJI_DIGITS[s[1]]
    else:
        n = _KANJI_DIGITS[s]
    return f"{n}丁目"


def normalise_address(addr: str, prefix: str) -> str:
    """Turns '外神田1-3-9 木倉ビル1階' into '東京都千代田区外神田1-3-9'."""
    a = addr.translate(_KANJI_NUM)
    a = re.sub(r"(十?[一二三四五六七八九]|十)丁目", _kanji_chome, a)
    a = re.sub(r"（.*?）|\(.*?\)", "", a)
    a = a.replace("番地先", "番地").replace("番先", "番").replace("地先", "")
    a = re.sub(r"先$", "", a.strip())
    # cut building names / floors after the street number
    m = re.match(r"^(.*?\d+(?:[-丁目番号地]+\d*)*(?:番地?|号)?)", a)
    if m:
        a = m.group(1)
    a = a.strip()
    for p in (prefix, prefix.split("都")[-1] if "都" in prefix else prefix):
        if a.startswith(p):
            a = a[len(p):]
    return prefix + a


def area(*, source: str, local_id: str, name: str, lat: float, lon: float,
         address: str | None = None, hours: str | None = None,
         kind: str | None = None, geocoded: bool = False, note: str | None = None) -> dict:
    out = {
        "id": f"{source}:{local_id}",
        "source": source,
        "name": name.strip(),
        "lat": round(lat, 6),
        "lon": round(lon, 6),
    }
    if address:
        out["address"] = address
    if hours:
        out["hours"] = hours
    if kind:
        out["kind"] = kind
    if geocoded:
        out["geocoded"] = True
    if note:
        out["note"] = note
    return out


def merge_same_location(areas: list[dict]) -> list[dict]:
    """Several rooms in one building (e.g. 1F and 2F) get the same geocoded
    coordinate. Show them as one marker instead of stacked duplicates."""
    groups: dict[tuple, list[dict]] = {}
    for a in areas:
        groups.setdefault((a["source"], round(a["lat"], 5), round(a["lon"], 5)), []).append(a)
    merged = []
    for items in groups.values():
        if len(items) == 1:
            merged.append(items[0])
            continue
        first = dict(items[0])
        first["name"] = " / ".join(dict.fromkeys(i["name"] for i in items))
        hours = [f"{i['name']}: {i['hours']}" for i in items if i.get("hours")]
        if hours:
            first["hours"] = "\n".join(hours)
        first["members"] = len(items)
        merged.append(first)
    return merged


# --------------------------------------------------------------------------
# sources
# --------------------------------------------------------------------------

SOURCES: dict[str, dict] = {}


def source(key: str, *, name: str, city: str, url: str, license: str):
    def deco(fn):
        SOURCES[key] = {"fn": fn, "meta": {"id": key, "name": name, "city": city,
                                            "url": url, "license": license}}
        return fn
    return deco


@source("kyoto", name="京都市オープンデータ（施設情報・喫煙場所）", city="kyoto",
        url="https://data.city.kyoto.lg.jp/dataset/00003/", license="CC BY 4.0")
def kyoto() -> list[dict]:
    page = decode(fetch("https://data.city.kyoto.lg.jp/dataset/00003/"))
    # newest "施設情報一覧" CSV resource (download is a POST form)
    m = re.search(r"<form action='\.\./\.\./resource/\?id=(\d+)'[^>]*>.*?"
                  r"name='upload_file' type='hidden' value='([^']+\.csv)'", page, re.S)
    if not m:
        raise RuntimeError("CSV resource not found on dataset page")
    rid, fname = m.groups()
    raw = fetch(f"https://data.city.kyoto.lg.jp/resource/?id={rid}",
                data={"download": "Download", "upload_file": fname, "upload_url": ""})
    rows = list(csv.reader(io.StringIO(decode(raw))))
    head = rows[0]
    col = {}
    for i, h in enumerate(head):
        m_col = re.search(r"[（(]\s*([a-z_]+)\s*[)）]", h)
        if m_col:
            col[m_col.group(1)] = i
    out = []
    for r in rows[1:]:
        if len(r) <= col["cate_id"] or r[col["cate_id"]].strip() != "138":  # 138 = 喫煙場所
            continue
        out.append(area(source="kyoto", local_id=r[col["id"]], name=r[col["name"]],
                        lat=float(r[col["lat"]]), lon=float(r[col["lng"]]),
                        address=r[col["address"]] or None, kind="public"))
    return out


@source("tokyo_koto", name="江東区 公共喫煙所一覧", city="tokyo",
        url="https://catalog.data.metro.tokyo.lg.jp/dataset/t131083d0000000061", license="CC BY 4.0")
def tokyo_koto() -> list[dict]:
    out = []
    for kind, url in (("station", "https://www.opendata.metro.tokyo.lg.jp/koto/131083_237_public_smoking_area_station.csv"),
                      ("park", "https://www.opendata.metro.tokyo.lg.jp/koto/131083_237_public_smoking_area_park.csv")):
        rows = list(csv.DictReader(io.StringIO(decode(fetch(url)))))
        for i, r in enumerate(rows):
            out.append(area(source="tokyo_koto", local_id=f"{kind}{i}", name=r["喫煙所名"],
                            lat=float(r["緯度"]), lon=float(r["経度"]),
                            address=(r.get("場所") or None), kind="public"))
    return out


@source("tokyo_taito", name="台東区 公衆喫煙所（区設置分）", city="tokyo",
        url="https://www.city.taito.lg.jp/kusei/online/opendata/seikatu/shisethutizujouhou.html", license="CC BY 4.0")
def tokyo_taito() -> list[dict]:
    base = "https://www.city.taito.lg.jp/kusei/online/opendata/seikatu/"
    page = decode(fetch(base + "shisethutizujouhou.html"))
    m = re.search(r'href="([^"]*koshukitsuenjo[^"]*\.csv)"', page)
    if not m:
        raise RuntimeError("CSV link not found")
    rows = list(csv.DictReader(io.StringIO(decode(fetch(urllib.parse.urljoin(base, m.group(1)))))))
    out = []
    for r in rows:
        hours = r.get("利用開始時間")
        if hours and r.get("利用終了時間") and r["利用終了時間"] != hours:
            hours = f"{hours}～{r['利用終了時間']}"
        out.append(area(source="tokyo_taito", local_id=r["#"], name=r["名称"],
                        lat=float(r["緯度"]), lon=float(r["経度"]),
                        address=r.get("設置位置") or None, hours=hours or None,
                        kind="public", note=r.get("特記事項") or None))
    return out


@source("tokyo_chiyoda", name="千代田区 無料喫煙所（公衆喫煙所）", city="tokyo",
        url="https://www.city.chiyoda.lg.jp/koho/machizukuri/sekatsu/jore/muryokitsuenjo.html",
        license="千代田区ホームページ掲載情報")
def tokyo_chiyoda() -> list[dict]:
    url = SOURCES["tokyo_chiyoda"]["meta"]["url"]
    page = decode(fetch(url))
    out = []
    blocks = re.split(r"<h3[^>]*>", page)[1:]
    for i, b in enumerate(blocks):
        name = text_of(b.split("</h3>")[0])
        body = text_of(b.split("</h3>", 1)[1].split("<h", 1)[0])
        m_addr = re.search(r"設置場所：([^\n]+)", body)
        if not m_addr:
            continue
        m_hours = re.search(r"開放時間：([^\n]+)", body)
        addr = m_addr.group(1).strip()
        pos = geocode(normalise_address(addr, "東京都千代田区"), "千代田区")
        if not pos:
            print(f"   [chiyoda] not geocoded: {name} / {addr}", file=sys.stderr)
            continue
        out.append(area(source="tokyo_chiyoda", local_id=str(i), name=name, lat=pos[0], lon=pos[1],
                        address="千代田区" + addr.removeprefix("千代田区"),
                        hours=m_hours.group(1).strip() if m_hours else None,
                        kind="public", geocoded=True))
    return out


@source("tokyo_shinjuku", name="新宿区 公衆喫煙所", city="tokyo",
        url="https://www.city.shinjuku.lg.jp/seikatsu/file11_01_00003.html", license="新宿区ホームページ掲載情報")
def tokyo_shinjuku() -> list[dict]:
    page = decode(fetch(SOURCES["tokyo_shinjuku"]["meta"]["url"]))
    txt = text_of(page)
    out = []
    for i, m in enumerate(re.finditer(r"(\S+公衆喫煙所)\s+([^\n（]*?)（([^）]+番[^）]*)）", txt)):
        name, place, addr = m.groups()
        pos = geocode(normalise_address(addr, "東京都新宿区"), "新宿区")
        if not pos:
            print(f"   [shinjuku] not geocoded: {name} / {addr}", file=sys.stderr)
            continue
        out.append(area(source="tokyo_shinjuku", local_id=str(i), name=name, lat=pos[0], lon=pos[1],
                        address=f"新宿区{addr}", kind="public", geocoded=True,
                        note=place.strip() or None))
    return out


@source("tokyo_shibuya", name="渋谷区 区内公共喫煙所一覧", city="tokyo",
        url="https://www.city.shibuya.tokyo.jp/kankyo/machi-seiso/kitsuen/smokingplace.html",
        license="渋谷区ホームページ掲載情報")
def tokyo_shibuya() -> list[dict]:
    page = decode(fetch(SOURCES["tokyo_shibuya"]["meta"]["url"]))
    out = []
    # entries are list items: 「名前（住所）:時間」
    items = re.findall(r"<li[^>]*>(.*?)</li>", page, re.S)
    for i, it in enumerate(items):
        t = text_of(it)
        # 「名前（住所）[階数]:時間」
        m = re.match(r"^(.+?)（\s*([^（）]*?\d[^（）]*?)\s*）\s*([^:：]*?)\s*[:：]\s*(.+)$", t, re.S)
        if not m:
            continue
        name, addr, floors, hours = (s.strip() for s in m.groups())
        if floors:
            name = f"{name} {floors}"
        pos = geocode(normalise_address(addr, "東京都渋谷区"), "渋谷区")
        if not pos:
            print(f"   [shibuya] not geocoded: {name} / {addr}", file=sys.stderr)
            continue
        out.append(area(source="tokyo_shibuya", local_id=str(i), name=name, lat=pos[0], lon=pos[1],
                        address=f"渋谷区{addr}", hours=hours, kind="public", geocoded=True))
    return out


@source("tokyo_toshima", name="豊島区 区指定喫煙所", city="tokyo",
        url="https://www.city.toshima.lg.jp/152/machizukuri/sumai/bika/taisaku/025701.html",
        license="豊島区ホームページ掲載情報")
def tokyo_toshima() -> list[dict]:
    page = decode(fetch(SOURCES["tokyo_toshima"]["meta"]["url"]))
    txt = text_of(page)
    out = []
    pattern = r"\d+\.\s*([^\n]+?)\s*(?:\n[^\n]*?)*?\n?\s*住所：\s*([^\n]+?)\s*(?:\n\s*運営日：[^\n]*)?\s*\n?\s*時間：\s*([^\n]+)"
    for i, m in enumerate(re.finditer(pattern, txt)):
        name, addr, hours = (s.strip() for s in m.groups())
        note = None
        if "※" in name:
            name, note = (s.strip() for s in name.split("※", 1))
        pos = geocode(normalise_address(addr, "東京都豊島区"), "豊島区")
        if not pos:
            print(f"   [toshima] not geocoded: {name} / {addr}", file=sys.stderr)
            continue
        out.append(area(source="tokyo_toshima", local_id=str(i), name=name, lat=pos[0], lon=pos[1],
                        address=addr, hours=hours, kind="public", geocoded=True, note=note))
    return out


@source("osaka", name="大阪市 大阪市指定喫煙所", city="osaka",
        url="https://www.city.osaka.lg.jp/kankyo/page/0000607135.html", license="大阪市ホームページ掲載情報")
def osaka() -> list[dict]:
    page = decode(fetch(SOURCES["osaka"]["meta"]["url"]))
    out = []
    # Split into <h3> sections; only "大阪市指定喫煙所" (free, open to everybody).
    sections = re.split(r"<h3>", page)[1:]
    idx = 0
    for sec in sections:
        title = text_of(sec.split("</h3>")[0])
        if title != "大阪市指定喫煙所":
            continue
        body = sec.split("</h3>", 1)[1]
        # one <ul class="ul_type01"><li>NAME</li></ul> per smoking area,
        # followed by its details until the next list
        for chunk in body.split('<ul class="ul_type01">')[1:]:
            li = re.search(r"<li>(.*?)</li>", chunk, re.S)
            if not li:
                continue
            name = text_of(li.group(1))
            p = chunk[li.end():]
            info = text_of(p)
            addr_m = re.search(r"所在地：\s*([^\n]+)", info)
            if not addr_m:
                continue
            hours_m = re.search(r"供用時間：\s*([^\n]+)", info)
            type_m = re.search(r"喫煙所.?形態：\s*([^\n]+)", info)
            link = re.search(r"mpx=([\d.]+)&amp;mpy=([\d.]+)", p)
            geocoded = False
            if link:
                lon, lat = float(link.group(1)), float(link.group(2))
            elif addr_m.group(1).startswith("大阪市"):
                pos = geocode(normalise_address(addr_m.group(1), "大阪府"), "大阪市")
                if not pos:
                    print(f"   [osaka] not geocoded: {name}", file=sys.stderr)
                    continue
                (lat, lon), geocoded = pos, True
            else:
                print(f"   [osaka] no position: {name} / {addr_m.group(1)}", file=sys.stderr)
                continue
            idx += 1
            out.append(area(source="osaka", local_id=str(idx), name=name, lat=lat, lon=lon,
                            address=addr_m.group(1).strip(),
                            hours=hours_m.group(1).strip() if hours_m else None,
                            kind=type_m.group(1).strip() if type_m else "public",
                            geocoded=geocoded))
    return out


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main(only: list[str]) -> int:
    global _geocode_cache
    if GEOCODE_CACHE.exists():
        _geocode_cache = json.loads(GEOCODE_CACHE.read_text(encoding="utf-8"))
    previous = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {"sources": [], "areas": []}
    prev_by_source: dict[str, list[dict]] = {}
    for a in previous["areas"]:
        prev_by_source.setdefault(a["source"], []).append(a)
    prev_meta = {s["id"]: s for s in previous["sources"]}

    all_areas: list[dict] = []
    metas = []
    failures = 0
    today = dt.date.today().isoformat()
    for key, src in SOURCES.items():
        meta = dict(src["meta"])
        if only and key not in only:
            all_areas += prev_by_source.get(key, [])
            if key in prev_meta:
                metas.append(prev_meta[key])
            continue
        try:
            items = merge_same_location(src["fn"]())
            if not items:
                raise RuntimeError("no entries parsed")
            meta["fetched"] = today
            meta["count"] = len(items)
            print(f"{key:16s} {len(items):4d} entries")
            all_areas += items
        except Exception as e:  # noqa: BLE001
            failures += 1
            kept = prev_by_source.get(key, [])
            print(f"{key:16s} FAILED ({e}); keeping {len(kept)} previous entries", file=sys.stderr)
            all_areas += kept
            meta = prev_meta.get(key, meta)
        metas.append(meta)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"generated": today, "sources": metas, "areas": all_areas},
                              ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    GEOCODE_CACHE.write_text(json.dumps(_geocode_cache, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
                             encoding="utf-8")
    print(f"wrote {len(all_areas)} areas to {OUT.relative_to(ROOT)}")
    return 1 if failures == len(SOURCES) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
