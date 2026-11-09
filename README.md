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
- Automatische Stadtwahl anhand des Standorts, manuelle Auswahl mit Suche.
- 30‑m‑Annäherungsalarm als lokale Push-Benachrichtigung
  - Hysterese (erneuter Alarm erst nach > 60 m Abstand) und 30 min Cooldown je
    Raucherbereich, damit GPS-Schwankungen keine Benachrichtigungsflut auslösen
  - ungenaue Standortdaten (> 50 m Genauigkeit) werden ignoriert
  - Antippen der Benachrichtigung öffnet den Raucherbereich auf der Karte
- Offline-Cache pro Stadt (7 Tage), Fallback auf gespeicherte Daten ohne Netz.

## Datenquellen

| Quelle | Zugriff | Lizenz |
|---|---|---|
| **OpenStreetMap** via öffentliche **Overpass API** (`overpass-api.de`, Fallbacks `overpass.kumi.systems`, `maps.mail.ru`) – Tags `amenity=smoking_area`, `amenity=smoking_room`, `smoking=dedicated` | live, ohne API-Key | ODbL |
| OpenStreetMap-Kartenkacheln (`tile.openstreetmap.org`) | live | ODbL |

Weitere Quellen (z. B. Open-Data-Datensätze einzelner Bezirke/Städte als
GeoJSON/CSV) können durch Implementieren von `SmokingAreaSource`
(`lib/sources/smoking_area_source.dart`) und Registrieren in
`SmokingAreaRepository` ergänzt werden. Punkte verschiedener Quellen, die
weniger als 8 m auseinanderliegen, werden automatisch zusammengeführt.

> Fehlt ein Raucherbereich? Er lässt sich direkt auf openstreetmap.org als
> `amenity=smoking_area` eintragen – die App zeigt ihn nach dem nächsten
> Aktualisieren an.

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
- App Store / Play Store verlangen eine Begründung für Hintergrund-Standort;
  die Texte in `Info.plist` und die Foreground-Service-Benachrichtigung sind
  dafür vorbereitet.
