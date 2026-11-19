// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accepts => 'Accepts';

  @override
  String get access => 'Access';

  @override
  String get accessHint =>
      'e.g. station platform – ticket only, inside a museum';

  @override
  String get accessNotPublic =>
      'not public (ticket, entry fee or purchase needed)';

  @override
  String get accessOptional => 'Access (optional)';

  @override
  String get accessPublic => 'public';

  @override
  String get account => 'Account';

  @override
  String get accountActions => 'Account, sign out, delete account';

  @override
  String get accountDeleteFailed =>
      'Could not delete the account – please try again.';

  @override
  String get accountDeleted => 'Your account was deleted.';

  @override
  String get activeProfile => 'Active profile';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get address => 'Address';

  @override
  String get alertRadius => 'Alert radius';

  @override
  String get alertRadiusHelp =>
      'Small radius: alerts only right next to a smoking area. Large radius: earlier alerts, but more of them in dense areas. The blue circle around your location shows the radius.';

  @override
  String get alertsOff => 'Alerts off.';

  @override
  String alertsOnWithin(int meters) {
    return 'Alerts on: you will be notified within $meters m.';
  }

  @override
  String get alreadyOnMap => 'Already on the map?';

  @override
  String get appTitle => 'Ippuku';

  @override
  String asUser(String name) {
    return 'as $name';
  }

  @override
  String get babyChanging => 'Baby changing';

  @override
  String get binHereQuestion => 'Is there a trash can here?';

  @override
  String binNo(int count) {
    return 'None ($count)';
  }

  @override
  String get binNone => 'No trash can here.';

  @override
  String get binShown => 'Shown with a trash can on the map.';

  @override
  String binYes(int count) {
    return 'Trash can ($count)';
  }

  @override
  String get block => 'Block';

  @override
  String get blockExplain =>
      'You will no longer see their places, ratings and photos. You can undo this in Settings → Account.';

  @override
  String blockName(String name) {
    return 'Block $name';
  }

  @override
  String blockNameQuestion(String name) {
    return 'Block $name?';
  }

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get cancel => 'Cancel';

  @override
  String get catBin => 'Trash can';

  @override
  String get catBinPlural => 'Trash cans';

  @override
  String get catSmoking => 'Smoking area';

  @override
  String get catSmokingPlural => 'Smoking areas';

  @override
  String get catToilet => 'Public toilet';

  @override
  String get catToiletPlural => 'Toilets';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get changeRating => 'Change';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get cities => 'Cities';

  @override
  String get city => 'City';

  @override
  String get close => 'Close';

  @override
  String get closedNow => 'Closed now';

  @override
  String get closedOfficially => 'Closed according to the official list.';

  @override
  String closesAt(String time) {
    return 'closes $time';
  }

  @override
  String get closureHint =>
      'Blocked, construction, out of order? Report it – the report expires after 14 days or on the date you set.';

  @override
  String closureInfo(int closed, int reopened) {
    String _temp0 = intl.Intl.pluralLogic(
      closed,
      locale: localeName,
      other: '$closed \"closed\" reports',
      one: '1 \"closed\" report',
    );
    String _temp1 = intl.Intl.pluralLogic(
      reopened,
      locale: localeName,
      other: ', $reopened \"reopened\"',
      one: ', 1 \"reopened\"',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get closureReasonHint => 'e.g. construction, out of order, blocked';

  @override
  String get commentHint =>
      'Comment (optional): clean, crowded, easy to find …';

  @override
  String get community => 'Community';

  @override
  String get continueLabel => 'Continue';

  @override
  String get continueWithoutAccount => 'Continue without account';

  @override
  String get couldNotLoadData => 'Could not load data.';

  @override
  String get covered => 'Covered';

  @override
  String get createProfile => 'Create profile';

  @override
  String get dataSources => 'Data sources:';

  @override
  String get date => 'Date';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete account?';

  @override
  String get deleteAccountText =>
      'Your account, ratings, photos, votes and closure reports are deleted for good. Places you reported stay on the map without your name.';

  @override
  String deleteSpotQuestion(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteSpotText =>
      'The place is removed from the map for everyone.';

  @override
  String get detailsOptional => 'Details (optional)';

  @override
  String get discard => 'Discard';

  @override
  String get distance => 'Distance';

  @override
  String distanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get edit => 'Edit';

  @override
  String get editTitleBin => 'Edit trash can';

  @override
  String get editTitleSmoking => 'Edit smoking area';

  @override
  String get editTitleToilet => 'Edit public toilet';

  @override
  String get endUnknown => 'End unknown (expires after 14 days)';

  @override
  String get errConnection => 'Could not save – please check your connection.';

  @override
  String errCouldNotSave(String reason) {
    return 'Could not save ($reason).';
  }

  @override
  String get errRateLimit =>
      'Too many contributions in a short time – please try again later.';

  @override
  String get errSignInFirst => 'Please sign in first.';

  @override
  String expectedUntil(String date) {
    return 'expected until $date';
  }

  @override
  String get fee => 'Fee';

  @override
  String fgAlertsOnText(int meters) {
    return 'You will be notified when a smoking area is within $meters m.';
  }

  @override
  String get fgAlertsOnTitle => 'Smoking area alerts on';

  @override
  String get fgChannel => 'Location monitoring';

  @override
  String get goneText =>
      'If enough users report that this place is gone, it is removed from the map.';

  @override
  String get goneTitle => 'Gone?';

  @override
  String get hasTrashCan => 'Has a trash can';

  @override
  String get hoursAlways => 'Open 24 hours';

  @override
  String hoursClosedOn(String days) {
    return 'Closed: $days';
  }

  @override
  String get hoursHolidays => 'public holidays';

  @override
  String get hoursNewYear => 'New Year holidays (Dec 29 – Jan 3)';

  @override
  String hoursNextDay(String time) {
    return '$time (next day)';
  }

  @override
  String get imprint => 'Imprint';

  @override
  String inThisCity(int count) {
    return '$count in this city';
  }

  @override
  String get info => 'Info';

  @override
  String get infoAbout =>
      'Shows public smoking areas (喫煙所, green) and public toilets (公衆トイレ, blue) all over Japan, plus trash cans (ゴミ箱, orange) reported by users. Many Japanese cities ban smoking on the street and only allow it in designated areas.\n\nWith alerts on you get a notification as soon as you come close to a smoking area (radius configurable in Settings) – also while the app runs in the background (not for toilets).\n';

  @override
  String get infoLegendMerge =>
      'The legend (menu ⋮) explains all symbols. Official entries (gold ring) come from lists published by cities and wards; if an OSM entry is at the same place, both are merged into one marker. Addresses published without coordinates were located with the GSI address search and are marked as \"approximate\".';

  @override
  String get infoMapCredits =>
      'Map: Google Maps. Spot data from OpenStreetMap: © OpenStreetMap contributors (ODbL).\nNo guarantee of accuracy – you can fix missing or wrong entries directly on openstreetmap.org (amenity=smoking_area, amenity=toilets).';

  @override
  String get initialSignInReason =>
      'Browse without an account, or sign in to rate, report and add photos.';

  @override
  String get legAlertRadius => 'Alert radius for nearby smoking areas.';

  @override
  String get legBin => 'Trash can (reported by users).';

  @override
  String get legBinBadge => 'Orange badge: has a trash can.';

  @override
  String get legCategory => 'Category (fill colour)';

  @override
  String get legClosed => 'Grey with pause badge: temporarily closed.';

  @override
  String get legClusterBin => 'Several trash cans – tap to zoom in.';

  @override
  String get legClusterSmoking => 'Several smoking areas – tap to zoom in.';

  @override
  String get legClusterToilet => 'Several toilets – tap to zoom in.';

  @override
  String get legGold => 'Gold: from an official list of the city or ward.';

  @override
  String get legIndoorSmoking => 'Indoor smoking room.';

  @override
  String get legMap => 'Map';

  @override
  String get legOrigin => 'Origin (ring)';

  @override
  String get legOutdoorSmoking => 'Outdoor smoking area.';

  @override
  String get legPink => 'Pink: reported by a user.';

  @override
  String get legStatus => 'Status';

  @override
  String get legToilet => 'Public toilet.';

  @override
  String get legWhite => 'White: entry from OpenStreetMap.';

  @override
  String get legYourLocation =>
      'Your location – the cone shows the direction you are facing.';

  @override
  String get legend => 'Legend';

  @override
  String get loadingSmokingAreas => 'Loading smoking areas …';

  @override
  String get localDataRemoved => 'Removed the contributions from this device.';

  @override
  String localDataText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions were',
      one: '1 contribution was',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return '$_temp0 (places, ratings, photos, reports) saved only on this device. Upload $_temp1 to your account so everyone can see $_temp2?';
  }

  @override
  String get localDataTitle => 'Contributions on this device';

  @override
  String get localProfilesNote =>
      'Ratings, photos and reports are currently stored only on this device and assigned to the active profile. Several profiles let you try out e.g. that a spot disappears after three \"gone\" reports.';

  @override
  String get locationServicesOff => 'Location services are turned off.';

  @override
  String get locationUseText =>
      'Ippuku uses your location to show nearby smoking areas and public toilets on the map.\n\nIf you turn on alerts, the app also uses your location in the background – even when the app is closed or not in use – to notify you when you are close to a designated smoking area.\n\nYour location is processed only on your device. It is never sent to us or shared with anyone. You can turn alerts off at any time.';

  @override
  String get locationUseTitle => 'Use of your location';

  @override
  String mapDataUpdated(String version) {
    return 'Map data updated ($version).';
  }

  @override
  String get menu => 'Menu';

  @override
  String meters(int meters) {
    return '$meters m';
  }

  @override
  String get more => 'More';

  @override
  String moveCrossHint(String category) {
    return '$category: move the map until the cross is exactly on the spot.';
  }

  @override
  String get myLocation => 'My location';

  @override
  String get mySpots => 'My spots';

  @override
  String get mySpotsEmpty =>
      'You have not reported any places yet. Use the \"Report a spot\" button on the map.';

  @override
  String get mySpotsSignIn =>
      'Sign in to see and manage the places you reported.';

  @override
  String get name => 'Name';

  @override
  String get nameHintBin => 'e.g. \"Bins next to the vending machines\"';

  @override
  String get nameHintSmoking => 'e.g. \"Smoking corner next to FamilyMart\"';

  @override
  String get nameHintToilet => 'e.g. \"Toilet at the park entrance\"';

  @override
  String get namePlace => 'Name / place';

  @override
  String nearestName(String name) {
    return 'Nearest: $name';
  }

  @override
  String get no => 'no';

  @override
  String get noAccountText =>
      'You are using the app without an account. Sign in with Apple or Google to rate, report and add photos.';

  @override
  String get noLocationNoAlerts =>
      'Without location access there are no proximity alerts.';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String get noReportNew => 'No, report new';

  @override
  String get noSeparate => 'No, separate';

  @override
  String get notNow => 'Not now';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get notSure => 'Not sure';

  @override
  String get note => 'Note';

  @override
  String get noteBabyChairTable => 'Baby chair and changing table';

  @override
  String get noteChangingTable => 'Changing table';

  @override
  String get noteConstruction => 'Closed for construction work';

  @override
  String get noteHeatedOnly => 'Heated tobacco only';

  @override
  String get noteHintBin => 'Where exactly, how to find it …';

  @override
  String get noteHintDefault => 'Opening hours, ashtray, access …';

  @override
  String get noteMenOnly => 'Men only';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get noteUnisex => 'Unisex';

  @override
  String get noteWomenAccessible =>
      'Women\'s toilet, also an accessible toilet';

  @override
  String get noteWomenOnly => 'Women only';

  @override
  String get notifChannelNearby => 'Smoking area nearby';

  @override
  String get notifChannelNearbyDesc =>
      'Notifies you when you come close to a smoking area.';

  @override
  String notifNearbyBody(String name, int meters) {
    return '$name – about $meters m away. Tap to open the map.';
  }

  @override
  String get notifNearbyTitle => 'Smoking area nearby';

  @override
  String officialDataVersion(String version) {
    return 'Official data version: $version – updated automatically, also via Reload.';
  }

  @override
  String offlineSavedData(String date) {
    return 'Offline – showing saved data from $date.';
  }

  @override
  String get ok => 'OK';

  @override
  String get openAgain => 'Open again';

  @override
  String get openNow => 'Open now';

  @override
  String get openingHours => 'Opening hours';

  @override
  String opensAt(String time) {
    return 'opens $time';
  }

  @override
  String get operator => 'Operator';

  @override
  String get osm => 'OSM';

  @override
  String get osmCopyright => 'Data © OpenStreetMap contributors';

  @override
  String get outdoors => 'Outdoors';

  @override
  String partOfHostText(String name, String category) {
    return '\"$name\" ($category) is right here. Is the trash can part of it (e.g. an ashtray with a bin)? Then it is added there instead of a new marker.';
  }

  @override
  String get partOfHostTitle => 'Part of this place?';

  @override
  String get photo => 'Photo';

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get photoUploadFailed => 'The photo could not be uploaded.';

  @override
  String get popularDistricts => 'Popular districts';

  @override
  String get position => 'Position';

  @override
  String get positionApprox => 'approximate (from the address, ± approx. 50 m)';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get profile => 'Profile';

  @override
  String get profilesOnDevice => 'Profiles on this device';

  @override
  String get publiclyAccessible => 'Publicly accessible';

  @override
  String get publiclyAccessibleSub => 'no ticket, entry fee or purchase needed';

  @override
  String get rate => 'Rate';

  @override
  String ratingSummary(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$average ($_temp0)';
  }

  @override
  String get reasonOffensive => 'Offensive or inappropriate';

  @override
  String get reasonOptional => 'Reason (optional)';

  @override
  String get reasonOther => 'Other';

  @override
  String get reasonPersonalData => 'Personal data of others';

  @override
  String get reasonSpam => 'Spam or advertising';

  @override
  String get reasonWrong => 'Wrong or misleading';

  @override
  String get reload => 'Reload';

  @override
  String get remove => 'Remove';

  @override
  String get removedAfterReports =>
      'Thanks! The place was removed after community reports.';

  @override
  String get removedByCommunity => 'removed by the community';

  @override
  String get rename => 'Rename';

  @override
  String get report => 'Report';

  @override
  String get reportASpot => 'Report a spot';

  @override
  String get reportHere => 'Report here';

  @override
  String get reportTitleBin => 'Report trash can';

  @override
  String get reportTitleSmoking => 'Report smoking area';

  @override
  String get reportTitleToilet => 'Report public toilet';

  @override
  String get reportedBy => 'Reported by';

  @override
  String reportedGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users reported',
      one: '1 user reported',
    );
    return '$_temp0 that this place is gone.';
  }

  @override
  String reportedOn(String date) {
    return 'Reported $date';
  }

  @override
  String get reportedVisibleNote =>
      'Reported spots are visible right away. If enough users report that a spot does not exist, it is removed again.';

  @override
  String resetToMeters(int meters) {
    return 'Reset to $meters m';
  }

  @override
  String get retry => 'Retry';

  @override
  String roomsInBuilding(int count) {
    return '$count in the same building';
  }

  @override
  String get route => 'Route';

  @override
  String sameplaceQuestion(String name, int meters) {
    return '\"$name\" is $meters m away. Is it the same place?';
  }

  @override
  String get save => 'Save';

  @override
  String get savedOffline =>
      'No connection – saved on this device and sent automatically later.';

  @override
  String get saving => 'Saving …';

  @override
  String get searchPlaceHint => 'Search city, district or prefecture';

  @override
  String get send => 'Send';

  @override
  String get sending => 'Sending …';

  @override
  String get settings => 'Settings';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get shownWithContributions => 'Shown with your contributions';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInDefaultReason => 'Sign in to rate, report and add photos.';

  @override
  String get signInFailed => 'Sign-in failed. Please try again.';

  @override
  String get signInPrivacyNote =>
      'Only your first name is shown with your contributions. Your location never leaves your device. By signing in you accept the terms of use.';

  @override
  String get signInToAddDetails => 'Sign in to add details.';

  @override
  String get signInToAddPhotos => 'Sign in to add photos.';

  @override
  String get signInToBlock => 'Sign in to block users.';

  @override
  String get signInToConfirm => 'Sign in to confirm places.';

  @override
  String get signInToContribute => 'Sign in to contribute.';

  @override
  String get signInToRate => 'Sign in to rate places.';

  @override
  String get signInToReport => 'Sign in to report new places.';

  @override
  String get signInToReportClosures => 'Sign in to report closures.';

  @override
  String get signInToReportContent => 'Sign in to report content.';

  @override
  String get signInToReportGone => 'Sign in to report places that are gone.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign out';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get smokingAreaAlerts => 'Smoking area alerts';

  @override
  String get smokingAreaAlertsSub =>
      'Notify me when I come close to a smoking area.';

  @override
  String smokingAreasInCity(int count) {
    return '$count smoking areas in this city';
  }

  @override
  String get smokingRoom => 'Smoking room';

  @override
  String get smokingRoomIndoors => 'Smoking room (indoors)';

  @override
  String get smokingRooms => 'Smoking rooms';

  @override
  String get someSourcesUnreachable => 'Some sources are unreachable.';

  @override
  String get source => 'Source';

  @override
  String sourceOfficial(String source) {
    return '$source (official)';
  }

  @override
  String get stillThereQuestion => 'Is this place still there?';

  @override
  String get switchProfile => 'Switch';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get temporarilyClosed => 'Temporarily closed';

  @override
  String get temporarilyClosedLower => 'temporarily closed';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String thanksHostHasBin(String name) {
    return 'Thanks! \"$name\" now shows a trash can.';
  }

  @override
  String get thanksReportReviewed => 'Thanks – the report will be reviewed.';

  @override
  String get thanksSpotOnMap => 'Thanks! Your spot is now on the map.';

  @override
  String get thanksSpotPhotoUploading =>
      'Thanks! Your spot is on the map – the photo is uploading.';

  @override
  String get thisUser => 'this user';

  @override
  String get tipAllowAlways =>
      'Tip: allow \"Always\" for alerts in the background.';

  @override
  String toiletNearest(String name, String distance) {
    return 'Toilet: $name · $distance';
  }

  @override
  String get translate => 'Translate';

  @override
  String get tryAgain => 'Try again';

  @override
  String get turnAlertsOff => 'Turn alerts off';

  @override
  String get turnAlertsOn => 'Turn alerts on';

  @override
  String get type => 'Type';

  @override
  String get unblock => 'Unblock';

  @override
  String get unknown => 'unknown';

  @override
  String get upload => 'Upload';

  @override
  String get uploadFailedTap => 'Failed – tap';

  @override
  String uploadedPartly(int done, int left) {
    return 'Uploaded $done, $left left – the rest is uploaded next time.';
  }

  @override
  String uploadedThanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions',
      one: '1 contribution',
    );
    return 'Uploaded $_temp0. Thanks!';
  }

  @override
  String get uploading => 'Uploading …';

  @override
  String voteNo(int count) {
    return 'No ($count)';
  }

  @override
  String voteYes(int count) {
    return 'Yes ($count)';
  }

  @override
  String wardName(String ward) {
    return '$ward ward';
  }

  @override
  String get wasteBottles => 'PET bottles';

  @override
  String get wasteCans => 'Cans';

  @override
  String get wasteTrash => 'General waste';

  @override
  String get whatToReport => 'What do you want to report?';

  @override
  String get wheelchairAccessible => 'Wheelchair accessible';

  @override
  String get yes => 'yes';

  @override
  String get yesAddToIt => 'Yes, add to it';

  @override
  String get yesShowIt => 'Yes, show it';
}
