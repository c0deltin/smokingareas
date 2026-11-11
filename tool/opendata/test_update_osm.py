import unittest
from datetime import datetime, timezone

import update_osm as osm


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
        q = osm.build_query([(35.6, 139.6, 35.7, 139.8)])
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

    def test_partial_results_are_refused(self):
        self.assertFalse(osm.plausible(0, None))
        self.assertTrue(osm.plausible(100, None))
        self.assertFalse(osm.plausible(70, {"count": 100}))
        self.assertTrue(osm.plausible(95, {"count": 100}))


if __name__ == "__main__":
    unittest.main()
