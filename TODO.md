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

- [ ] **Server backend** for the community features: implement
  `RemoteCommunityBackend`, `PhotoStorage` and `AuthService` against a real
  server (login, one rating per user, Waze rules and rate limiting on the
  server, photos in object storage). Until then every device only sees its own
  reports.
- [ ] **Okayama official data** is a manual download
  (`tool/opendata/manual/`) because the GIS refuses connections from abroad;
  refresh it occasionally from within Japan.
- [ ] More official datasets: Osaka public toilets, Tokyo wards without data
  (Shibuya, Minato, Shinagawa, Nakano), further cities.

## App

- [ ] Opening a notification while the app was terminated does not jump to
  the smoking area yet (only works while the app is running).
- [ ] Measure map performance with all markers in Tokyo (≈ 2,600 official
  entries plus OSM smoking areas and toilets); consider viewport-based
  marker building if it stutters.
- [ ] Verify on a real device: live Overpass query incl. toilets, camera and
  gallery for photos, background location and proximity alerts (incl. the radius setting), direction cone
  (compass accuracy, flat vs. upright, map rotation) – on Android and iOS.

## Distribution

- [ ] Fixed Android signing key as GitHub secrets so updates install over the
  previous version (see README, "APK download & CI").
