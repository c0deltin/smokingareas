import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';
import 'models/smoking_area.dart';

export 'l10n/app_localizations.dart';

/// Short access to the UI texts: `context.l10n.save`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// UI language: the device language when the app supports it, else
/// English.
Locale resolveAppLocale(Locale? device, Iterable<Locale> supported) {
  for (final s in supported) {
    if (s.languageCode == device?.languageCode) return s;
  }
  return const Locale('en');
}

/// A day in the UI language, e.g. "Dec 24, 2026" / "24.12.2026" /
/// "2026年12月24日".
String formatDay(BuildContext context, DateTime day) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .format(day);

/// Texts outside of widgets (notifications, background service): the
/// device language, English when it is not supported.
AppLocalizations deviceL10n() {
  for (final l in PlatformDispatcher.instance.locales) {
    for (final s in AppLocalizations.supportedLocales) {
      if (s.languageCode == l.languageCode) return lookupAppLocalizations(s);
    }
  }
  return lookupAppLocalizations(const Locale('en'));
}

extension CategoryText on AppLocalizations {
  String category(SpotCategory c) => switch (c) {
        SpotCategory.smoking => catSmoking,
        SpotCategory.toilet => catToilet,
        SpotCategory.bin => catBin,
      };

  String categories(SpotCategory c) => switch (c) {
        SpotCategory.smoking => catSmokingPlural,
        SpotCategory.toilet => catToiletPlural,
        SpotCategory.bin => catBinPlural,
      };

  String waste(WasteType t) => switch (t) {
        WasteType.trash => wasteTrash,
        WasteType.cans => wasteCans,
        WasteType.bottles => wasteBottles,
      };

  /// Spot title for the UI: the name, else the localised category.
  String title(SmokingArea a) {
    final n = a.name ?? a.tags['name:en'] ?? a.tags['name:ja'];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return category(a.category);
  }
}
