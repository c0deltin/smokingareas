// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accepts => 'Nimmt an';

  @override
  String get access => 'Zugang';

  @override
  String get accessHint => 'z. B. Bahnsteig – nur mit Ticket, im Museum';

  @override
  String get accessNotPublic =>
      'nicht öffentlich (Ticket, Eintritt oder Kauf nötig)';

  @override
  String get accessOptional => 'Zugang (optional)';

  @override
  String get accessPublic => 'öffentlich';

  @override
  String get account => 'Konto';

  @override
  String get accountActions => 'Konto, abmelden, Konto löschen';

  @override
  String get accountDeleteFailed =>
      'Das Konto konnte nicht gelöscht werden – bitte versuche es noch einmal.';

  @override
  String get accountDeleted => 'Dein Konto wurde gelöscht.';

  @override
  String get activeProfile => 'Aktives Profil';

  @override
  String get addPhoto => 'Foto hinzufügen';

  @override
  String get address => 'Adresse';

  @override
  String get alertRadius => 'Benachrichtigungs-Radius';

  @override
  String get alertRadiusHelp =>
      'Kleiner Radius: Hinweise nur direkt am Raucherbereich. Großer Radius: frühere Hinweise, in dichten Gegenden aber mehr davon. Der blaue Kreis um deinen Standort zeigt den Radius.';

  @override
  String get alertsOff => 'Benachrichtigungen aus.';

  @override
  String alertsOnWithin(int meters) {
    return 'Benachrichtigungen an: Hinweis im Umkreis von $meters m.';
  }

  @override
  String get alreadyOnMap => 'Schon auf der Karte?';

  @override
  String get appTitle => 'Ippuku';

  @override
  String asUser(String name) {
    return 'als $name';
  }

  @override
  String get babyChanging => 'Wickeltisch';

  @override
  String get binHereQuestion => 'Gibt es hier einen Mülleimer?';

  @override
  String binNo(int count) {
    return 'Keiner ($count)';
  }

  @override
  String get binNone => 'Hier gibt es keinen Mülleimer.';

  @override
  String get binShown => 'Wird auf der Karte mit Mülleimer angezeigt.';

  @override
  String binYes(int count) {
    return 'Mülleimer ($count)';
  }

  @override
  String get block => 'Blockieren';

  @override
  String get blockExplain =>
      'Du siehst dann keine Orte, Bewertungen und Fotos dieser Person mehr. Rückgängig machen kannst du das unter Einstellungen → Konto.';

  @override
  String blockName(String name) {
    return '$name blockieren';
  }

  @override
  String blockNameQuestion(String name) {
    return '$name blockieren?';
  }

  @override
  String get blockedUsers => 'Blockierte Nutzer';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get catBin => 'Mülleimer';

  @override
  String get catBinPlural => 'Mülleimer';

  @override
  String get catSmoking => 'Raucherbereich';

  @override
  String get catSmokingPlural => 'Raucherbereiche';

  @override
  String get catToilet => 'Öffentliche Toilette';

  @override
  String get catToiletPlural => 'Toiletten';

  @override
  String get changePhoto => 'Foto ändern';

  @override
  String get changeRating => 'Ändern';

  @override
  String get chooseFromGallery => 'Aus Galerie wählen';

  @override
  String get cities => 'Städte';

  @override
  String get city => 'Stadt';

  @override
  String get close => 'Schließen';

  @override
  String get closedOfficially => 'Laut offizieller Liste geschlossen.';

  @override
  String get closureHint =>
      'Gesperrt, Baustelle, außer Betrieb? Melde es – die Meldung läuft nach 14 Tagen oder am gewählten Datum ab.';

  @override
  String closureInfo(int closed, int reopened) {
    String _temp0 = intl.Intl.pluralLogic(
      closed,
      locale: localeName,
      other: '$closed Meldungen „geschlossen“',
      one: '1 Meldung „geschlossen“',
    );
    String _temp1 = intl.Intl.pluralLogic(
      reopened,
      locale: localeName,
      other: ', $reopened „wieder offen“',
      one: ', 1 „wieder offen“',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get closureReasonHint => 'z. B. Baustelle, außer Betrieb, gesperrt';

  @override
  String get commentHint =>
      'Kommentar (optional): sauber, voll, leicht zu finden …';

  @override
  String get community => 'Community';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get continueWithoutAccount => 'Ohne Konto fortfahren';

  @override
  String get couldNotLoadData => 'Daten konnten nicht geladen werden.';

  @override
  String get covered => 'Überdacht';

  @override
  String get createProfile => 'Profil anlegen';

  @override
  String get dataSources => 'Datenquellen:';

  @override
  String get date => 'Datum';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountQuestion => 'Konto löschen?';

  @override
  String get deleteAccountText =>
      'Dein Konto, deine Bewertungen, Fotos, Abstimmungen und Schließungsmeldungen werden endgültig gelöscht. Von dir gemeldete Orte bleiben ohne deinen Namen auf der Karte.';

  @override
  String deleteSpotQuestion(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteSpotText => 'Der Ort wird für alle von der Karte entfernt.';

  @override
  String get detailsOptional => 'Details (optional)';

  @override
  String get discard => 'Verwerfen';

  @override
  String get distance => 'Entfernung';

  @override
  String distanceAway(String distance) {
    return '$distance entfernt';
  }

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editTitleBin => 'Mülleimer bearbeiten';

  @override
  String get editTitleSmoking => 'Raucherbereich bearbeiten';

  @override
  String get editTitleToilet => 'Öffentliche Toilette bearbeiten';

  @override
  String get endUnknown => 'Ende unbekannt (läuft nach 14 Tagen ab)';

  @override
  String get errConnection =>
      'Speichern fehlgeschlagen – bitte prüfe deine Verbindung.';

  @override
  String errCouldNotSave(String reason) {
    return 'Speichern fehlgeschlagen ($reason).';
  }

  @override
  String get errRateLimit =>
      'Zu viele Beiträge in kurzer Zeit – bitte versuche es später noch einmal.';

  @override
  String get errSignInFirst => 'Bitte melde dich zuerst an.';

  @override
  String expectedUntil(String date) {
    return 'voraussichtlich bis $date';
  }

  @override
  String get fee => 'Gebühr';

  @override
  String fgAlertsOnText(int meters) {
    return 'Du wirst benachrichtigt, wenn ein Raucherbereich im Umkreis von $meters m ist.';
  }

  @override
  String get fgAlertsOnTitle => 'Raucherbereich-Benachrichtigungen an';

  @override
  String get fgChannel => 'Standortüberwachung';

  @override
  String get goneText =>
      'Wenn genug Leute melden, dass es den Ort nicht mehr gibt, verschwindet er von der Karte.';

  @override
  String get goneTitle => 'Nicht mehr da?';

  @override
  String get hasTrashCan => 'Mit Mülleimer';

  @override
  String get hoursAlways => '24 Stunden geöffnet';

  @override
  String hoursClosedOn(String days) {
    return 'Geschlossen: $days';
  }

  @override
  String get hoursHolidays => 'Feiertage';

  @override
  String get hoursNewYear => 'Neujahrstage (29.12.–3.1.)';

  @override
  String hoursNextDay(String time) {
    return '$time (Folgetag)';
  }

  @override
  String get imprint => 'Impressum';

  @override
  String inThisCity(int count) {
    return '$count in dieser Stadt';
  }

  @override
  String get info => 'Info';

  @override
  String get infoAbout =>
      'Zeigt öffentliche Raucherbereiche (喫煙所, grün) und öffentliche Toiletten (公衆トイレ, blau) in ganz Japan sowie von Nutzern gemeldete Mülleimer (ゴミ箱, orange). Viele japanische Städte verbieten das Rauchen auf der Straße und erlauben es nur in ausgewiesenen Bereichen.\n\nMit eingeschalteten Benachrichtigungen bekommst du einen Hinweis, sobald du in die Nähe eines Raucherbereichs kommst (Radius in den Einstellungen) – auch wenn die App im Hintergrund läuft (nicht für Toiletten).\n';

  @override
  String get infoLegendMerge =>
      'Die Legende (Menü ⋮) erklärt alle Symbole. Offizielle Einträge (goldener Ring) stammen aus Listen der Städte und Bezirke; liegt ein OSM-Eintrag am selben Ort, werden beide zu einem Marker zusammengeführt. Adressen ohne Koordinaten wurden mit der GSI-Adresssuche verortet und sind als „ungefähr“ markiert.';

  @override
  String get infoMapCredits =>
      'Karte: Google Maps. Spot-Daten von OpenStreetMap: © OpenStreetMap-Mitwirkende (ODbL).\nKeine Gewähr für Richtigkeit – fehlende oder falsche Einträge kannst du direkt auf openstreetmap.org korrigieren (amenity=smoking_area, amenity=toilets).';

  @override
  String get initialSignInReason =>
      'Stöbere ohne Konto oder melde dich an, um zu bewerten, zu melden und Fotos hinzuzufügen.';

  @override
  String get legAlertRadius =>
      'Benachrichtigungs-Radius für Raucherbereiche in der Nähe.';

  @override
  String get legBin => 'Mülleimer (von Nutzern gemeldet).';

  @override
  String get legBinBadge => 'Oranges Abzeichen: mit Mülleimer.';

  @override
  String get legCategory => 'Kategorie (Füllfarbe)';

  @override
  String get legClosed => 'Grau mit Pause-Zeichen: vorübergehend geschlossen.';

  @override
  String get legClusterBin => 'Mehrere Mülleimer – zum Vergrößern tippen.';

  @override
  String get legClusterSmoking =>
      'Mehrere Raucherbereiche – zum Vergrößern tippen.';

  @override
  String get legClusterToilet => 'Mehrere Toiletten – zum Vergrößern tippen.';

  @override
  String get legGold =>
      'Gold: aus einer offiziellen Liste der Stadt oder des Bezirks.';

  @override
  String get legIndoorSmoking => 'Raucherraum drinnen.';

  @override
  String get legMap => 'Karte';

  @override
  String get legOrigin => 'Herkunft (Ring)';

  @override
  String get legOutdoorSmoking => 'Raucherbereich im Freien.';

  @override
  String get legPink => 'Pink: von einer Person gemeldet.';

  @override
  String get legStatus => 'Status';

  @override
  String get legToilet => 'Öffentliche Toilette.';

  @override
  String get legWhite => 'Weiß: Eintrag aus OpenStreetMap.';

  @override
  String get legYourLocation =>
      'Dein Standort – der Kegel zeigt deine Blickrichtung.';

  @override
  String get legend => 'Legende';

  @override
  String get loadingSmokingAreas => 'Raucherbereiche werden geladen …';

  @override
  String get localDataRemoved =>
      'Die Beiträge wurden von diesem Gerät entfernt.';

  @override
  String localDataText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beiträge wurden',
      one: '1 Beitrag wurde',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sie',
      one: 'ihn',
    );
    return '$_temp0 (Orte, Bewertungen, Fotos, Meldungen) nur auf diesem Gerät gespeichert. In dein Konto hochladen, damit alle $_temp1 sehen?';
  }

  @override
  String get localDataTitle => 'Beiträge auf diesem Gerät';

  @override
  String get localProfilesNote =>
      'Bewertungen, Fotos und Meldungen werden derzeit nur auf diesem Gerät gespeichert und dem aktiven Profil zugeordnet. Mit mehreren Profilen kannst du z. B. ausprobieren, dass ein Spot nach drei „nicht mehr da“-Meldungen verschwindet.';

  @override
  String get locationServicesOff => 'Ortungsdienste sind ausgeschaltet.';

  @override
  String get locationUseText =>
      'Ippuku nutzt deinen Standort, um Raucherbereiche und öffentliche Toiletten in der Nähe auf der Karte zu zeigen.\n\nWenn du Benachrichtigungen einschaltest, nutzt die App deinen Standort auch im Hintergrund – auch wenn die App geschlossen ist oder nicht verwendet wird –, um dich zu benachrichtigen, sobald du in der Nähe eines ausgewiesenen Raucherbereichs bist.\n\nDein Standort wird nur auf deinem Gerät verarbeitet. Er wird nie an uns gesendet oder mit anderen geteilt. Du kannst die Benachrichtigungen jederzeit ausschalten.';

  @override
  String get locationUseTitle => 'Nutzung deines Standorts';

  @override
  String mapDataUpdated(String version) {
    return 'Kartendaten aktualisiert ($version).';
  }

  @override
  String get menu => 'Menü';

  @override
  String meters(int meters) {
    return '$meters m';
  }

  @override
  String get more => 'Mehr';

  @override
  String moveCrossHint(String category) {
    return '$category: Verschiebe die Karte, bis das Kreuz genau auf dem Ort liegt.';
  }

  @override
  String get myLocation => 'Mein Standort';

  @override
  String get mySpots => 'Meine Spots';

  @override
  String get mySpotsEmpty =>
      'Du hast noch keine Orte gemeldet. Nutze dafür den Button „Spot melden“ auf der Karte.';

  @override
  String get mySpotsSignIn =>
      'Melde dich an, um deine gemeldeten Orte zu sehen und zu verwalten.';

  @override
  String get name => 'Name';

  @override
  String get nameHintBin => 'z. B. „Mülleimer neben den Automaten“';

  @override
  String get nameHintSmoking => 'z. B. „Raucherecke neben dem FamilyMart“';

  @override
  String get nameHintToilet => 'z. B. „Toilette am Parkeingang“';

  @override
  String get namePlace => 'Name / Ort';

  @override
  String nearestName(String name) {
    return 'Am nächsten: $name';
  }

  @override
  String get no => 'nein';

  @override
  String get noAccountText =>
      'Du nutzt die App ohne Konto. Melde dich mit Apple oder Google an, um zu bewerten, zu melden und Fotos hinzuzufügen.';

  @override
  String get noLocationNoAlerts =>
      'Ohne Standortzugriff gibt es keine Benachrichtigungen in der Nähe.';

  @override
  String get noRatingsYet => 'Noch keine Bewertungen';

  @override
  String get noReportNew => 'Nein, neu melden';

  @override
  String get noSeparate => 'Nein, separat';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get notSignedIn => 'Nicht angemeldet';

  @override
  String get notSure => 'Unsicher';

  @override
  String get note => 'Hinweis';

  @override
  String get noteBabyChairTable => 'Babysitz und Wickeltisch';

  @override
  String get noteChangingTable => 'Wickeltisch';

  @override
  String get noteConstruction => 'Wegen Bauarbeiten geschlossen';

  @override
  String get noteHeatedOnly => 'Nur Tabakerhitzer';

  @override
  String get noteHintBin => 'Wo genau, wie man ihn findet …';

  @override
  String get noteHintDefault => 'Öffnungszeiten, Aschenbecher, Zugang …';

  @override
  String get noteMenOnly => 'Nur für Männer';

  @override
  String get noteOptional => 'Hinweis (optional)';

  @override
  String get noteUnisex => 'Für alle Geschlechter';

  @override
  String get noteWomenAccessible =>
      'Damentoilette, zugleich barrierefreie Toilette';

  @override
  String get noteWomenOnly => 'Nur für Frauen';

  @override
  String get notifChannelNearby => 'Raucherbereich in der Nähe';

  @override
  String get notifChannelNearbyDesc =>
      'Benachrichtigt dich, wenn du in die Nähe eines Raucherbereichs kommst.';

  @override
  String notifNearbyBody(String name, int meters) {
    return '$name – etwa $meters m entfernt. Tippen, um die Karte zu öffnen.';
  }

  @override
  String get notifNearbyTitle => 'Raucherbereich in der Nähe';

  @override
  String officialDataVersion(String version) {
    return 'Version der offiziellen Daten: $version – wird automatisch aktualisiert, auch über „Neu laden“.';
  }

  @override
  String offlineSavedData(String date) {
    return 'Offline – gespeicherte Daten vom $date.';
  }

  @override
  String get ok => 'OK';

  @override
  String get openAgain => 'Wieder offen';

  @override
  String get openingHours => 'Öffnungszeiten';

  @override
  String get operator => 'Betreiber';

  @override
  String get osm => 'OSM';

  @override
  String get osmCopyright => 'Daten © OpenStreetMap-Mitwirkende';

  @override
  String get outdoors => 'Draußen';

  @override
  String partOfHostText(String name, String category) {
    return '„$name“ ($category) ist direkt hier. Gehört der Mülleimer dazu (z. B. ein Aschenbecher mit Mülleimer)? Dann wird er dort ergänzt statt als neuer Marker.';
  }

  @override
  String get partOfHostTitle => 'Gehört er zu diesem Ort?';

  @override
  String get photo => 'Foto';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos',
      one: '1 Foto',
    );
    return '$_temp0';
  }

  @override
  String get photoUploadFailed => 'Das Foto konnte nicht hochgeladen werden.';

  @override
  String get popularDistricts => 'Beliebte Viertel';

  @override
  String get position => 'Position';

  @override
  String get positionApprox => 'ungefähr (aus der Adresse, ± ca. 50 m)';

  @override
  String get privacyPolicy => 'Datenschutz';

  @override
  String get profile => 'Profil';

  @override
  String get profilesOnDevice => 'Profile auf diesem Gerät';

  @override
  String get publiclyAccessible => 'Öffentlich zugänglich';

  @override
  String get publiclyAccessibleSub => 'kein Ticket, Eintritt oder Kauf nötig';

  @override
  String get rate => 'Bewerten';

  @override
  String ratingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bewertungen',
      one: '1 Bewertung',
    );
    return '$average ($_temp0)';
  }

  @override
  String get reasonOffensive => 'Beleidigend oder unangemessen';

  @override
  String get reasonOptional => 'Grund (optional)';

  @override
  String get reasonOther => 'Sonstiges';

  @override
  String get reasonPersonalData => 'Persönliche Daten anderer';

  @override
  String get reasonSpam => 'Spam oder Werbung';

  @override
  String get reasonWrong => 'Falsch oder irreführend';

  @override
  String get reload => 'Neu laden';

  @override
  String get remove => 'Entfernen';

  @override
  String get removedAfterReports =>
      'Danke! Der Ort wurde nach Meldungen der Community entfernt.';

  @override
  String get removedByCommunity => 'von der Community entfernt';

  @override
  String get rename => 'Umbenennen';

  @override
  String get report => 'Melden';

  @override
  String get reportASpot => 'Spot melden';

  @override
  String get reportHere => 'Hier melden';

  @override
  String get reportTitleBin => 'Mülleimer melden';

  @override
  String get reportTitleSmoking => 'Raucherbereich melden';

  @override
  String get reportTitleToilet => 'Öffentliche Toilette melden';

  @override
  String get reportedBy => 'Gemeldet von';

  @override
  String reportedGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen haben',
      one: '1 Person hat',
    );
    return '$_temp0 gemeldet, dass es diesen Ort nicht mehr gibt.';
  }

  @override
  String reportedOn(String date) {
    return 'Gemeldet am $date';
  }

  @override
  String get reportedVisibleNote =>
      'Gemeldete Spots sind sofort sichtbar. Melden genug Leute, dass es einen Spot nicht gibt, wird er wieder entfernt.';

  @override
  String resetToMeters(int meters) {
    return 'Auf $meters m zurücksetzen';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String roomsInBuilding(int count) {
    return '$count im selben Gebäude';
  }

  @override
  String get route => 'Route';

  @override
  String sameplaceQuestion(String name, int meters) {
    return '„$name“ ist $meters m entfernt. Ist es derselbe Ort?';
  }

  @override
  String get save => 'Speichern';

  @override
  String get savedOffline =>
      'Keine Verbindung – auf dem Gerät gespeichert und später automatisch gesendet.';

  @override
  String get saving => 'Wird gespeichert …';

  @override
  String get searchPlaceHint => 'Stadt, Bezirk oder Präfektur suchen';

  @override
  String get send => 'Senden';

  @override
  String get sending => 'Wird gesendet …';

  @override
  String get settings => 'Einstellungen';

  @override
  String get showOnMap => 'Auf der Karte zeigen';

  @override
  String get shownWithContributions => 'Wird bei deinen Beiträgen angezeigt';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signInDefaultReason =>
      'Melde dich an, um zu bewerten, zu melden und Fotos hinzuzufügen.';

  @override
  String get signInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuche es noch einmal.';

  @override
  String get signInPrivacyNote =>
      'Bei deinen Beiträgen wird nur dein Vorname angezeigt. Dein Standort verlässt nie dein Gerät. Mit der Anmeldung akzeptierst du die Nutzungsbedingungen.';

  @override
  String get signInToAddDetails => 'Melde dich an, um Details zu ergänzen.';

  @override
  String get signInToAddPhotos => 'Melde dich an, um Fotos hinzuzufügen.';

  @override
  String get signInToBlock => 'Melde dich an, um Nutzer zu blockieren.';

  @override
  String get signInToConfirm => 'Melde dich an, um Orte zu bestätigen.';

  @override
  String get signInToContribute => 'Melde dich an, um beizutragen.';

  @override
  String get signInToRate => 'Melde dich an, um Orte zu bewerten.';

  @override
  String get signInToReport => 'Melde dich an, um neue Orte zu melden.';

  @override
  String get signInToReportClosures =>
      'Melde dich an, um Schließungen zu melden.';

  @override
  String get signInToReportContent => 'Melde dich an, um Inhalte zu melden.';

  @override
  String get signInToReportGone =>
      'Melde dich an, um verschwundene Orte zu melden.';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signOut => 'Abmelden';

  @override
  String signedInAs(String name) {
    return 'Angemeldet als $name';
  }

  @override
  String get smokingAreaAlerts => 'Benachrichtigungen für Raucherbereiche';

  @override
  String get smokingAreaAlertsSub =>
      'Benachrichtige mich, wenn ich in die Nähe eines Raucherbereichs komme.';

  @override
  String smokingAreasInCity(int count) {
    return '$count Raucherbereiche in dieser Stadt';
  }

  @override
  String get smokingRoom => 'Raucherraum';

  @override
  String get smokingRoomIndoors => 'Raucherraum (drinnen)';

  @override
  String get smokingRooms => 'Raucherräume';

  @override
  String get someSourcesUnreachable => 'Einige Quellen sind nicht erreichbar.';

  @override
  String get source => 'Quelle';

  @override
  String sourceOfficial(String source) {
    return '$source (offiziell)';
  }

  @override
  String get stillThereQuestion => 'Gibt es diesen Ort noch?';

  @override
  String get switchProfile => 'Wechseln';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get temporarilyClosed => 'Vorübergehend geschlossen';

  @override
  String get temporarilyClosedLower => 'vorübergehend geschlossen';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String thanksHostHasBin(String name) {
    return 'Danke! „$name“ zeigt jetzt einen Mülleimer.';
  }

  @override
  String get thanksReportReviewed => 'Danke – die Meldung wird geprüft.';

  @override
  String get thanksSpotOnMap => 'Danke! Dein Spot ist jetzt auf der Karte.';

  @override
  String get thanksSpotPhotoUploading =>
      'Danke! Dein Spot ist auf der Karte – das Foto wird hochgeladen.';

  @override
  String get thisUser => 'diese Person';

  @override
  String get tipAllowAlways =>
      'Tipp: Erlaube „Immer“ für Benachrichtigungen im Hintergrund.';

  @override
  String toiletNearest(String name, String distance) {
    return 'Toilette: $name · $distance';
  }

  @override
  String get translate => 'Übersetzen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get turnAlertsOff => 'Benachrichtigungen ausschalten';

  @override
  String get turnAlertsOn => 'Benachrichtigungen einschalten';

  @override
  String get type => 'Art';

  @override
  String get unblock => 'Freigeben';

  @override
  String get unknown => 'unbekannt';

  @override
  String get upload => 'Hochladen';

  @override
  String get uploadFailedTap => 'Fehler – tippen';

  @override
  String uploadedPartly(int done, int left) {
    return '$done hochgeladen, $left übrig – der Rest folgt beim nächsten Mal.';
  }

  @override
  String uploadedThanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Beiträge',
      one: '1 Beitrag',
    );
    return '$_temp0 hochgeladen. Danke!';
  }

  @override
  String get uploading => 'Wird hochgeladen …';

  @override
  String voteNo(int count) {
    return 'Nein ($count)';
  }

  @override
  String voteYes(int count) {
    return 'Ja ($count)';
  }

  @override
  String wardName(String ward) {
    return 'Bezirk $ward';
  }

  @override
  String get wasteBottles => 'PET-Flaschen';

  @override
  String get wasteCans => 'Dosen';

  @override
  String get wasteTrash => 'Restmüll';

  @override
  String get whatToReport => 'Was möchtest du melden?';

  @override
  String get wheelchairAccessible => 'Rollstuhlgerecht';

  @override
  String get yes => 'ja';

  @override
  String get yesAddToIt => 'Ja, ergänzen';

  @override
  String get yesShowIt => 'Ja, anzeigen';
}
