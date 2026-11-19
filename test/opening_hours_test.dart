import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/i18n.dart';
import 'package:smoking_areas/models/opening_hours.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';
import 'package:smoking_areas/ui/hours_text.dart';

String? osm(String ja) => OpeningHours.parseJapanese(ja)?.toOsm();

void main() {
  setUpAll(() => initializeDateFormatting());
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));
  final ja = lookupAppLocalizations(const Locale('ja'));

  group('Japanese wording', () {
    test('around the clock', () {
      for (final s in [
        '終日',
        '00:00:00～23:59:00',
        '0:00～23:59',
        '00:00～00:00 ２４時間利用可能',
        '月曜日から日曜日（祝日含む）の終日',
        '24時間利用可能',
      ]) {
        expect(osm(s), '24/7', reason: s);
      }
      expect(osm('終日（注）年末年始閉鎖'), '24/7; Dec 29-Jan 03 off');
    });

    test('days, times and closures', () {
      expect(osm('月曜日から日曜日（祝日含む）の10時から22時30分まで'),
          '10:00-22:30');
      expect(osm('月曜日から金曜日（祝日除く）の9時から17時まで'),
          'Mo-Fr 09:00-17:00; PH off');
      expect(osm('午前7時～午後8時（土曜日・日曜日・祝日・年末年始を除く）'),
          'Mo-Fr 07:00-20:00; PH off; Dec 29-Jan 03 off');
      expect(osm('８時～２１時（注）土曜日、日曜日、祝日を除く'),
          'Mo-Fr 08:00-21:00; PH off');
      expect(osm('月曜日、火曜日、木曜日、金曜日、土曜日（祝日除く）の9時30分から18時まで'),
          'Mo,Tu,Th-Sa 09:30-18:00; PH off');
      expect(osm('平日9時～18時'), 'Mo-Fr 09:00-18:00');
      expect(osm('7:00～19:00 年末年始利用不可'),
          '07:00-19:00; Dec 29-Jan 03 off');
    });

    test('times past midnight and 12-hour times', () {
      expect(osm('5時～25時'), '05:00-25:00');
      expect(osm('午前6時～翌午前12時30分'), '06:00-24:30');
      expect(osm('午前9時から午後5時まで'), '09:00-17:00');
    });

    test('anything not understood for sure yields null', () {
      for (final s in [
        '午前9時～午後9時（土曜日・日曜日・祝日・お盆・年末年始を除く）',
        '8:30～19:00 10月～3月　18:00まで',
        '利用時間等の制限あり',
        'A: 7時～22時\nB: 8時～20時',
        '7時～21時（注）16時30分～16時50分は利用不可',
      ]) {
        expect(OpeningHours.parseJapanese(s), isNull, reason: s);
      }
    });
  });

  group('OSM syntax', () {
    test('round trip of the common subset', () {
      for (final s in [
        '24/7',
        'Mo-Fr 08:00-18:00; PH off',
        'Mo-Fr 07:00-20:00; Sa 10:00-14:00; Dec 29-Jan 03 off',
        '10:00-22:00',
        'Mo,We,Fr 09:00-12:00,13:00-17:00',
      ]) {
        expect(OpeningHours.parseOsm(s)?.toOsm(), s, reason: s);
      }
      expect(OpeningHours.parseOsm('Mo-Su 00:00-24:00')?.toOsm(), '24/7');
      expect(OpeningHours.parseOsm('Mo-Fr 08:00-18:00 "by appointment"'),
          isNull);
      expect(OpeningHours.parseOsm('sunrise-sunset'), isNull);
    });
  });

  group('display', () {
    test('in the UI language', () {
      const raw = '午前7時～午後8時（土曜日・日曜日・祝日・年末年始を除く）';
      expect(hoursText(raw, en, 'en'),
          'Mon–Fri 7:00–20:00\n'
          'Closed: public holidays, New Year holidays (Dec 29 – Jan 3)');
      expect(hoursText(raw, de, 'de'),
          'Mo–Fr 7:00–20:00\nGeschlossen: Feiertage, Neujahrstage (29.12.–3.1.)');
      // Japanese source text stays as it is in Japanese.
      expect(hoursText(raw, ja, 'ja'), raw);
      expect(hoursText('Mo-Fr 08:00-18:00; PH off', ja, 'ja'),
          '月–金 8:00–18:00\n休み：祝日');
      expect(hoursText('終日', en, 'en'), 'Open 24 hours');
      expect(hoursText('5時～25時', en, 'en'), '5:00–1:00 (next day)');
      expect(hoursText('0:00～24:00', en, 'en'), 'Open 24 hours');
      // Not understood: the original text.
      expect(hoursText('利用時間等の制限あり', en, 'en'), '利用時間等の制限あり');
    });

    test('frequent notes are translated', () {
      expect(noteText('ベビーチェア・ベビーシート', en, 'en'),
          'Baby chair and changing table');
      expect(noteText('男女共用', de, 'de'), 'Für alle Geschlechter');
      expect(noteText('土日祝日、年末年始は休業\n※加熱式たばこ専用', en, 'en'),
          'Closed: Sat, Sun, public holidays, New Year holidays '
          '(Dec 29 – Jan 3)\nHeated tobacco only');
      expect(noteText('南口駅前交番横', en, 'en'), isNull);
      expect(noteText('男女共用', ja, 'ja'), isNull);
      expect(noteText('Behind the station', en, 'en'), isNull);
    });

    test('translate link', () {
      final uri = translateUri('南口駅前交番横', 'de');
      expect(uri.host, 'translate.google.com');
      expect(uri.queryParameters['tl'], 'de');
      expect(uri.queryParameters['text'], '南口駅前交番横');
    });
  });

  testWidgets('details offer a translation for unknown Japanese notes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AreaDetailsSheet(
          area: SmokingArea(
            id: 'official:1',
            position: LatLng(35.69, 139.70),
            source: 'Tokyo',
            tags: {
              'official': 'yes',
              'amenity': 'smoking_area',
              'opening_hours': '月曜日から金曜日（祝日除く）の9時から17時まで',
              'note': '南口駅前交番横',
            },
          ),
        ),
      ),
    ));
    expect(find.text('Mon–Fri 9:00–17:00\nClosed: public holidays'),
        findsOneWidget);
    expect(find.text('南口駅前交番横'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
  });
}
