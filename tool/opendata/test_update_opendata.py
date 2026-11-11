"""Unit tests for the id handling of update_opendata.py (stdlib only).

Run: python3 -m unittest discover -s tool/opendata -p 'test_*.py'
"""

import importlib.util
import pathlib
import unittest

_spec = importlib.util.spec_from_file_location(
    "update_opendata", pathlib.Path(__file__).with_name("update_opendata.py"))
uo = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(uo)


def entry(id_, name, lat, lon, **kw):
    return {"id": id_, "source": id_.split(":")[0], "name": name, "lat": lat, "lon": lon, **kw}


class StableKeyTest(unittest.TestCase):
    def test_independent_of_row_order_and_whitespace(self):
        self.assertEqual(uo.stable_key("新宿駅東口", "新宿三丁目38番先"),
                         uo.stable_key("新宿駅東口 ", "新宿三丁目38番先"))
        self.assertNotEqual(uo.stable_key("A", "x"), uo.stable_key("B", "x"))

    def test_full_width_digits_are_normalised(self):
        self.assertEqual(uo.stable_key("大供第２公園"), uo.stable_key("大供第2公園"))


class UniqueIdsTest(unittest.TestCase):
    def test_collisions_get_a_suffix_in_stable_order(self):
        items = [entry("s:h1", "A", 35.2, 139), entry("s:h1", "A", 35.1, 139)]
        uo.assign_unique_ids(items)
        self.assertEqual({a["id"] for a in items}, {"s:h1", "s:h1-2"})
        # the southern one (lower lat) keeps the plain id regardless of input order
        self.assertEqual(next(a for a in items if a["lat"] == 35.1)["id"], "s:h1")


class CarryAliasesTest(unittest.TestCase):
    def test_old_positional_id_becomes_alias(self):
        prev = [entry("s:0", "Park", 35.0, 139.0)]
        new = [entry("s:habc", "Park", 35.0, 139.0)]
        uo.carry_aliases(new, prev)
        self.assertEqual(new[0]["aliases"], ["s:0"])

    def test_reordered_list_maps_by_place_not_by_row(self):
        prev = [entry("s:0", "A", 35.0, 139.0), entry("s:1", "B", 35.01, 139.0)]
        new = [entry("s:hb", "B", 35.01, 139.0), entry("s:ha", "A", 35.0, 139.0)]
        uo.carry_aliases(new, prev)
        by_name = {a["name"]: a for a in new}
        self.assertEqual(by_name["A"]["aliases"], ["s:0"])
        self.assertEqual(by_name["B"]["aliases"], ["s:1"])

    def test_aliases_accumulate_and_unchanged_ids_keep_them(self):
        prev = [entry("s:h2", "Park", 35.0, 139.0, aliases=["s:0", "s:h1"])]
        new = [entry("s:h2", "Park", 35.0, 139.0)]
        uo.carry_aliases(new, prev)
        self.assertEqual(new[0]["aliases"], ["s:0", "s:h1"])

    def test_renamed_entry_at_same_spot_is_matched(self):
        prev = [entry("s:0", "Alter Name", 35.0, 139.0)]
        new = [entry("s:hx", "Neuer Name", 35.00001, 139.0)]
        uo.carry_aliases(new, prev)
        self.assertEqual(new[0]["aliases"], ["s:0"])

    def test_different_category_is_not_matched(self):
        prev = [entry("s:0", "WC", 35.0, 139.0, category="toilet")]
        new = [entry("s:hx", "Raucherecke", 35.0, 139.0)]
        uo.carry_aliases(new, prev)
        self.assertNotIn("aliases", new[0])

    def test_distant_entry_is_not_matched(self):
        prev = [entry("s:0", "Park", 35.0, 139.0)]
        new = [entry("s:hx", "Park", 35.01, 139.0)]  # ~1.1 km away
        uo.carry_aliases(new, prev)
        self.assertNotIn("aliases", new[0])


class SameLocationTest(unittest.TestCase):
    def test_merged_rooms_keep_their_ids(self):
        items = [entry("s:a", "1F", 35.0, 139.0), entry("s:b", "2F", 35.0, 139.0)]
        merged = uo.merge_same_location(items)
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["aliases"], ["s:b"])


if __name__ == "__main__":
    unittest.main()
