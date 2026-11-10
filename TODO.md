# TODO

Open items and ideas collected during development. Move an item into a PR
when it is picked up and delete it here once it is merged.

## Community / data

- [ ] **Community always overrides official closure flags.** A "reopened"
  report on a spot that official data marks as temporarily closed currently
  expires after 14 days (like every closure report); afterwards the stale
  official flag applies again. Reports that contradict the official status
  should stay valid much longer (e.g. up to 180 days) and only lose their
  effect when the official dataset itself changes (new snapshot value). Same
  idea the other way round: a "closed" report on an officially open spot.
  Relevant code: `ClosurePolicy`, `CommunityService.annotate`.
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
- [ ] Public download links: the repository is private, so release downloads
  need a GitHub login; options are a public releases repository or Firebase
  App Distribution.
