import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/legend_sheet.dart';
import 'package:smoking_areas/ui/spot_style.dart';

SmokingArea spot(Map<String, String> tags) => SmokingArea(
      id: 'x:${tags.hashCode}',
      position: const LatLng(35.69, 139.70),
      source: 'test',
      tags: tags,
    );

void main() {
  group('SpotMarker.fromArea – same mapping as on the map', () {
    test('ring shows the origin', () {
      expect(SpotMarker.fromArea(spot(const {})).origin, SpotOrigin.osm);
      expect(SpotMarker.fromArea(spot(const {'official': 'yes'})).origin,
          SpotOrigin.official);
      expect(SpotMarker.fromArea(spot(const {'community': 'yes'})).origin,
          SpotOrigin.community);
    });

    test('fill shows category, indoor and closure', () {
      final toilet = SpotMarker.fromArea(spot(const {'amenity': 'toilets'}));
      expect(toilet.category, SpotCategory.toilet);
      expect(SpotMarker.fromArea(spot(const {'indoor': 'yes'})).indoor, isTrue);
      expect(
          SpotMarker.fromArea(spot(const {'temporarily_closed': 'yes'})).closed,
          isTrue);
    });

    test('ring colours are distinct', () {
      final colours = SpotOrigin.values.map(originRingColor).toSet();
      expect(colours, hasLength(SpotOrigin.values.length));
    });
  });

  testWidgets('legend lists every symbol with a one-sentence explanation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LegendView())));

    for (final text in [
      'Outdoor smoking area.',
      'Indoor smoking room.',
      'Public toilet.',
      'White: entry from OpenStreetMap.',
      'Gold: from an official list of the city or ward.',
      'Pink: reported by a user.',
      'Grey with pause badge: temporarily closed.',
      'Several smoking areas – tap to zoom in.',
      'Several toilets – tap to zoom in.',
      'Your location – the cone shows the direction you are facing.',
      'Alert radius for nearby smoking areas.',
    ]) {
      await tester.scrollUntilVisible(find.text(text), 100);
      expect(find.text(text), findsOneWidget, reason: text);
    }

    // Every explanation is a single sentence.
    for (final (_, entries) in legendSections()) {
      for (final e in entries) {
        expect('.'.allMatches(e.text).length,
            lessThanOrEqualTo(1),
            reason: e.text);
      }
    }
  });

  testWidgets('legend symbols are the real map markers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LegendView())));
    final markers =
        tester.widgetList<SpotMarker>(find.byType(SpotMarker, skipOffstage: false));
    expect(markers.map((m) => m.origin).toSet(), SpotOrigin.values.toSet());
    expect(markers.any((m) => m.closed), isTrue);
    expect(markers.any((m) => m.category == SpotCategory.toilet), isTrue);
  });
}
