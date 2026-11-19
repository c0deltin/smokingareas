import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @accepts.
  ///
  /// In en, this message translates to:
  /// **'Accepts'**
  String get accepts;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @accessHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. station platform – ticket only, inside a museum'**
  String get accessHint;

  /// No description provided for @accessNotPublic.
  ///
  /// In en, this message translates to:
  /// **'not public (ticket, entry fee or purchase needed)'**
  String get accessNotPublic;

  /// No description provided for @accessOptional.
  ///
  /// In en, this message translates to:
  /// **'Access (optional)'**
  String get accessOptional;

  /// No description provided for @accessPublic.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get accessPublic;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountActions.
  ///
  /// In en, this message translates to:
  /// **'Account, sign out, delete account'**
  String get accountActions;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account – please try again.'**
  String get accountDeleteFailed;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get accountDeleted;

  /// No description provided for @activeProfile.
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get activeProfile;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @alertRadius.
  ///
  /// In en, this message translates to:
  /// **'Alert radius'**
  String get alertRadius;

  /// No description provided for @alertRadiusHelp.
  ///
  /// In en, this message translates to:
  /// **'Small radius: alerts only right next to a smoking area. Large radius: earlier alerts, but more of them in dense areas. The blue circle around your location shows the radius.'**
  String get alertRadiusHelp;

  /// No description provided for @alertsOff.
  ///
  /// In en, this message translates to:
  /// **'Alerts off.'**
  String get alertsOff;

  /// No description provided for @alertsOnWithin.
  ///
  /// In en, this message translates to:
  /// **'Alerts on: you will be notified within {meters} m.'**
  String alertsOnWithin(int meters);

  /// No description provided for @alreadyOnMap.
  ///
  /// In en, this message translates to:
  /// **'Already on the map?'**
  String get alreadyOnMap;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Ippuku'**
  String get appTitle;

  /// No description provided for @asUser.
  ///
  /// In en, this message translates to:
  /// **'as {name}'**
  String asUser(String name);

  /// No description provided for @babyChanging.
  ///
  /// In en, this message translates to:
  /// **'Baby changing'**
  String get babyChanging;

  /// No description provided for @binHereQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is there a trash can here?'**
  String get binHereQuestion;

  /// No description provided for @binNo.
  ///
  /// In en, this message translates to:
  /// **'None ({count})'**
  String binNo(int count);

  /// No description provided for @binNone.
  ///
  /// In en, this message translates to:
  /// **'No trash can here.'**
  String get binNone;

  /// No description provided for @binShown.
  ///
  /// In en, this message translates to:
  /// **'Shown with a trash can on the map.'**
  String get binShown;

  /// No description provided for @binYes.
  ///
  /// In en, this message translates to:
  /// **'Trash can ({count})'**
  String binYes(int count);

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @blockExplain.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see their places, ratings and photos. You can undo this in Settings → Account.'**
  String get blockExplain;

  /// No description provided for @blockName.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockName(String name);

  /// No description provided for @blockNameQuestion.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockNameQuestion(String name);

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @catBin.
  ///
  /// In en, this message translates to:
  /// **'Trash can'**
  String get catBin;

  /// No description provided for @catBinPlural.
  ///
  /// In en, this message translates to:
  /// **'Trash cans'**
  String get catBinPlural;

  /// No description provided for @catSmoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking area'**
  String get catSmoking;

  /// No description provided for @catSmokingPlural.
  ///
  /// In en, this message translates to:
  /// **'Smoking areas'**
  String get catSmokingPlural;

  /// No description provided for @catToilet.
  ///
  /// In en, this message translates to:
  /// **'Public toilet'**
  String get catToilet;

  /// No description provided for @catToiletPlural.
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get catToiletPlural;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @changeRating.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeRating;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get closedNow;

  /// No description provided for @closedOfficially.
  ///
  /// In en, this message translates to:
  /// **'Closed according to the official list.'**
  String get closedOfficially;

  /// No description provided for @closesAt.
  ///
  /// In en, this message translates to:
  /// **'closes {time}'**
  String closesAt(String time);

  /// No description provided for @closureHint.
  ///
  /// In en, this message translates to:
  /// **'Blocked, construction, out of order? Report it – the report expires after 14 days or on the date you set.'**
  String get closureHint;

  /// No description provided for @closureInfo.
  ///
  /// In en, this message translates to:
  /// **'{closed, plural, =1{1 \"closed\" report} other{{closed} \"closed\" reports}}{reopened, plural, =0{} =1{, 1 \"reopened\"} other{, {reopened} \"reopened\"}}'**
  String closureInfo(int closed, int reopened);

  /// No description provided for @closureReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. construction, out of order, blocked'**
  String get closureReasonHint;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional): clean, crowded, easy to find …'**
  String get commentHint;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continueWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue without account'**
  String get continueWithoutAccount;

  /// No description provided for @couldNotLoadData.
  ///
  /// In en, this message translates to:
  /// **'Could not load data.'**
  String get couldNotLoadData;

  /// No description provided for @covered.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get covered;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get createProfile;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources:'**
  String get dataSources;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountText.
  ///
  /// In en, this message translates to:
  /// **'Your account, ratings, photos, votes and closure reports are deleted for good. Places you reported stay on the map without your name.'**
  String get deleteAccountText;

  /// No description provided for @deleteSpotQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteSpotQuestion(String name);

  /// No description provided for @deleteSpotText.
  ///
  /// In en, this message translates to:
  /// **'The place is removed from the map for everyone.'**
  String get deleteSpotText;

  /// No description provided for @detailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get detailsOptional;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @distanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String distanceAway(String distance);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editTitleBin.
  ///
  /// In en, this message translates to:
  /// **'Edit trash can'**
  String get editTitleBin;

  /// No description provided for @editTitleSmoking.
  ///
  /// In en, this message translates to:
  /// **'Edit smoking area'**
  String get editTitleSmoking;

  /// No description provided for @editTitleToilet.
  ///
  /// In en, this message translates to:
  /// **'Edit public toilet'**
  String get editTitleToilet;

  /// No description provided for @endUnknown.
  ///
  /// In en, this message translates to:
  /// **'End unknown (expires after 14 days)'**
  String get endUnknown;

  /// No description provided for @errConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not save – please check your connection.'**
  String get errConnection;

  /// No description provided for @errCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save ({reason}).'**
  String errCouldNotSave(String reason);

  /// No description provided for @errRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many contributions in a short time – please try again later.'**
  String get errRateLimit;

  /// No description provided for @errSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first.'**
  String get errSignInFirst;

  /// No description provided for @expectedUntil.
  ///
  /// In en, this message translates to:
  /// **'expected until {date}'**
  String expectedUntil(String date);

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @fgAlertsOnText.
  ///
  /// In en, this message translates to:
  /// **'You will be notified when a smoking area is within {meters} m.'**
  String fgAlertsOnText(int meters);

  /// No description provided for @fgAlertsOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Smoking area alerts on'**
  String get fgAlertsOnTitle;

  /// No description provided for @fgChannel.
  ///
  /// In en, this message translates to:
  /// **'Location monitoring'**
  String get fgChannel;

  /// No description provided for @goneText.
  ///
  /// In en, this message translates to:
  /// **'If enough users report that this place is gone, it is removed from the map.'**
  String get goneText;

  /// No description provided for @goneTitle.
  ///
  /// In en, this message translates to:
  /// **'Gone?'**
  String get goneTitle;

  /// No description provided for @hasTrashCan.
  ///
  /// In en, this message translates to:
  /// **'Has a trash can'**
  String get hasTrashCan;

  /// No description provided for @hoursAlways.
  ///
  /// In en, this message translates to:
  /// **'Open 24 hours'**
  String get hoursAlways;

  /// No description provided for @hoursClosedOn.
  ///
  /// In en, this message translates to:
  /// **'Closed: {days}'**
  String hoursClosedOn(String days);

  /// No description provided for @hoursHolidays.
  ///
  /// In en, this message translates to:
  /// **'public holidays'**
  String get hoursHolidays;

  /// No description provided for @hoursNewYear.
  ///
  /// In en, this message translates to:
  /// **'New Year holidays (Dec 29 – Jan 3)'**
  String get hoursNewYear;

  /// No description provided for @hoursNextDay.
  ///
  /// In en, this message translates to:
  /// **'{time} (next day)'**
  String hoursNextDay(String time);

  /// No description provided for @imprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint'**
  String get imprint;

  /// No description provided for @inThisCity.
  ///
  /// In en, this message translates to:
  /// **'{count} in this city'**
  String inThisCity(int count);

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @infoAbout.
  ///
  /// In en, this message translates to:
  /// **'Shows public smoking areas (喫煙所, green) and public toilets (公衆トイレ, blue) all over Japan, plus trash cans (ゴミ箱, orange) reported by users. Many Japanese cities ban smoking on the street and only allow it in designated areas.\n\nWith alerts on you get a notification as soon as you come close to a smoking area (radius configurable in Settings) – also while the app runs in the background (not for toilets).\n'**
  String get infoAbout;

  /// No description provided for @infoLegendMerge.
  ///
  /// In en, this message translates to:
  /// **'The legend (menu ⋮) explains all symbols. Official entries (gold ring) come from lists published by cities and wards; if an OSM entry is at the same place, both are merged into one marker. Addresses published without coordinates were located with the GSI address search and are marked as \"approximate\".'**
  String get infoLegendMerge;

  /// No description provided for @infoMapCredits.
  ///
  /// In en, this message translates to:
  /// **'Map: Google Maps. Spot data from OpenStreetMap: © OpenStreetMap contributors (ODbL).\nNo guarantee of accuracy – you can fix missing or wrong entries directly on openstreetmap.org (amenity=smoking_area, amenity=toilets).'**
  String get infoMapCredits;

  /// No description provided for @initialSignInReason.
  ///
  /// In en, this message translates to:
  /// **'Browse without an account, or sign in to rate, report and add photos.'**
  String get initialSignInReason;

  /// No description provided for @legAlertRadius.
  ///
  /// In en, this message translates to:
  /// **'Alert radius for nearby smoking areas.'**
  String get legAlertRadius;

  /// No description provided for @legBin.
  ///
  /// In en, this message translates to:
  /// **'Trash can (reported by users).'**
  String get legBin;

  /// No description provided for @legBinBadge.
  ///
  /// In en, this message translates to:
  /// **'Orange badge: has a trash can.'**
  String get legBinBadge;

  /// No description provided for @legCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (fill colour)'**
  String get legCategory;

  /// No description provided for @legClosed.
  ///
  /// In en, this message translates to:
  /// **'Grey with pause badge: temporarily closed.'**
  String get legClosed;

  /// No description provided for @legClusterBin.
  ///
  /// In en, this message translates to:
  /// **'Several trash cans – tap to zoom in.'**
  String get legClusterBin;

  /// No description provided for @legClusterSmoking.
  ///
  /// In en, this message translates to:
  /// **'Several smoking areas – tap to zoom in.'**
  String get legClusterSmoking;

  /// No description provided for @legClusterToilet.
  ///
  /// In en, this message translates to:
  /// **'Several toilets – tap to zoom in.'**
  String get legClusterToilet;

  /// No description provided for @legGold.
  ///
  /// In en, this message translates to:
  /// **'Gold: from an official list of the city or ward.'**
  String get legGold;

  /// No description provided for @legIndoorSmoking.
  ///
  /// In en, this message translates to:
  /// **'Indoor smoking room.'**
  String get legIndoorSmoking;

  /// No description provided for @legMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get legMap;

  /// No description provided for @legOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin (ring)'**
  String get legOrigin;

  /// No description provided for @legOutdoorSmoking.
  ///
  /// In en, this message translates to:
  /// **'Outdoor smoking area.'**
  String get legOutdoorSmoking;

  /// No description provided for @legPink.
  ///
  /// In en, this message translates to:
  /// **'Pink: reported by a user.'**
  String get legPink;

  /// No description provided for @legStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get legStatus;

  /// No description provided for @legToilet.
  ///
  /// In en, this message translates to:
  /// **'Public toilet.'**
  String get legToilet;

  /// No description provided for @legWhite.
  ///
  /// In en, this message translates to:
  /// **'White: entry from OpenStreetMap.'**
  String get legWhite;

  /// No description provided for @legYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location – the cone shows the direction you are facing.'**
  String get legYourLocation;

  /// No description provided for @legend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get legend;

  /// No description provided for @loadingSmokingAreas.
  ///
  /// In en, this message translates to:
  /// **'Loading smoking areas …'**
  String get loadingSmokingAreas;

  /// No description provided for @localDataRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed the contributions from this device.'**
  String get localDataRemoved;

  /// No description provided for @localDataText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 contribution was} other{{count} contributions were}} (places, ratings, photos, reports) saved only on this device. Upload {count, plural, =1{it} other{them}} to your account so everyone can see {count, plural, =1{it} other{them}}?'**
  String localDataText(int count);

  /// No description provided for @localDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions on this device'**
  String get localDataTitle;

  /// No description provided for @localProfilesNote.
  ///
  /// In en, this message translates to:
  /// **'Ratings, photos and reports are currently stored only on this device and assigned to the active profile. Several profiles let you try out e.g. that a spot disappears after three \"gone\" reports.'**
  String get localProfilesNote;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locationServicesOff;

  /// No description provided for @locationUseText.
  ///
  /// In en, this message translates to:
  /// **'Ippuku uses your location to show nearby smoking areas and public toilets on the map.\n\nIf you turn on alerts, the app also uses your location in the background – even when the app is closed or not in use – to notify you when you are close to a designated smoking area.\n\nYour location is processed only on your device. It is never sent to us or shared with anyone. You can turn alerts off at any time.'**
  String get locationUseText;

  /// No description provided for @locationUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Use of your location'**
  String get locationUseTitle;

  /// No description provided for @mapDataUpdated.
  ///
  /// In en, this message translates to:
  /// **'Map data updated ({version}).'**
  String mapDataUpdated(String version);

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String meters(int meters);

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moveCrossHint.
  ///
  /// In en, this message translates to:
  /// **'{category}: move the map until the cross is exactly on the spot.'**
  String moveCrossHint(String category);

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @mySpots.
  ///
  /// In en, this message translates to:
  /// **'My spots'**
  String get mySpots;

  /// No description provided for @mySpotsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not reported any places yet. Use the \"Report a spot\" button on the map.'**
  String get mySpotsEmpty;

  /// No description provided for @mySpotsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see and manage the places you reported.'**
  String get mySpotsSignIn;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameHintBin.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Bins next to the vending machines\"'**
  String get nameHintBin;

  /// No description provided for @nameHintSmoking.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Smoking corner next to FamilyMart\"'**
  String get nameHintSmoking;

  /// No description provided for @nameHintToilet.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Toilet at the park entrance\"'**
  String get nameHintToilet;

  /// No description provided for @namePlace.
  ///
  /// In en, this message translates to:
  /// **'Name / place'**
  String get namePlace;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @nearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing within 2 km.'**
  String get nearbyEmpty;

  /// No description provided for @nearbyNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is not known yet.'**
  String get nearbyNoLocation;

  /// No description provided for @nearestName.
  ///
  /// In en, this message translates to:
  /// **'Nearest: {name}'**
  String nearestName(String name);

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @noAccountText.
  ///
  /// In en, this message translates to:
  /// **'You are using the app without an account. Sign in with Apple or Google to rate, report and add photos.'**
  String get noAccountText;

  /// No description provided for @noLocationNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'Without location access there are no proximity alerts.'**
  String get noLocationNoAlerts;

  /// No description provided for @noRatingsYet.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get noRatingsYet;

  /// No description provided for @noReportNew.
  ///
  /// In en, this message translates to:
  /// **'No, report new'**
  String get noReportNew;

  /// No description provided for @noSeparate.
  ///
  /// In en, this message translates to:
  /// **'No, separate'**
  String get noSeparate;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteBabyChairTable.
  ///
  /// In en, this message translates to:
  /// **'Baby chair and changing table'**
  String get noteBabyChairTable;

  /// No description provided for @noteChangingTable.
  ///
  /// In en, this message translates to:
  /// **'Changing table'**
  String get noteChangingTable;

  /// No description provided for @noteConstruction.
  ///
  /// In en, this message translates to:
  /// **'Closed for construction work'**
  String get noteConstruction;

  /// No description provided for @noteHeatedOnly.
  ///
  /// In en, this message translates to:
  /// **'Heated tobacco only'**
  String get noteHeatedOnly;

  /// No description provided for @noteHintBin.
  ///
  /// In en, this message translates to:
  /// **'Where exactly, how to find it …'**
  String get noteHintBin;

  /// No description provided for @noteHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Opening hours, ashtray, access …'**
  String get noteHintDefault;

  /// No description provided for @noteMenOnly.
  ///
  /// In en, this message translates to:
  /// **'Men only'**
  String get noteMenOnly;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @noteUnisex.
  ///
  /// In en, this message translates to:
  /// **'Unisex'**
  String get noteUnisex;

  /// No description provided for @noteWomenAccessible.
  ///
  /// In en, this message translates to:
  /// **'Women\'s toilet, also an accessible toilet'**
  String get noteWomenAccessible;

  /// No description provided for @noteWomenOnly.
  ///
  /// In en, this message translates to:
  /// **'Women only'**
  String get noteWomenOnly;

  /// No description provided for @notifChannelNearby.
  ///
  /// In en, this message translates to:
  /// **'Smoking area nearby'**
  String get notifChannelNearby;

  /// No description provided for @notifChannelNearbyDesc.
  ///
  /// In en, this message translates to:
  /// **'Notifies you when you come close to a smoking area.'**
  String get notifChannelNearbyDesc;

  /// No description provided for @notifNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'{name} – about {meters} m away. Tap to open the map.'**
  String notifNearbyBody(String name, int meters);

  /// No description provided for @notifNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Smoking area nearby'**
  String get notifNearbyTitle;

  /// No description provided for @officialDataVersion.
  ///
  /// In en, this message translates to:
  /// **'Official data version: {version} – updated automatically, also via Reload.'**
  String officialDataVersion(String version);

  /// No description provided for @offlineSavedData.
  ///
  /// In en, this message translates to:
  /// **'Offline – showing saved data from {date}.'**
  String offlineSavedData(String date);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @openAgain.
  ///
  /// In en, this message translates to:
  /// **'Open again'**
  String get openAgain;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @opensAt.
  ///
  /// In en, this message translates to:
  /// **'opens {time}'**
  String opensAt(String time);

  /// No description provided for @operator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operator;

  /// No description provided for @osm.
  ///
  /// In en, this message translates to:
  /// **'OSM'**
  String get osm;

  /// No description provided for @osmCopyright.
  ///
  /// In en, this message translates to:
  /// **'Data © OpenStreetMap contributors'**
  String get osmCopyright;

  /// No description provided for @outdoors.
  ///
  /// In en, this message translates to:
  /// **'Outdoors'**
  String get outdoors;

  /// No description provided for @partOfHostText.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" ({category}) is right here. Is the trash can part of it (e.g. an ashtray with a bin)? Then it is added there instead of a new marker.'**
  String partOfHostText(String name, String category);

  /// No description provided for @partOfHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Part of this place?'**
  String get partOfHostTitle;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @photoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String photoCount(int count);

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be uploaded.'**
  String get photoUploadFailed;

  /// No description provided for @popularDistricts.
  ///
  /// In en, this message translates to:
  /// **'Popular districts'**
  String get popularDistricts;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @positionApprox.
  ///
  /// In en, this message translates to:
  /// **'approximate (from the address, ± approx. 50 m)'**
  String get positionApprox;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profilesOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Profiles on this device'**
  String get profilesOnDevice;

  /// No description provided for @publiclyAccessible.
  ///
  /// In en, this message translates to:
  /// **'Publicly accessible'**
  String get publiclyAccessible;

  /// No description provided for @publiclyAccessibleSub.
  ///
  /// In en, this message translates to:
  /// **'no ticket, entry fee or purchase needed'**
  String get publiclyAccessibleSub;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @ratingSummary.
  ///
  /// In en, this message translates to:
  /// **'{average} ({count, plural, =1{1 rating} other{{count} ratings}})'**
  String ratingSummary(String average, int count);

  /// No description provided for @reasonOffensive.
  ///
  /// In en, this message translates to:
  /// **'Offensive or inappropriate'**
  String get reasonOffensive;

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reasonPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Personal data of others'**
  String get reasonPersonalData;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reasonSpam;

  /// No description provided for @reasonWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong or misleading'**
  String get reasonWrong;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removedAfterReports.
  ///
  /// In en, this message translates to:
  /// **'Thanks! The place was removed after community reports.'**
  String get removedAfterReports;

  /// No description provided for @removedByCommunity.
  ///
  /// In en, this message translates to:
  /// **'removed by the community'**
  String get removedByCommunity;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportASpot.
  ///
  /// In en, this message translates to:
  /// **'Report a spot'**
  String get reportASpot;

  /// No description provided for @reportHere.
  ///
  /// In en, this message translates to:
  /// **'Report here'**
  String get reportHere;

  /// No description provided for @reportTitleBin.
  ///
  /// In en, this message translates to:
  /// **'Report trash can'**
  String get reportTitleBin;

  /// No description provided for @reportTitleSmoking.
  ///
  /// In en, this message translates to:
  /// **'Report smoking area'**
  String get reportTitleSmoking;

  /// No description provided for @reportTitleToilet.
  ///
  /// In en, this message translates to:
  /// **'Report public toilet'**
  String get reportTitleToilet;

  /// No description provided for @reportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by'**
  String get reportedBy;

  /// No description provided for @reportedGone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 user reported} other{{count} users reported}} that this place is gone.'**
  String reportedGone(int count);

  /// No description provided for @reportedOn.
  ///
  /// In en, this message translates to:
  /// **'Reported {date}'**
  String reportedOn(String date);

  /// No description provided for @reportedVisibleNote.
  ///
  /// In en, this message translates to:
  /// **'Reported spots are visible right away. If enough users report that a spot does not exist, it is removed again.'**
  String get reportedVisibleNote;

  /// No description provided for @resetToMeters.
  ///
  /// In en, this message translates to:
  /// **'Reset to {meters} m'**
  String resetToMeters(int meters);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @roomsInBuilding.
  ///
  /// In en, this message translates to:
  /// **'{count} in the same building'**
  String roomsInBuilding(int count);

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @sameplaceQuestion.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is {meters} m away. Is it the same place?'**
  String sameplaceQuestion(String name, int meters);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection – saved on this device and sent automatically later.'**
  String get savedOffline;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving …'**
  String get saving;

  /// No description provided for @searchPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Search city, district or prefecture'**
  String get searchPlaceHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending …'**
  String get sending;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @shownWithContributions.
  ///
  /// In en, this message translates to:
  /// **'Shown with your contributions'**
  String get shownWithContributions;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate, report and add photos.'**
  String get signInDefaultReason;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// No description provided for @signInPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Only your first name is shown with your contributions. Your location never leaves your device. By signing in you accept the terms of use.'**
  String get signInPrivacyNote;

  /// No description provided for @signInToAddDetails.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add details.'**
  String get signInToAddDetails;

  /// No description provided for @signInToAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Sign in to add photos.'**
  String get signInToAddPhotos;

  /// No description provided for @signInToBlock.
  ///
  /// In en, this message translates to:
  /// **'Sign in to block users.'**
  String get signInToBlock;

  /// No description provided for @signInToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign in to confirm places.'**
  String get signInToConfirm;

  /// No description provided for @signInToContribute.
  ///
  /// In en, this message translates to:
  /// **'Sign in to contribute.'**
  String get signInToContribute;

  /// No description provided for @signInToRate.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate places.'**
  String get signInToRate;

  /// No description provided for @signInToReport.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report new places.'**
  String get signInToReport;

  /// No description provided for @signInToReportClosures.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report closures.'**
  String get signInToReportClosures;

  /// No description provided for @signInToReportContent.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report content.'**
  String get signInToReportContent;

  /// No description provided for @signInToReportGone.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report places that are gone.'**
  String get signInToReportGone;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// No description provided for @smokingAreaAlerts.
  ///
  /// In en, this message translates to:
  /// **'Smoking area alerts'**
  String get smokingAreaAlerts;

  /// No description provided for @smokingAreaAlertsSub.
  ///
  /// In en, this message translates to:
  /// **'Notify me when I come close to a smoking area.'**
  String get smokingAreaAlertsSub;

  /// No description provided for @smokingAreasInCity.
  ///
  /// In en, this message translates to:
  /// **'{count} smoking areas in this city'**
  String smokingAreasInCity(int count);

  /// No description provided for @smokingRoom.
  ///
  /// In en, this message translates to:
  /// **'Smoking room'**
  String get smokingRoom;

  /// No description provided for @smokingRoomIndoors.
  ///
  /// In en, this message translates to:
  /// **'Smoking room (indoors)'**
  String get smokingRoomIndoors;

  /// No description provided for @smokingRooms.
  ///
  /// In en, this message translates to:
  /// **'Smoking rooms'**
  String get smokingRooms;

  /// No description provided for @someSourcesUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Some sources are unreachable.'**
  String get someSourcesUnreachable;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @sourceOfficial.
  ///
  /// In en, this message translates to:
  /// **'{source} (official)'**
  String sourceOfficial(String source);

  /// No description provided for @stillThereQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is this place still there?'**
  String get stillThereQuestion;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchProfile;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @temporarilyClosed.
  ///
  /// In en, this message translates to:
  /// **'Temporarily closed'**
  String get temporarilyClosed;

  /// No description provided for @temporarilyClosedLower.
  ///
  /// In en, this message translates to:
  /// **'temporarily closed'**
  String get temporarilyClosedLower;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @thanksHostHasBin.
  ///
  /// In en, this message translates to:
  /// **'Thanks! \"{name}\" now shows a trash can.'**
  String thanksHostHasBin(String name);

  /// No description provided for @thanksReportReviewed.
  ///
  /// In en, this message translates to:
  /// **'Thanks – the report will be reviewed.'**
  String get thanksReportReviewed;

  /// No description provided for @thanksSpotOnMap.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your spot is now on the map.'**
  String get thanksSpotOnMap;

  /// No description provided for @thanksSpotPhotoUploading.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your spot is on the map – the photo is uploading.'**
  String get thanksSpotPhotoUploading;

  /// No description provided for @thisUser.
  ///
  /// In en, this message translates to:
  /// **'this user'**
  String get thisUser;

  /// No description provided for @tipAllowAlways.
  ///
  /// In en, this message translates to:
  /// **'Tip: allow \"Always\" for alerts in the background.'**
  String get tipAllowAlways;

  /// No description provided for @toiletNearest.
  ///
  /// In en, this message translates to:
  /// **'Toilet: {name} · {distance}'**
  String toiletNearest(String name, String distance);

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @turnAlertsOff.
  ///
  /// In en, this message translates to:
  /// **'Turn alerts off'**
  String get turnAlertsOff;

  /// No description provided for @turnAlertsOn.
  ///
  /// In en, this message translates to:
  /// **'Turn alerts on'**
  String get turnAlertsOn;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknown;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @uploadFailedTap.
  ///
  /// In en, this message translates to:
  /// **'Failed – tap'**
  String get uploadFailedTap;

  /// No description provided for @uploadedPartly.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {done}, {left} left – the rest is uploaded next time.'**
  String uploadedPartly(int done, int left);

  /// No description provided for @uploadedThanks.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {count, plural, =1{1 contribution} other{{count} contributions}}. Thanks!'**
  String uploadedThanks(int count);

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading …'**
  String get uploading;

  /// No description provided for @voteNo.
  ///
  /// In en, this message translates to:
  /// **'No ({count})'**
  String voteNo(int count);

  /// No description provided for @voteYes.
  ///
  /// In en, this message translates to:
  /// **'Yes ({count})'**
  String voteYes(int count);

  /// No description provided for @wardName.
  ///
  /// In en, this message translates to:
  /// **'{ward} ward'**
  String wardName(String ward);

  /// No description provided for @wasteBottles.
  ///
  /// In en, this message translates to:
  /// **'PET bottles'**
  String get wasteBottles;

  /// No description provided for @wasteCans.
  ///
  /// In en, this message translates to:
  /// **'Cans'**
  String get wasteCans;

  /// No description provided for @wasteTrash.
  ///
  /// In en, this message translates to:
  /// **'General waste'**
  String get wasteTrash;

  /// No description provided for @whatToReport.
  ///
  /// In en, this message translates to:
  /// **'What do you want to report?'**
  String get whatToReport;

  /// No description provided for @wheelchairAccessible.
  ///
  /// In en, this message translates to:
  /// **'Wheelchair accessible'**
  String get wheelchairAccessible;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @yesAddToIt.
  ///
  /// In en, this message translates to:
  /// **'Yes, add to it'**
  String get yesAddToIt;

  /// No description provided for @yesShowIt.
  ///
  /// In en, this message translates to:
  /// **'Yes, show it'**
  String get yesShowIt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
