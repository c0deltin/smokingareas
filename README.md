# Raucherzonen Japan (Smoking Areas Japan) 🚬🗾

Flutter app for **iOS and Android** that shows public smoking areas (喫煙所) in
all major Japanese cities on a map and sends a **push notification** as soon as
you get within **30 m** of one – even while the app runs in the background.

The app's user interface is in German.

## Features

- Map (OpenStreetMap tiles) with clustered markers, a details view (indoor /
  outdoor, covered, fee, opening hours, operator, access) and walking
  directions via Apple Maps / Google Maps.
- 55 cities / metropolitan areas: Tokyo (23 wards + Tama), all 20 designated
  cities (政令指定都市) and all remaining prefectural capitals or large cities
  (Naha, Kanazawa, Nara, Kagoshima, Nagasaki …) – see `lib/data/cities.dart`.
- Automatic city selection based on your location, manual selection with
  search – including quick jumps to popular districts (Shinjuku, Shibuya,
  Ikebukuro, Akihabara, Kanda, Ueno, Asakusa, Ginza, Umeda, Namba, Gion …).
- 30 m proximity alert as a local push notification
  - hysteresis (a new alert only after moving > 60 m away) and a 30 min
    cooldown per smoking area, so GPS jitter does not cause a flood of alerts
  - inaccurate location fixes (accuracy > 50 m) are ignored
  - tapping the notification opens the smoking area on the map
- Offline cache per city (7 days), falling back to stored data without a
  network connection.
- Community features: report spots, add photos, rate spots and vote on
  whether a spot still exists (see below).

## Data sources

| Source | Area | Access | Licence |
|---|---|---|---|
| **OpenStreetMap** via the public **Overpass API** – `amenity=smoking_area`, `amenity=smoking_room`, `smoking=dedicated` | all of Japan | live in the app | ODbL |
| City of Kyoto – open data portal, dataset “施設情報一覧”, category 喫煙場所 | Kyoto | snapshot | CC BY 4.0 |
| City of Osaka – list of 大阪市指定喫煙所 (coordinates taken from the GIS links) | Osaka | snapshot | published by the city |
| Tokyo, Kōtō ward – open data “公共喫煙所一覧” | Kameido, Tōyōchō, Shin-Kiba … | snapshot | CC BY 4.0 |
| Tokyo, Taitō ward – open data “公衆喫煙所（区設置分）” | Ueno, Asakusa … | snapshot | CC BY 4.0 |
| Tokyo, Chiyoda ward – “無料喫煙所（公衆喫煙所）のご案内” | **Akihabara, Kanda**, Jimbōchō, Iidabashi … | snapshot, geocoded | published by the ward |
| Tokyo, Shinjuku ward – “公衆喫煙所” | **Shinjuku**, Takadanobaba … | snapshot, geocoded | published by the ward |
| Tokyo, Shibuya ward – “区内公共喫煙所一覧” | **Shibuya**, Harajuku, Ebisu … | snapshot, geocoded | published by the ward |
| Tokyo, Toshima ward – “区指定喫煙所” | **Ikebukuro**, Ōtsuka | snapshot, geocoded | published by the ward |
| GSI (国土地理院) address search | geocoding of the address lists | when building the snapshot | – |
| OpenStreetMap map tiles | – | live | ODbL |

**Okayama** does not publish a machine-readable list of smoking areas (only
the outline of its no-smoking zone) – there the app shows the OSM data.

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

### One map, all data

Users never choose a data source: all sources are merged into a single data
set for the whole of Japan. On start-up the official data and every city
already stored on the device are visible immediately; OSM data for the current
city is added in the background. Selecting a city or district only changes the
map section (zoom).

### No duplicate markers

- Several smoking rooms in the same building (same address) are already
  combined into one entry in the snapshot.
- When a city is loaded, every official entry is merged with at most one OSM
  point (closest pair first; radius 25 m for exact and 50 m for geocoded
  coordinates). The resulting marker uses the city's name, address and
  opening hours, the OSM attributes and – for geocoded addresses – the more
  precise OSM position.
- Official entries have a blue ring; the details view links to the city's
  page and to the OSM entry.

## Community (report spots, photos, ratings)

- **Report a spot:** “Report smoking area” button → move the map until the
  cross hair is on the spot → name, type (outdoor / smoking room), covered,
  note and optionally a photo. A “publicly accessible” checkbox (no ticket,
  entrance fee or purchase required); if unchecked – e.g. on a station
  platform or inside a sight – the access can be described (stored using the
  OSM schema `access=customers` + `access:note`). If a spot already exists
  within 20 m, the app offers it instead of creating a duplicate. Reported
  spots have orange markers.
- **Ratings:** 1–5 stars plus a comment, one rating per user and spot (a new
  rating replaces the old one).
- **Photos:** camera or gallery, for every spot (including official and OSM
  spots).
- **“Does it still exist?” (like Waze):** yes/no per user; only a user's
  latest vote counts and votes older than 180 days expire. A spot is hidden
  (from the map **and** the 30 m alert) once at least 3 users say “no” and the
  “no” votes are at least twice the “yes” votes (`ExistencePolicy`).
- **Multiple users:** every record carries the `userId` of its author. Until a
  server exists there are local profiles (profile icon at the top right) to
  try out the multi-user rules on a single device.

### Architecture: adapters, everything local for now

```
lib/community/
  models.dart              UserProfile, CommunitySpot, SpotReview, SpotPhoto, ExistenceVote
  existence_policy.dart    Waze-like rule (pure, tested)
  community_backend.dart   CommunityBackend (adapter)
                             ├ LocalCommunityBackend  → JSON "database" on the device
                             └ RemoteCommunityBackend → stub for the future server
  photo_storage.dart       PhotoStorage → LocalPhotoStorage (files in the app folder)
  auth_service.dart        AuthService  → LocalAuthService (local profiles)
  community_service.dart   facade for the UI; feeds community spots and hidden
                           spots into the single data set
```

The local database (`<app support>/community/db.json`) is structured like a
multi-user database (tables `users`, `spots`, `reviews`, `photos`, `votes`).
For a real server, `RemoteCommunityBackend` gets implemented (login, one rating
per user, Waze rule and rate limiting on the server, photos in object storage)
and is used in `main.dart` instead of the local adapters – UI and logic stay
unchanged.

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
    overpass_source.dart             OSM/Overpass query + parser
    official_opendata_source.dart    bundled official snapshot
  services/
    smoking_area_repository.dart     loading, merging, de-duplication, file cache
    proximity_detector.dart          pure 30 m logic (tested)
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
open `raucherzonen-japan-….apk` on the Android device and allow installation
from unknown sources. The pipeline can also be started manually (*Actions* →
*Run workflow*).

**Fixed signing key (recommended):** without it every APK is signed with a
different debug key, so an update can only be installed after uninstalling
the old version. Create it once:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias raucherzonen
base64 -w0 release.jks   # store the output as a secret
```

and add it under *Settings → Secrets and variables → Actions*:

| Secret | Content |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64-encoded `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | e.g. `raucherzonen` |
| `ANDROID_KEY_PASSWORD` | key password (empty = keystore password) |

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

## Notes for publishing

- The public OSM tile and Overpass servers have
  [usage policies](https://operations.osmfoundation.org/policies/tiles/). An
  app with many users should use its own or a commercial tile provider and, if
  needed, its own Overpass instance (URL in `map_screen.dart` and
  `OverpassSource.defaultEndpoints`).
- Android is currently **not distributed through the Play Store** but
  installed directly as an APK from the GitHub Releases (sideloading). Google
  Play Protect may show an “unknown app” warning on first installation –
  choose “Install anyway”.
- For a later store release, the App Store and Play Store require a
  justification for background location; the texts in `Info.plist` and the
  foreground service notification are prepared for that.
