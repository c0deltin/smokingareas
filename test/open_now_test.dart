import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/i18n.dart';
import 'package:smoking_areas/models/japan_holidays.dart';
import 'package:smoking_areas/models/opening_hours.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';
import 'package:smoking_areas/ui/hours_text.dart';

bool open(String raw, DateTime t) =>
    OpeningHours.parse(raw)!.isOpenAt(t, isHoliday: isJapaneseHoliday);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('Japanese holidays', () {
    test('2026 incl. substitute and citizens\' holidays', () {
      String md(int v) => '${v ~/ 100}/${v % 100}';
      expect((holidaysOf(2026).toList()..sort()).map(md), [
        '1/1', '1/12', '2/11', '2/23', '3/20', '4/29', '5/3', '5/4', '5/5',
        '5/6', '7/20', '8/11', '9/21', '9/22', '9/23', '10/12', '11/3',
        '11/23', //
      ]);
      expect(isJapaneseHoliday(DateTime(2025, 11, 24)), isTrue); // substitute
      expect(isJapaneseHoliday(DateTime(2026, 11, 24)), isFalse);
    });

    test('Japan time whatever the device time zone', () {
      expect(
        japanNow(DateTime.utc(2026, 11, 19, 20, 30)),
        DateTime(2026, 11, 20, 5, 30),
      );
    });
  });

  group('open at a time', () {
    const weekdays = 'Mo-Fr 09:00-17:00; PH off';
    test('weekdays, holidays and closing time', () {
      expect(open(weekdays, DateTime(2026, 11, 17, 10)), isTrue); // Tue
      expect(open(weekdays, DateTime(2026, 11, 17, 17)), isFalse);
      expect(open(weekdays, DateTime(2026, 11, 21, 10)), isFalse); // Sat
      expect(open(weekdays, DateTime(2026, 11, 23, 10)), isFalse); // holiday
    });

    test('past midnight and New Year', () {
      const late = '5時～25時';
      expect(open(late, DateTime(2026, 11, 18, 0, 30)), isTrue);
      expect(open(late, DateTime(2026, 11, 18, 1)), isFalse);
      expect(open(late, DateTime(2026, 11, 18, 4, 59)), isFalse);
      expect(open(late, DateTime(2026, 11, 18, 5)), isTrue);
      const ny = '24/7; Dec 29-Jan 03 off';
      expect(open(ny, DateTime(2026, 12, 28, 23)), isTrue);
      expect(open(ny, DateTime(2027, 1, 1, 12)), isFalse);
      expect(open(ny, DateTime(2027, 1, 4)), isTrue);
    });

    test('next change and status text', () {
      final h = OpeningHours.parse(weekdays)!;
      expect(openStatus(h, DateTime(2026, 11, 17, 10), en, 'en'), (
        true,
        'Open now · closes 17:00',
      ));
      expect(openStatus(h, DateTime(2026, 11, 20, 18), en, 'en'), (
        false,
        'Closed now · opens Tue 9:00',
      )); // Mon 23rd is a holiday
      expect(
        openStatus(OpeningHours.parse('24/7')!, DateTime(2026), en, 'en'),
        isNull,
      );
    });

    test('unknown hours are never "closed"', () {
      const area = SmokingArea(
        id: 'x',
        position: LatLng(35.69, 139.70),
        source: 'Tokyo',
        tags: {'opening_hours': '利用時間等の制限あり'},
      );
      expect(area.openAt(DateTime(2026, 11, 17, 3)), isNull);
      expect(area.closedAt(DateTime(2026, 11, 17, 3)), isFalse);
      final closed = SmokingArea(
        id: 'y',
        position: area.position,
        source: 'Tokyo',
        tags: const {'opening_hours': '月曜日から金曜日（祝日除く）の9時から17時まで'},
      );
      expect(closed.closedAt(DateTime(2026, 11, 17, 3)), isTrue);
    });
  });

  testWidgets('details show whether the place is open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AreaDetailsSheet(
            now: DateTime(2026, 11, 17, 18),
            area: const SmokingArea(
              id: 'official:1',
              position: LatLng(35.69, 139.70),
              source: 'Tokyo',
              tags: {
                'official': 'yes',
                'amenity': 'smoking_area',
                'opening_hours': 'Mo-Fr 07:00-20:00',
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Open now · closes 20:00'), findsOneWidget);
  });
}
