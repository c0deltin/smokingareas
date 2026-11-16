import math
import unittest
from datetime import datetime, timezone

import update_osm as osm
import use_published_osm as bundle


class OsmExportTest(unittest.TestCase):
    def test_city_bounds_from_dart(self):
        cities = osm.city_bounds(osm.CITIES.read_text(encoding="utf-8"))
        ids = [c for c, _ in cities]
        self.assertIn("tokyo", ids)
        self.assertGreater(len(cities), 50)
        s, w, n, e = dict(cities)["tokyo"]
        self.assertLess(s, 35.6812)
        self.assertGreater(n, 35.6812)
        self.assertAlmostEqual(n - s, 2 * 16 / 111.32, places=4)

    def test_query_covers_all_categories(self):
        q = osm.build_query((34, 132))
        self.assertIn("(34,132,36,134)", q)
        self.assertIn('"amenity"="toilets"', q)
        self.assertIn("smoking_area|smoking_room", q)
        self.assertIn('"smoking"="dedicated"', q)
        self.assertIn("out center tags;", q)

    def test_normalize(self):
        raw = [
            {"type": "node", "id": 2, "lat": 35.1234567, "lon": 139.1,
             "tags": {"amenity": "smoking_area", "name": "A", "source": "survey"}},
            {"type": "way", "id": 1, "center": {"lat": 35.2, "lon": 139.2},
             "tags": {"amenity": "toilets", "wheelchair": "yes"}},
            {"type": "node", "id": 2, "lat": 35.1234567, "lon": 139.1,
             "tags": {"amenity": "smoking_area"}},  # duplicate from 2nd bbox
            {"type": "relation", "id": 3, "tags": {}},  # no position
        ]
        out = osm.normalize(raw)
        self.assertEqual([(e["type"], e["id"]) for e in out], [("node", 2), ("way", 1)])
        self.assertEqual(out[0]["lat"], 35.123457)
        self.assertNotIn("source", out[0]["tags"])
        self.assertEqual(out[1]["lat"], 35.2)

    def test_version_only_changes_with_the_data(self):
        elements = osm.normalize([{"type": "node", "id": 1, "lat": 35, "lon": 139,
                                   "tags": {"amenity": "toilets"}}])
        t1 = datetime(2026, 11, 11, tzinfo=timezone.utc)
        t2 = datetime(2026, 11, 18, tzinfo=timezone.utc)
        _, first = osm.build(elements, None, t1)
        _, same = osm.build(elements, first, t2)
        self.assertEqual(same["generated"], first["generated"])
        changed = elements + [{"type": "node", "id": 5, "lat": 35, "lon": 139, "tags": {}}]
        _, newer = osm.build(changed, first, t2)
        self.assertGreater(newer["generated"], first["generated"])

    def test_busy_servers_are_retried(self):
        calls = []

        def fetch(url):
            calls.append(url)
            if len(calls) < 5:
                raise RuntimeError("HTTP Error 504: Gateway Timeout")
            return {"elements": [{"type": "node", "id": 1}]}

        pauses = []
        out = osm.overpass("q", sleep=pauses.append, fetch=fetch)
        self.assertEqual(out, [{"type": "node", "id": 1}])
        self.assertEqual(len(calls), 5)
        self.assertIn(osm.RETRY_PAUSE_SECONDS, pauses)

    def test_gives_up_after_all_retries(self):
        def fetch(url):
            raise RuntimeError("HTTP Error 504")

        with self.assertRaises(RuntimeError):
            osm.overpass("q", sleep=lambda s: None, fetch=fetch)

    def test_boxes_cover_japan(self):
        places = {
            "Yonaguni": (24.47, 123.0), "Naha": (26.21, 127.68),
            "Chichijima": (27.09, 142.19), "Amami": (28.38, 129.49),
            "Fukuoka": (33.59, 130.40), "Tsushima": (34.20, 129.29),
            "Kurashiki": (34.59, 133.77), "Tokyo": (35.68, 139.76),
            "Hachijo": (33.11, 139.79), "Oki": (36.21, 133.32),
            "Sendai": (38.27, 140.87), "Hakodate": (41.77, 140.73),
            "Sapporo": (43.06, 141.35), "Nemuro": (43.33, 145.58),
            "Wakkanai": (45.42, 141.67), "Shiretoko": (44.07, 145.0),
        }
        for name, (lat, lon) in places.items():
            box = (math.floor(lat / 2) * 2, math.floor(lon / 2) * 2)
            self.assertIn(box, osm.BOXES, name)
            self.assertTrue(osm.in_japan(lat, lon), name)
        self.assertEqual(len(set(osm.BOXES)), len(osm.BOXES))

    def test_neighbours_are_dropped(self):
        for name, (lat, lon) in {
            "Busan": (35.10, 129.04), "Jeju": (33.50, 126.53),
            "Ulsan": (35.54, 129.31), "Pohang": (36.02, 129.37),
            "Korsakov": (46.63, 142.78), "Kunashir": (44.02, 145.86),
        }.items():
            self.assertFalse(osm.in_japan(lat, lon), name)

    def test_failed_box_keeps_published_elements(self):
        calls = []

        def query(q):
            calls.append(q)
            if len(calls) == 2:  # second box fails
                raise RuntimeError("504")
            return [{"type": "node", "id": 1, "lat": 34.6, "lon": 135.5}]

        published = [
            {"type": "node", "id": 7, "lat": 35.68, "lon": 139.76, "p": "b34_138"},
            {"type": "node", "id": 8, "lat": 34.69, "lon": 135.50, "p": "b34_134"},
        ]
        old_pause = osm.PAUSE_SECONDS
        osm.PAUSE_SECONDS = 0
        try:
            raw, missing = osm.collect([(34, 134), (34, 138)], query, lambda: published)
        finally:
            osm.PAUSE_SECONDS = old_pause
        self.assertEqual([(e["id"], e["p"]) for e in raw], [(1, "b34_134"), (7, "b34_138")])
        self.assertEqual(missing, [])

    def test_failed_box_without_published_export_is_missing(self):
        calls = []

        def query(q):
            calls.append(q)
            if len(calls) == 1:
                raise RuntimeError("504")
            return [{"type": "node", "id": 1, "lat": 34.6, "lon": 133.7}]

        old_pause = osm.PAUSE_SECONDS
        osm.PAUSE_SECONDS = 0
        try:
            raw, missing = osm.collect([(42, 140), (34, 132)], query, lambda: [])
            self.assertEqual(missing, ["b42_140"])
            self.assertEqual([e["id"] for e in raw], [1])
            with self.assertRaises(RuntimeError):  # nothing worked at all
                osm.collect([(42, 140)], lambda q: (_ for _ in ()).throw(RuntimeError("504")),
                            lambda: [])
        finally:
            osm.PAUSE_SECONDS = old_pause

    def test_time_budget(self):
        t = [0.0]

        def query(q):
            t[0] += osm.DEADLINE_SECONDS + 1  # every query uses up the budget
            return [{"type": "node", "id": 1, "lat": 35.05, "lon": 139.05}]

        old_pause = osm.PAUSE_SECONDS
        osm.PAUSE_SECONDS = 0
        try:
            raw, missing = osm.collect([(34, 138), (34, 134)], query,
                                       lambda: [{"type": "node", "id": 9, "lat": 34.6,
                                                 "lon": 135.5, "p": "b34_134"}],
                                       clock=lambda: t[0])
        finally:
            osm.PAUSE_SECONDS = old_pause
        # first box queried, second over budget -> published elements kept
        self.assertEqual([e["id"] for e in raw], [1, 9])
        self.assertEqual(missing, [])

    def test_tiles_file_round_trip(self):
        elements = osm.normalize([
            {"type": "node", "id": 1, "lat": 35.68, "lon": 139.76, "p": "13",
             "tags": {"amenity": "toilets"}},
            {"type": "node", "id": 2, "lat": 34.59, "lon": 133.77, "p": "33",
             "tags": {"amenity": "smoking_area"}},
            {"type": "node", "id": 3, "lat": 35.10, "lon": 139.99, "p": "13", "tags": {}},
        ])
        snapshot, manifest = osm.build(elements, None,
                                       datetime(2026, 11, 16, tzinfo=timezone.utc),
                                       osm.TILES_FORMAT)
        text = osm.tiles_text(snapshot)
        lines = text.strip().split("\n")
        self.assertEqual(len(lines), 3)  # header + tiles 34_133 and 35_139
        self.assertTrue(lines[1].startswith("34_133\t"))
        self.assertTrue(lines[2].startswith("35_139\t"))
        header, back = osm.parse_tiles(text)
        self.assertEqual(header["format"], 2)
        self.assertEqual(header["count"], 3)
        self.assertEqual(sorted(e["id"] for e in back), [1, 2, 3])
        self.assertEqual(osm.tile_counts(elements), {"34_133": 1, "35_139": 2})
        self.assertEqual(manifest["format"], 2)

    def test_city_export_is_derived_from_japan(self):
        elements = [
            {"type": "node", "id": 1, "lat": 35.05, "lon": 139.05, "p": "13", "tags": {}},
            {"type": "node", "id": 2, "lat": 34.59, "lon": 133.77, "p": "33", "tags": {}},
        ]
        city = osm.city_elements(elements, [("a", (35.0, 139.0, 35.1, 139.1))])
        self.assertEqual(city, [{"type": "node", "id": 1, "lat": 35.05,
                                 "lon": 139.05, "tags": {}}])

    def test_normalize_keeps_the_first_prefecture(self):
        out = osm.normalize([
            {"type": "way", "id": 5, "center": {"lat": 35.5, "lon": 139.5}, "p": "13"},
            {"type": "way", "id": 5, "center": {"lat": 35.5, "lon": 139.5}, "p": "14"},
        ])
        self.assertEqual(out[0]["p"], "13")

    def test_bundle_only_takes_newer_exports(self):
        self.assertTrue(bundle.newer({"generated": "2026-11-12T00:00:00Z"}, None))
        self.assertTrue(bundle.newer({"generated": "2026-11-19T00:00:00Z"},
                                     {"generated": "2026-11-12T00:00:00Z"}))
        self.assertFalse(bundle.newer({"generated": "2026-11-12T00:00:00Z"},
                                      {"generated": "2026-11-12T00:00:00Z"}))

    def test_bundled_tiles_header(self):
        import gzip
        snapshot, _ = osm.build(osm.normalize([
            {"type": "node", "id": 1, "lat": 35.68, "lon": 139.76, "p": "13", "tags": {}}]),
            None, datetime(2026, 11, 16, tzinfo=timezone.utc), osm.TILES_FORMAT)
        gz = gzip.compress(osm.tiles_text(snapshot).encode())
        header = bundle.tiles_header(gz)
        self.assertEqual((header["format"], header["count"]), (2, 1))
        self.assertIsNone(bundle.tiles_header(b""))  # the placeholder

    def test_partial_results_are_refused(self):
        self.assertFalse(osm.plausible(0, None))
        self.assertTrue(osm.plausible(100, None))
        self.assertFalse(osm.plausible(70, {"count": 100}))
        self.assertTrue(osm.plausible(95, {"count": 100}))


if __name__ == "__main__":
    unittest.main()
