import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/models/city.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/map_clustering.dart';
import 'package:smoking_areas/ui/marker_icons.dart';
import 'package:smoking_areas/ui/spot_style.dart';

SmokingArea spot(String id, double lat, double lon, {bool toilet = false}) =>
    SmokingArea(
      id: id,
      position: LatLng(lat, lon),
      source: 'test',
      name: id,
      tags: toilet ? const {'amenity': 'toilets'} : const {},
    );

const shinjuku = GeoBounds(
    south: 35.680, west: 139.690, north: 35.700, east: 139.710);

void main() {
  test('nearby spots of one category share a bubble at low zoom', () {
    final areas = [
      spot('a', 35.6900, 139.7000),
      spot('b', 35.6901, 139.7001),
      spot('c', 35.6902, 139.7002),
    ];
    final clusters = clusterAreas(areas, visible: shinjuku, zoom: 12);
    expect(clusters, hasLength(1));
    expect(clusters.single.areas, hasLength(3));
    expect(clusters.single.isSingle, isFalse);
    expect(clusters.single.center.latitude, closeTo(35.6901, 1e-6));
  });

  test('categories are never mixed in a bubble', () {
    final areas = [
      spot('a', 35.6900, 139.7000),
      spot('b', 35.6901, 139.7001),
      spot('t', 35.6901, 139.7001, toilet: true),
    ];
    final clusters = clusterAreas(areas, visible: shinjuku, zoom: 12);
    expect(clusters, hasLength(2));
    for (final c in clusters) {
      expect(c.areas.map((a) => a.category).toSet(), {c.category});
    }
  });

  test('from zoom 17 every spot is shown on its own, with its id', () {
    final areas = [spot('a', 35.6900, 139.7000), spot('b', 35.6900, 139.7000)];
    final clusters = clusterAreas(areas, visible: shinjuku, zoom: 17);
    expect(clusters.map((c) => c.id), ['a', 'b']);
    expect(clusters.every((c) => c.isSingle), isTrue);
  });

  test('spots far outside the visible region are left out', () {
    final areas = [
      spot('in', 35.6900, 139.7000),
      spot('osaka', 34.70, 135.50),
    ];
    final clusters = clusterAreas(areas, visible: shinjuku, zoom: 15);
    expect(clusters.expand((c) => c.areas).map((a) => a.id), ['in']);
  });

  test('cluster ids are stable for the same cell and zoom', () {
    final areas = [spot('a', 35.6900, 139.7000), spot('b', 35.6901, 139.7001)];
    final first = clusterAreas(areas, visible: shinjuku, zoom: 12);
    final second = clusterAreas(areas.reversed, visible: shinjuku, zoom: 12.4);
    expect(first.single.id, second.single.id);
  });

  test('bubble labels are rounded for large counts', () {
    expect(ClusterBubble.label(7), '7');
    expect(ClusterBubble.label(99), '99');
    expect(ClusterBubble.label(256), '200+');
    expect(ClusterBubble.label(4321), '4k+');
  });

  test('mercator y: equator in the middle, north above', () {
    expect(mercatorY(0), closeTo(0.5, 1e-9));
    expect(mercatorY(35.7), lessThan(0.5));
  });

  testWidgets('marker bitmaps are rendered once per look', (tester) async {
    await tester.runAsync(() async {
      final icons = MarkerIcons(2);
      await icons.prepareBase();
      const m = SpotMarker(
          category: SpotCategory.toilet,
          origin: SpotOrigin.official,
          closed: true);
      expect(icons.spot(m), isNotNull);
      expect(icons.dot, isNotNull);
      expect(icons.cluster(SpotCategory.smoking, '12'), isNull);
      final a = await icons.ensureCluster(SpotCategory.smoking, '12');
      final b = await icons.ensureCluster(SpotCategory.smoking, '12');
      expect(identical(a, b), isTrue);
      await icons.ensureCone(31);
      expect(icons.cone(29), isNotNull); // same 5° step
    });
  });

  testWidgets('legend markers paint without overflow errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: SpotMarker(category: SpotCategory.smoking, closed: true),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
