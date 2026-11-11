# TODO

Open items and ideas collected during development. Move an item into a PR
when it is picked up and delete it here once it is merged.

## Community / data

Agreed order (data first, then the server):

1. ~~Stable ids for official entries~~ – done: content-based ids, former ids
   kept as `aliases` so community data stays attached.
2. [ ] **Merge user-reported spots with official/OSM entries.** When a
   reported spot later appears in official data or OSM (same category,
   ≤ ~25 m, 1:1 nearest first), the official/OSM entry becomes the base
   (name, position, origin), user details only fill gaps, and the community
   id is kept as alias so ratings, photos, votes and closures move along.
   Today only the official ↔ OSM merge keeps ids; a community spot next to
   an OSM point is dropped by the 8 m de-duplication.
3. [ ] **Bind community verdicts to the data version** (see below).
4. [ ] **Data updates without an app release.** The repository is public
   now, so the app can download a newer official snapshot from GitHub (e.g.
   a release asset or the raw file on `main`) on start and via "Neu laden",
   store it locally and fall back to the bundled one. Later served by the
   backend.

- [ ] **Community verdicts survive data updates (step 3).** The community
  must always win over the official "DB", which is only the baseline:
  - "gibt es nicht mehr": today the spot stays hidden while the votes are
    valid (180 days) and reappears afterwards if the official list still
    contains it. Instead the verdict should hold until the official entry
    itself changes (store a fingerprint of the entry with each vote; a
    changed entry restarts the evaluation).
  - "vorübergehend geschlossen / wieder offen": a report that contradicts the
    official status currently expires after 14 days, after which the stale
    official flag applies again. Such reports should likewise hold until the
    official entry changes.
  Relevant code: `ExistencePolicy`, `ClosurePolicy`, `CommunityService`.
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
  gallery for photos, background location and the 30 m alert, direction cone
  (compass accuracy, flat vs. upright, map rotation).

## Distribution

- [ ] Fixed Android signing key as GitHub secrets so updates install over the
  previous version (see README, "APK download & CI").
- [ ] iOS distribution: TestFlight pipeline (App Store Connect API key) or
  local install via Xcode.
