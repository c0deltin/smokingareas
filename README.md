# Raucherzonen Japan 🚬🗾

Flutter-App für **iOS und Android**, die öffentliche Raucherbereiche (喫煙所) in
allen großen Städten Japans auf einer Karte anzeigt und eine **Push-Benachrichtigung**
sendet, sobald man sich einem Raucherbereich auf **30 m** nähert – auch wenn die
App im Hintergrund läuft.

## Funktionen

- Karte (OpenStreetMap-Kacheln) mit geclusterten Markern, Detailansicht
  (innen/außen, überdacht, Gebühr, Öffnungszeiten, Betreiber) und Fußweg-Route
  über Apple Maps / Google Maps.
- 55 Städte/Ballungsräume: Tokio (23 Bezirke + Tama), alle 20 Großstädte mit
  Sonderstatus (政令指定都市) sowie alle übrigen Präfektur-Hauptstädte bzw.
  großen Städte (Naha, Kanazawa, Nara, Kagoshima, Nagasaki …) – siehe
  `lib/data/cities.dart`.
- Automatische Stadtwahl anhand des Standorts, manuelle Auswahl mit Suche –
  inkl. Schnellauswahl beliebter Viertel (Shinjuku, Shibuya, Ikebukuro,
  Akihabara, Kanda, Ueno, Asakusa, Ginza, Umeda, Namba, Gion …).
- 30‑m‑Annäherungsalarm als lokale Push-Benachrichtigung
  - Hysterese (erneuter Alarm erst nach > 60 m Abstand) und 30 min Cooldown je
    Raucherbereich, damit GPS-Schwankungen keine Benachrichtigungsflut auslösen
  - ungenaue Standortdaten (> 50 m Genauigkeit) werden ignoriert
  - Antippen der Benachrichtigung öffnet den Raucherbereich auf der Karte
- Offline-Cache pro Stadt (7 Tage), Fallback auf gespeicherte Daten ohne Netz.

## Datenquellen

| Quelle | Gebiet | Zugriff | Lizenz |
|---|---|---|---|
| **OpenStreetMap** via öffentliche **Overpass API** – `amenity=smoking_area`, `amenity=smoking_room`, `smoking=dedicated` | ganz Japan | live in der App | ODbL |
| Stadt Kyoto – Open-Data-Portal, Datensatz „施設情報一覧“, Kategorie 喫煙場所 | Kyoto | Snapshot | CC BY 4.0 |
| Stadt Osaka – Liste der 大阪市指定喫煙所 (Koordinaten aus den GIS-Links) | Osaka | Snapshot | Angaben der Stadt |
| Tokio, Bezirk Kōtō – Open Data „公共喫煙所一覧“ | Kameido, Tōyōchō, Shin-Kiba … | Snapshot | CC BY 4.0 |
| Tokio, Bezirk Taitō – Open Data „公衆喫煙所（区設置分）“ | Ueno, Asakusa … | Snapshot | CC BY 4.0 |
| Tokio, Bezirk Chiyoda – „無料喫煙所（公衆喫煙所）のご案内“ | **Akihabara, Kanda**, Jimbōchō, Iidabashi … | Snapshot, geocodiert | Angaben des Bezirks |
| Tokio, Bezirk Shinjuku – „公衆喫煙所“ | **Shinjuku**, Takadanobaba … | Snapshot, geocodiert | Angaben des Bezirks |
| Tokio, Bezirk Shibuya – „区内公共喫煙所一覧“ | **Shibuya**, Harajuku, Ebisu … | Snapshot, geocodiert | Angaben des Bezirks |
| Tokio, Bezirk Toshima – „区指定喫煙所“ | **Ikebukuro**, Ōtsuka | Snapshot, geocodiert | Angaben des Bezirks |
| GSI (国土地理院) Adresssuche | Geocoding der Adresslisten | beim Snapshot-Bau | – |
| OpenStreetMap-Kartenkacheln | – | live | ODbL |

**Okayama** veröffentlicht keine maschinenlesbare Liste der Raucherplätze
(nur die Fläche der Rauchverbotszone) – dort zeigt die App die OSM-Daten.

### Offizielle Daten (Snapshot)

Die Listen der Städte liegen in sehr unterschiedlichen Formaten vor (CSV,
HTML-Seiten, Formular-Downloads, teils nur Adressen). Darum normalisiert
`tool/opendata/update_opendata.py` sie zu
`assets/opendata/official_smoking_areas.json`, das mit der App ausgeliefert
wird. Die Pipeline aktualisiert den Snapshot vor jedem Build; lokal:

```bash
python3 tool/opendata/update_opendata.py            # alle Quellen
python3 tool/opendata/update_opendata.py osaka kyoto # nur einzelne
```

Fällt eine Quelle aus, bleiben ihre bisherigen Einträge erhalten. Adressen
ohne Koordinaten werden über die GSI-Adresssuche verortet (Cache:
`tool/opendata/geocode_cache.json`) und in der App als „ungefähr“ markiert.

### Eine Karte, alle Daten

Der Nutzer wählt keine Datenquelle: Alle Quellen werden zu einem Datenbestand
für ganz Japan zusammengeführt. Beim Start sind die offiziellen Daten und alle
bereits auf dem Gerät gespeicherten Städte sofort sichtbar; OSM-Daten der
aktuellen Stadt werden im Hintergrund ergänzt. Die Stadt-/Viertelauswahl
steuert nur den Kartenausschnitt (Zoom).

### Keine doppelten Marker

- Mehrere Raucherräume im selben Gebäude (gleiche Adresse) werden schon im
  Snapshot zu einem Eintrag zusammengefasst.
- Beim Laden einer Stadt wird jeder offizielle Eintrag mit höchstens einem
  OSM-Punkt zusammengeführt (nächstes Paar zuerst; Radius 25 m bei exakten,
  50 m bei geocodierten Koordinaten). Der Marker übernimmt Name, Adresse und
  Öffnungszeiten der Stadt, die OSM-Attribute und – bei geocodierten Adressen –
  die genauere OSM-Position.
- Offizielle Einträge haben einen blauen Ring; die Detailansicht verlinkt die
  Seite der Stadt und den OSM-Eintrag.

## Architektur

```
lib/
  main.dart                       App-Start
  data/cities.dart                abgedeckte Städte (Zentrum + Radius)
  models/                         SmokingArea, City, GeoBounds
  sources/overpass_source.dart    OSM/Overpass-Abfrage + Parser
  services/
    smoking_area_repository.dart  Laden, Deduplizieren, Datei-Cache
    proximity_detector.dart       reine 30‑m‑Logik (getestet)
    proximity_monitor.dart        Standort-Stream (auch Hintergrund) → Alarm
    notification_service.dart     lokale Push-Benachrichtigungen
  ui/                             Karte, Stadtauswahl, Detail-Sheet
```

## Starten

```bash
flutter pub get
flutter test
flutter run            # Android-Gerät oder iOS-Simulator/Gerät
```

iOS: `cd ios && pod install` wird von `flutter run` automatisch ausgeführt.
Für ein echtes iPhone muss in Xcode ein Signing-Team gesetzt werden.

## APK-Download & CI

Bei jedem Push auf `main` baut die GitHub-Actions-Pipeline
(`.github/workflows/android-release.yml`) die App, führt Analyse und Tests aus
und veröffentlicht das APK als **GitHub Release** (`v1.0.<Build-Nummer>`).
Download: *Releases* → neueste Version → `raucherzonen-japan-….apk` auf dem
Android-Gerät öffnen und die Installation aus unbekannten Quellen erlauben.
Die Pipeline kann auch manuell gestartet werden (*Actions* → *Run workflow*).

**Fester Signaturschlüssel (empfohlen):** Ohne ihn wird jedes APK mit einem
anderen Debug-Schlüssel signiert, sodass ein Update erst nach Deinstallation
der alten Version möglich ist. Einmalig anlegen:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias raucherzonen
base64 -w0 release.jks   # Ausgabe als Secret speichern
```

und unter *Settings → Secrets and variables → Actions* hinterlegen:

| Secret | Inhalt |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64-kodierte `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore-Passwort |
| `ANDROID_KEY_ALIAS` | z. B. `raucherzonen` |
| `ANDROID_KEY_PASSWORD` | Schlüssel-Passwort (leer = Keystore-Passwort) |

## Berechtigungen & Hintergrundbetrieb

- **Android**: Standort (fein + Hintergrund), Foreground-Service (Typ
  `location`) mit dauerhafter Benachrichtigung, solange der Alarm aktiv ist,
  sowie `POST_NOTIFICATIONS` (Android 13+). Für Alarme bei geschlossener App
  muss in den Systemeinstellungen „Immer zulassen“ gewählt werden.
- **iOS**: `UIBackgroundModes = location`, Beschreibungen für „Beim Verwenden“
  und „Immer“. Für Alarme im Hintergrund „Immer“ erlauben.
- Der Alarm lässt sich über das Glocken-Symbol ein- und ausschalten; ist er
  aus, läuft kein Hintergrund-Tracking.

## Hinweise für die Veröffentlichung

- Die öffentlichen OSM-Kachel- und Overpass-Server haben
  [Nutzungsrichtlinien](https://operations.osmfoundation.org/policies/tiles/).
  Für eine App mit vielen Nutzern sollte ein eigener bzw. kommerzieller
  Kachel-Anbieter und ggf. eine eigene Overpass-Instanz verwendet werden
  (URL in `map_screen.dart` bzw. `OverpassSource.defaultEndpoints`).
- Android wird aktuell **nicht über den Play Store** verteilt, sondern direkt
  als APK aus den GitHub Releases installiert (Sideloading). Google Play
  Protect kann beim ersten Installieren eine Warnung „Unbekannte App“ zeigen –
  „Trotzdem installieren“ wählen.
- Für einen späteren Store-Upload verlangen App Store / Play Store eine
  Begründung für Hintergrund-Standort; die Texte in `Info.plist` und die
  Foreground-Service-Benachrichtigung sind dafür vorbereitet.
