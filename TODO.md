# TODO

Open items and ideas collected during development. Move an item into a PR
when it is picked up and delete it here once it is merged.

## Community / data

Agreed order (data first, then the server):

1. ~~Stable ids for official entries~~ – done: content-based ids, former ids
   kept as `aliases` so community data stays attached.
2. ~~Merge user-reported spots with official/OSM entries~~ – done: reports
   are absorbed into official/OSM entries (≤ 25 m, same category, 1:1), the
   report id becomes an alias so community data moves along, and "No,
   report new" answers are respected.
3. ~~Bind community verdicts to the data version~~ – done: source-data
   fingerprints; verdicts for the current version never expire, a changed
   entry restarts the evaluation.
4. ~~Data updates without an app release~~ – done: weekly `opendata`
   release (manifest + gzip snapshot), checked by the app daily and on
   Reload, validated before use.

- [ ] **Before publishing:** paid backend plan (free
  projects pause after a week without traffic); fill in the placeholders of
  the legal pages (`docs/`), have them checked and enable GitHub Pages; App
  Store listing (texts, screenshots, privacy
  details, age rating, reason for "Always" location, review notes); decide
  Play Store vs. APK.
- [ ] **Okayama official data** is a manual download
  (`tool/opendata/manual/`) because the GIS refuses connections from abroad;
  refresh it occasionally from within Japan.
- [ ] More official datasets: Osaka public toilets, Tokyo wards without data
  (Shibuya, Minato, Shinagawa, Nakano), further cities.
- [ ] Trash cans from OSM (`amenity=waste_basket`, maybe `amenity=recycling`
  next to vending machines) – check data volume of the weekly export first.
- [ ] Japan-wide OSM export: the first runs ran out of time at the busy
  public Overpass servers; boxes without data are queried first, so the
  weekly runs complete it – check the log once (no missing boxes).

## App

- [ ] Measure map performance on a device with all of Tokyo visible
  (markers are clustered per visible region, but every camera stop
  recomputes the clusters).
- [ ] Google Maps: restrict the Android API key to the release SHA-1 (the
  fixed signing key exists now).
- [ ] Verify on a real device: Google sign-in (iOS + Android), OSM export incl. toilets, camera and
  gallery for photos, background location and proximity alerts (incl. the radius setting), direction cone
  (compass accuracy, flat vs. upright, map rotation) – on Android and iOS;
  battery use with the adaptive tracking, first install of the Japan tiles,
  offline contributions, trash-can badge and "Part of this smoking area?".

## Later

- [ ] **Translations:** the UI is available in English, German and Japanese
  (device language, English fallback) – have the German and Japanese texts
  checked by native speakers; more languages = one more ARB file. Some data
  fields are Japanese only (e.g. opening hours, notes and addresses of the
  official datasets) – translate or normalise them (opening hours into the
  OSM `opening_hours` format, shown localised).

- [ ] Native iOS look (Liquid Glass): native glass controls via platform
  views, or a separate SwiftUI app.
