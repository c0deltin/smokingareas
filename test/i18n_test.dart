import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoking_areas/i18n.dart';
import 'package:smoking_areas/ui/location_disclosure.dart';

void main() {
  test('device language when supported, otherwise English', () {
    const supported = AppLocalizations.supportedLocales;
    expect(resolveAppLocale(const Locale('ja', 'JP'), supported).languageCode,
        'ja');
    expect(resolveAppLocale(const Locale('de', 'AT'), supported).languageCode,
        'de');
    expect(resolveAppLocale(const Locale('fr', 'FR'), supported),
        const Locale('en'));
    expect(resolveAppLocale(null, supported), const Locale('en'));
  });

  for (final (lang, title) in [
    ('en', 'Use of your location'),
    ('de', 'Nutzung deines Standorts'),
    ('ja', '位置情報の利用について'),
    ('fr', 'Use of your location'), // not supported: English
  ]) {
    testWidgets('UI in $lang', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: resolveAppLocale,
        home: const Scaffold(body: LocationDisclosureDialog()),
      ));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    });
  }

  test('texts outside of widgets are translated too', () {
    expect(lookupAppLocalizations(const Locale('de')).catSmoking,
        'Raucherbereich');
    expect(lookupAppLocalizations(const Locale('ja')).catToilet, '公衆トイレ');
  });
}
