# Ippuku 🗾

Flutter app for **iOS and Android** that shows public smoking areas (喫煙所)
and public toilets (公衆トイレ) in all major Japanese cities on a map and sends a
**push notification** as soon as you get close to a smoking area (default
**30 m**, configurable) –
even while the app runs in the background.

The app's user interface is in English.

## Features

- Google Maps base map with clustered markers, a details view (indoor /
  outdoor, covered, fee, opening hours, operator, access; for toilets
  wheelchair access and baby changing table) and walking directions via Apple
  Maps / Google Maps.
- Three categories, visually distinct: **smoking areas in green** (darker
  green for smoking rooms), **public toilets in blue** with a WC icon and
  **trash cans in orange** (reported by users only). Each
  category has its own coloured cluster layer and a filter chip to show or
  hide it. Marker rings show the origin: gold = official list, pink =
  reported by a user. The status banner shows the nearest smoking area and
  the nearest toilet. A **legend** (menu ⋮ → Legend) explains every symbol
  with one sentence; it uses the same marker widgets as the map
  (`SpotMarker`, `ClusterBubble` in `lib/ui/spot_style.dart`).
- 55 cities / metropolitan areas: Tokyo (23 wards + Tama), all 20 designated
  cities (政令指定都市) and all remaining prefectural capitals or large cities
  (Naha, Kanazawa, Nara, Kagoshima, Nagasaki …) – see `lib/data/cities.dart`.
- Location dot with a **direction cone** like in map apps: compass heading
  from the fused rotation sensor (works lying flat and held upright like a
  camera), corrected to true north for Japan; GPS course as fallback while
  walking. The sensor is paused in the background.
- Automatic city selection based on your location, manual selection with
  search – including quick jumps to popular districts (Shinjuku, Shibuya,
  Ikebukuro, Akihabara, Kanda, Ueno, Asakusa, Ginza, Umeda, Namba, Gion …).
- Proximity alert as a local push notification, radius configurable in
  *Settings* (10–150 m, default 30 m; smoking areas only –
  toilets are far too dense for alerts)
  - hysteresis (a new alert only after moving twice the radius away, at
    least radius + 30 m) and a 30 min
    cooldown per smoking area, so GPS jitter does not cause a flood of alerts
  - inaccurate location fixes (accuracy > 50 m) are ignored
  - tapping the notification opens the smoking area on the map
- Offline cache per city (7 days), falling back to stored data without a
  network connection.
- Community features: report spots, add photos, rate spots and vote on
  whether a spot still exists (see below).

## Supported cities

All 55 cities / metropolitan areas below are covered with **OpenStreetMap
data for both categories** (smoking areas and public toilets, loaded live per
city and cached on the device). The download area of each city is a radius
around its centre, defined in `lib/data/cities.dart`.

| Region | Cities |
|---|---|
| Kantō | Tokyo (23 wards), Tokyo Tama (Hachiōji / Tachikawa), Yokohama, Kawasaki, Sagamihara, Saitama, Chiba, Utsunomiya, Maebashi / Takasaki, Mito |
| Hokkaidō / Tōhoku | Sapporo, Sendai, Aomori, Morioka, Akita, Yamagata, Fukushima / Kōriyama |
| Chūbu | Nagoya, Niigata, Shizuoka, Hamamatsu, Kanazawa, Toyama, Fukui, Kōfu, Nagano / Matsumoto, Gifu |
| Kansai | Osaka, Sakai, Kyoto, Kobe, Himeji, Nara, Ōtsu, Wakayama, Tsu / Yokkaichi |
| Chūgoku / Shikoku | Hiroshima, Okayama, Matsue, Tottori, Yamaguchi / Shimonoseki, Takamatsu, Matsuyama, Tokushima, Kōchi |
| Kyūshū / Okinawa | Fukuoka, Kitakyūshū, Kumamoto, Kagoshima, Nagasaki, Ōita / Beppu, Miyazaki, Saga, Naha |

**Additional official municipal data** (bundled snapshot, merged with OSM):

| City | Smoking areas | Public toilets |
|---|---|---|
| Tokyo | wards Chiyoda (Akihabara, Kanda), Shinjuku, Shibuya, Toshima (Ikebukuro), Taitō (Ueno, Asakusa), Kōtō | wards Chiyoda, Chūō, Shinjuku, Taitō, Sumida, Kōtō, Meguro, Suginami, Toshima, Arakawa, Itabashi, Nerima, Katsushika, Edogawa |
| Kyoto | ✔ city facility list | ✔ city facility list |
| Osaka | ✔ 大阪市指定喫煙所 | – (OSM only) |
| Okayama | – (OSM only) | ✔ city dataset 公衆トイレ (downloaded manually from within Japan) |
| all other cities | – (OSM only) | – (OSM only) |

Districts with a quick jump in the city picker: Shinjuku, Shibuya, Ikebukuro,
Akihabara, Kanda, Jimbōchō / Kudanshita, Tokyo Station / Marunouchi, Ueno,
Asakusa, Ginza, Shimbashi, Roppongi, Harajuku / Omotesandō, Ebisu,
Takadanobaba, Shinagawa, Kameido / Tōyōchō (Tokyo); Umeda, Namba / Dōtonbori,
Shinsaibashi, Tennōji, Shin-Ōsaka (Osaka); Kyoto Station, Kawaramachi / Gion,
Kiyomizu-dera (Kyoto); Okayama Station, Omotechō (Okayama).

To add a city, add an entry to `kCities` (centre + radius); OSM data then
works automatically. Official data needs a source in
`tool/opendata/update_opendata.py`.

## Data sources

| Source | Area | Access | Licence |
|---|---|---|---|
| **OpenStreetMap** via the public **Overpass API** – `amenity=smoking_area`, `amenity=smoking_room`, `smoking=dedicated`, and `amenity=toilets` without `access=private/no/customers/permit` | all covered cities | weekly export by CI (`tool/opendata/update_osm.py`), bundled with every app build (`use_published_osm.py`) and updated in the app like the official data | ODbL |
| City of Kyoto – open data portal, dataset “施設情報一覧”, category 喫煙場所 | Kyoto | snapshot | CC BY 4.0 |
| City of Osaka – list of 大阪市指定喫煙所 (coordinates taken from the GIS links) | Osaka | snapshot | published by the city |
| Tokyo, Kōtō ward – open data “公共喫煙所一覧” | Kameido, Tōyōchō, Shin-Kiba … | snapshot | CC BY 4.0 |
| Tokyo, Taitō ward – open data “公衆喫煙所（区設置分）” | Ueno, Asakusa … | snapshot | CC BY 4.0 |
| Tokyo, Chiyoda ward – “無料喫煙所（公衆喫煙所）のご案内” | **Akihabara, Kanda**, Jimbōchō, Iidabashi … | snapshot, geocoded | published by the ward |
| Tokyo, Shinjuku ward – “公衆喫煙所” | **Shinjuku**, Takadanobaba … | snapshot, geocoded | published by the ward |
| Tokyo, Shibuya ward – “区内公共喫煙所一覧” | **Shibuya**, Harajuku, Ebisu … | snapshot, geocoded | published by the ward |
| Tokyo, Toshima ward – “区指定喫煙所” | **Ikebukuro**, Ōtsuka | snapshot, geocoded | published by the ward |
| Kyoto – same facility list, category 公衆トイレ／観光トイレ | Kyoto (136 toilets) | snapshot | CC BY 4.0 |
| City of Okayama – 公衆トイレ, おかやま全県統合型GIS (only reachable from within Japan, so kept in `tool/opendata/manual/`) | Okayama (156 toilets) | manual snapshot | CC BY |
| Tokyo wards – national standard dataset “公衆トイレ一覧” of Chiyoda, Chūō, Shinjuku, Taitō, Sumida, Kōtō, Meguro, Suginami, Toshima, Arakawa, Itabashi, Nerima, Katsushika, Edogawa (URLs resolved via the Tokyo catalog API) | Tokyo (≈ 1,950 toilets) | snapshot | CC BY 4.0 |
| GSI (国土地理院) address search | geocoding of the address lists | when building the snapshot | – |
| Google Maps (base map only, Maps SDK for Android/iOS) | – | live | Google Maps Platform terms |

Where no official data is available the app shows the OSM data:

- **Okayama** publishes no machine-readable list of smoking areas (only the
  outline of its no-smoking zone). Its public-toilet dataset is served by a
  GIS that refuses connections from abroad; it is therefore downloaded
  manually from within Japan (`tool/opendata/manual/README.md`) and not
  refreshed by CI.
- **Osaka**: no official public-toilet dataset found.
- **Tokyo**: Shibuya and Minato publish no current toilet dataset, Shinagawa's
  file no longer exists and Nakano's server refuses connections from abroad.

### Official data (snapshot)

The cities publish their lists in very different formats (CSV, HTML pages,
form-based downloads, some with addresses only). Therefore
`tool/opendata/update_opendata.py` normalises them into
`assets/opendata/official_smoking_areas.json`, which ships with the app. The
pipeline refreshes the snapshot before every build; locally:

```bash
python3 tool/opendata/update_opendata.py             # all sources
python3 tool/opendata/update_opendata.py osaka kyoto # selected sources only
```

If a source fails, its previous entries are kept. Addresses without
coordinates are geocoded with the GSI address search (cache:
`tool/opendata/geocode_cache.json`) and marked as “approximate” in the app.

### Data updates without an app release

- The official snapshot is also published as assets of the GitHub release
  with tag [`opendata`](https://github.com/c0deltin/smokingareas/releases/tag/opendata):
  `opendata-manifest.json` (format, version, entry count, sha256) and
  `official_smoking_areas.json.gz` (~100 KB).
- `.github/workflows/opendata.yml` refreshes it **weekly** (and on demand);
  every app release refreshes it too. The data version (`generated`) only
  changes when entries actually changed. Each run starts from the last
  published snapshot so ids and aliases stay continuous.
- The app checks the manifest at most **once a day** at start and on
  **Reload**, downloads the snapshot only if it is newer, validates it
  (format, gzip, JSON, entry count, no drop below 50 %), stores it locally and
  shows it without a restart. The bundled snapshot is used when no download
  exists or when it is newer (after an app update).
- Privacy: this is a plain download from GitHub; no user data is sent.
- Snapshot `format` is versioned; apps ignore formats they do not
  understand.

### One map, all data

Users never choose a data source: all sources are merged into a single data
set for the whole of Japan. On start-up the official data and every city
already stored on the device are visible immediately; OSM data for the current
city is added in the background. Selecting a city or district only changes the
map section (zoom).

### No duplicate markers

- Entries are only ever merged within the same category – a toilet never
  absorbs a smoking area next to it.
- Several smoking rooms in the same building (same address) are already
  combined into one entry in the snapshot.
- When a city is loaded, every official entry is merged with at most one OSM
  point (closest pair first; radius 25 m for exact and 50 m for geocoded
  coordinates). The resulting marker uses the city's name, address and
  opening hours, the OSM attributes and – for geocoded addresses – the more
  precise OSM position.
- **User reports that later appear in official or OSM data** (same
  category, ≤ 25 m, 1:1 closest first) are absorbed: the official/OSM entry
  stays the base (name, position, gold/white ring), the user's details only
  fill gaps, a user-placed position beats a geocoded address, and the report
  id becomes an alias – ratings, photos, "gone" votes and closures move
  along. If the reporter answered "No, report new" to "Already on the map?"
  (asked within the same 25 m), the report is never merged with that place.
- Official entries have a gold ring; the details view links to the city's
  page and to the OSM entry.

## Community (report spots, photos, ratings)

- **Report a spot:** “Report” button → choose *smoking area*, *public
  toilet* or *trash can* → move the map until the cross hair is on the spot
  → name, type (outdoor / smoking room) and covered for smoking areas,
  wheelchair access and baby changing table for toilets, accepted waste
  (general waste, cans, PET bottles – OSM `waste=*`) for trash cans, note
  and optionally a photo. A “publicly accessible” checkbox (no ticket,
  entrance fee or purchase required); if unchecked – e.g. on a station
  platform or inside a sight – the access can be described (stored using the
  OSM schema `access=customers` + `access:note`). If a spot of the same
  category already exists within 20 m, the app offers it instead of creating
  a duplicate. Reported spots have a pink ring.
- **Ratings:** 1–5 stars plus a comment, one rating per user and spot (a new
  rating replaces the old one).
- **Photos:** camera or gallery, for every spot (including official and OSM
  spots).
- **“Does it still exist?” (like Waze):** yes/no per user; only a user's
  latest vote counts. A spot is hidden (from the map **and** the proximity
  alert) once at least 3 users say “no” and the “no” votes are at least
  twice the “yes” votes (`ExistencePolicy`).
- **The community overrides the data sets.** Official and OSM entries carry
  a fingerprint of their source data; every vote and closure report stores
  the fingerprint it was made for. A spot reported gone therefore stays
  hidden even if the next data update still lists it – until the city (or
  OSM) changes that entry, which restarts the evaluation. Votes without a
  data version (user-reported spots, older app versions) expire after 180
  days.
- **Temporarily closed (like a Waze report):** users can report a spot as
  temporarily closed (optional reason and expected end date) or as reopened.
  A report expires after 14 days, or at its end date (max. 180 days); only a
  user's latest report counts and the majority wins (newest report on a tie,
  `ClosurePolicy`). Closed spots stay on the map in grey with a pause badge,
  show a banner in the details view and are excluded from proximity alerts and the
  nearest-spot banner. Official entries flagged as closed (e.g. Okayama's
  「工事中のため、休止中」) are shown the same way and can be reopened by the
  community; such an "open again" report holds until the official entry
  changes. A "closed" report on an officially open spot always expires
  (temporary by nature – use "gone" for permanent removal).
- **Accounts:** the app can be used without an account. Contributing (report,
  rate, photo, vote, closure) needs Sign in with Apple (iPhone) or Google;
  the app asks once after installation, when someone contributes, or via
  Settings → Account (also sign out and delete account). Only the first name
  is shown with contributions.

### Architecture: adapters

```
lib/community/
  models.dart              UserProfile, CommunitySpot, SpotReview, SpotPhoto, ExistenceVote
  existence_policy.dart    Waze-like rule (pure, tested)
  community_backend.dart   CommunityBackend (adapter)
                             └ LocalCommunityBackend  → JSON "database" on the device
  photo_storage.dart       PhotoStorage → LocalPhotoStorage (files in the app folder)
  auth_service.dart        AuthService  → LocalAuthService (local profiles)
  server_backend.dart      server adapters: data, sign-in, photos (re-encoded
                           JPEG without metadata)
  server_rows.dart         mapping to the server tables (pure, tested)
  community_service.dart   facade for the UI; feeds community spots and hidden
                           spots into the single data set
```

Release builds use the server adapters when the build gets the server
settings (`--dart-define`, see "Backend"); development builds without them
use the local adapters with local profiles (`<app support>/community/db.json`),
so the multi-user rules can be tried on one device. UI and logic are the same
for both.

Votes, ratings and photos are attached to the id of the displayed spot. If an
OSM point is later merged with official data, the data collected under the
OSM id is still taken into account.

## Architecture

```
lib/
  main.dart                          app start-up and wiring
  data/cities.dart                   covered cities (centre + radius)
  data/districts.dart                popular districts for quick jumps
  models/                            SmokingArea, City, GeoBounds
  sources/
    osm_snapshot_source.dart         weekly OSM export (downloaded)
    overpass_source.dart             OSM/Overpass parser + live fallback
    official_opendata_source.dart    bundled official snapshot
  services/
    smoking_area_repository.dart     loading, merging, de-duplication, file cache
    proximity_detector.dart          pure proximity logic (tested)
    proximity_monitor.dart           location stream (also in background) → alert
    notification_service.dart        local push notifications
  community/                         community features (see above)
  ui/                                map, city picker, details, report, profile
tool/opendata/                       importer for the official data
```

## Getting started

```bash
flutter pub get
flutter test
flutter run            # Android device or iOS simulator/device
```

iOS: `cd ios && pod install` is run automatically by `flutter run`. For a
physical iPhone a signing team has to be set in Xcode.

## APK download & CI

On every push to `main` the GitHub Actions pipeline
(`.github/workflows/android-release.yml`) refreshes the official data, runs
analysis and tests, builds the app and publishes the APK as a **GitHub
Release** (`v1.0.<build number>`). Download: *Releases* → latest version →
open `ippuku-….apk` on the Android device and allow installation
from unknown sources. The pipeline can also be started manually (*Actions* →
*Run workflow*).

**Fixed signing key (recommended):** without it every APK is signed with a
different debug key, so an update can only be installed after uninstalling
the old version. It is also required for Google sign-in on Android.

*Without a computer:* create a fine-grained personal access token (GitHub →
Settings → Developer settings → Fine-grained tokens; only this repository;
permission *Secrets: Read and write*; short expiry), store it as repository
secret `SIGNING_SETUP_TOKEN` and run *Actions → Create Android signing key*.
The workflow creates the key on the runner, stores it as the secrets below
and shows only the public SHA-1/SHA-256 fingerprints in the run summary.
Delete the token and the secret afterwards. The key itself can never be read
back from GitHub – keep the secrets; replacing the key breaks updates.

*With a computer:* create it once:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias smokingareas
base64 -w0 release.jks   # store the output as a secret
```

and add it under *Settings → Secrets and variables → Actions*:

| Secret | Content |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64-encoded `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | e.g. `smokingareas` |
| `ANDROID_KEY_PASSWORD` | key password (empty = keystore password) |

## iOS via TestFlight

`.github/workflows/ios-testflight.yml` builds the app on a GitHub-hosted Mac
(free for public repositories) on every push to `main` and on demand, signs
it with Xcode **cloud signing** and uploads it to **TestFlight**; install it
with the TestFlight app. No certificate or provisioning profile has to be
created by hand.

One-time setup:

1. Apple Developer Program (paid). Register the App ID
   `de.c0deltin.smokingAreas` (explicit, no capabilities needed).
2. App Store Connect → Apps → New App (iOS, that bundle ID). The App Store
   listing (keywords, texts, screenshots) is **not** needed for TestFlight.
3. App Store Connect → Users and Access → Integrations → App Store Connect
   API → Team key with role **Admin** (needed for cloud signing); download
   the `.p8` once.
4. Repository secrets: `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`,
   `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` (full text of
   the `.p8`). Without them the workflow skips itself.
5. TestFlight → Internal Testing → add yourself. Internal testers need no
   App Review; builds expire after 90 days.

`ITSAppUsesNonExemptEncryption = false` (standard HTTPS only) avoids the
export-compliance question for every build.

Every build runs on a fresh Mac, where Xcode creates a new development
certificate for the archive. Apple limits their number, so the workflow first
revokes the ones earlier CI builds created (`tool/ios/revoke_ci_certificates.py`,
only certificates named "Created via API").

## Backend

Community data (reported spots, ratings, photos, votes, closure reports) is
stored in a hosted PostgreSQL backend. Using the app needs no account;
contributing needs Sign in with Apple or Google.

- Everyone can read; writes only as the signed-in account, with limits per
  hour; banned accounts can no longer write. Users can report content,
  block other users and delete their account in the app.
- Schema, access rules and their tests live in the repository and are
  tested on a plain PostgreSQL on every change; merges to `main` apply new
  schema versions automatically.

The app only ever uses public client credentials; administrative keys are
never part of the app or the repository.

Build settings (repository secrets, passed as `--dart-define`; without them
builds use local community data): `BACKEND_URL`, `BACKEND_ANON_KEY` (public
client key), `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`.

Sign-in setup:

- Apple Developer: enable *Sign in with Apple* for the App ID
  `de.c0deltin.smokingAreas` (the app's entitlement requests it).
- Google Cloud (same project as the Maps key): OAuth consent screen
  (external, published) and three OAuth clients – *Web* (used by the
  backend), *iOS* (bundle ID `de.c0deltin.smokingAreas`) and *Android*
  (package `de.c0deltin.smoking_areas`, SHA-1 of the release signing key).
- Backend auth settings: Apple and Google enabled with these client IDs
  (Google: all three, web first; *skip nonce checks* on for iOS); e-mail
  sign-up disabled.

## Google Maps API keys

The base map is Google Maps (Maps SDK for Android and iOS; map loads in
native apps are free). One-time setup in the Google Cloud console:

1. Create a project with a billing account (required by Google, even though
   the native map SDKs are free) and enable **Maps SDK for Android** and
   **Maps SDK for iOS**.
2. Create two API keys:
   - Android key: API restriction *Maps SDK for Android*; application
     restriction *Android apps* with package `de.c0deltin.smoking_areas` and
     the SHA-1 of the release signing key (needs the fixed signing key).
   - iOS key: API restriction *Maps SDK for iOS*; application restriction
     *iOS apps* with bundle ID `de.c0deltin.smokingAreas`.
3. Repository secrets `GOOGLE_MAPS_API_KEY_ANDROID` and
   `GOOGLE_MAPS_API_KEY_IOS`.

Local builds read the key from the environment variable `MAPS_API_KEY`
(Android) or from the uncommitted `ios/Flutter/Secrets.xcconfig`
(`MAPS_API_KEY = …`). Without a key the app runs but the map stays empty.

## Permissions & background operation

- **Android**: location (fine + background), foreground service (type
  `location`) with a persistent notification while the alert is active, and
  `POST_NOTIFICATIONS` (Android 13+). For alerts while the app is closed,
  “Allow all the time” must be selected in the system settings.
- **iOS**: `UIBackgroundModes = location`, descriptions for “While Using” and
  “Always”, plus camera and photo library descriptions for spot photos. Allow
  “Always” for background alerts.
- The alert can be switched on and off with the bell icon; when it is off, no
  background tracking takes place.

## Store listings

`store/` holds the prepared App Store and Google Play texts (English,
Japanese, German), privacy and age-rating answers, review notes and a
publishing checklist (`store/README.md`).

## Legal pages

`docs/` holds the privacy policy, terms of use and imprint, published with
GitHub Pages (Settings → Pages → *Deploy from a branch*, `main`, folder
`/docs`) at <https://c0deltin.github.io/smokingareas/>. The app links to them
in the sign-in sheet, Settings and Info (`lib/data/links.dart`); the account
deletion page (`docs/delete-account.md`) is required by Google Play. The
placeholders in `[BRACKETS]` must be filled in before publishing.

## Notes for publishing

- The public Overpass servers have a
  [usage policy](https://wiki.openstreetmap.org/wiki/Overpass_API#Public_Overpass_API_instances).
  Installed apps therefore do not query them: CI exports the OSM data once a
  week (a few requests with pauses) and publishes it with the data release
  (`osm_spots.json.gz` + `osm-manifest.json`).
- Android is currently **not distributed through the Play Store** but
  installed directly as an APK from the GitHub Releases (sideloading). Google
  Play Protect may show an “unknown app” warning on first installation –
  choose “Install anyway”.
- For a later store release, the App Store and Play Store require a
  justification for background location; the texts in `Info.plist` and the
  foreground service notification are prepared for that.
