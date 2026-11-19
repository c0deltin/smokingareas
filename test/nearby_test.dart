import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/i18n.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/nearby.dart';
import 'package:smoking_areas/ui/nearby_sheet.dart';

const _me = LatLng(35.6900, 139.7000);

SmokingArea _spot(
  String id,
  double dLat,
  double dLon, {
  String amenity = 'smoking_area',
  Map<String, String> tags = const {},
}) => SmokingArea(
  id: id,
  position: LatLng(_me.latitude + dLat, _me.longitude + dLon),
  source: 'OpenStreetMap',
  name: id,
  tags: {'amenity': amenity, ...tags},
);

final _areas = [
  _spot('far-north', 0.004, 0), // ~445 m north
  _spot('near-east', 0, 0.002), // ~180 m east
  _spot('toilet', 0.001, 0, amenity: 'toilets'),
  _spot('night', -0.0012, 0, tags: {'opening_hours': 'Mo-Su 18:00-23:00'}),
  _spot('outside', 0.05, 0), // ~5.5 km
];

void main() {
  test('nearest first, by category, within the radius', () {
    final out = nearbySpots(_areas, _me, categories: {SpotCategory.smoking});
    expect(out.map((s) => s.area.id), ['night', 'near-east', 'far-north']);
    expect(out[1].distanceMeters, closeTo(180, 5));
    expect(out[1].bearing, closeTo(90, 1));
    expect(out[2].bearing, closeTo(0, 1));
    expect(
      nearbySpots(
        _areas,
        _me,
        categories: SpotCategory.values.toSet(),
        limit: 2,
      ).map((s) => s.area.id),
      ['toilet', 'night'],
    );
  });

  test('"open now" leaves out places outside their hours', () {
    final out = nearbySpots(
      _areas,
      _me,
      categories: {SpotCategory.smoking},
      openAt: DateTime(2026, 11, 17, 10),
    );
    expect(out.map((s) => s.area.id), ['near-east', 'far-north']);
  });

  testWidgets('list shows distance and status; tap opens the spot', (
    tester,
  ) async {
    SmokingArea? shown;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NearbyView(
            areas: () => _areas,
            position: () => _me,
            categories: const {SpotCategory.smoking},
            openOnly: false,
            now: DateTime(2026, 11, 17, 10),
            onShow: (a) => shown = a,
          ),
        ),
      ),
    );
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Closed now · opens 18:00'), findsOneWidget);
    expect(find.text('181 m'), findsOneWidget);
    await tester.tap(find.text('near-east'));
    expect(shown?.id, 'near-east');

    await tester.tap(find.text('Open now'));
    await tester.pump();
    expect(find.text('night'), findsNothing);
  });

  testWidgets('without a position the list explains why it is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NearbyView(
            areas: () => _areas,
            position: () => null,
            categories: const {SpotCategory.smoking},
            openOnly: false,
            onShow: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Your location is not known yet.'), findsOneWidget);
  });
}
