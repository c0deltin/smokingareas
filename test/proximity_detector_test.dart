import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/proximity_detector.dart';

/// Moves [p] north by [meters].
LatLng north(LatLng p, double meters) =>
    const Distance().offset(p, meters, 0);

void main() {
  final shibuya = LatLng(35.6590, 139.7005);
  final area = SmokingArea(
    id: 'osm:node/1',
    position: shibuya,
    source: 'OpenStreetMap',
    name: 'Hachiko smoking area',
  );
  final t0 = DateTime(2026, 1, 1, 12);

  test('alerts within 30 m, not at 40 m', () {
    final d = ProximityDetector();
    expect(d.update(north(shibuya, 40), [area], now: t0), isNull);
    final hit = d.update(north(shibuya, 25), [area], now: t0);
    expect(hit, isNotNull);
    expect(hit!.area, area);
    expect(hit.distanceMeters, closeTo(25, 1));
  });

  test('does not alert twice while staying nearby (hysteresis)', () {
    final d = ProximityDetector(cooldown: Duration.zero);
    expect(d.update(north(shibuya, 10), [area], now: t0), isNotNull);
    expect(d.update(north(shibuya, 20), [area], now: t0), isNull);
    // GPS jitter outside 30 m but inside the 60 m re-arm radius.
    expect(d.update(north(shibuya, 45), [area], now: t0), isNull);
    expect(d.update(north(shibuya, 15), [area], now: t0), isNull);
    // Leaving properly re-arms the area.
    expect(d.update(north(shibuya, 100), [area], now: t0), isNull);
    expect(d.update(north(shibuya, 15), [area], now: t0), isNotNull);
  });

  test('respects cooldown after re-entering', () {
    final d = ProximityDetector(cooldown: const Duration(minutes: 30));
    expect(d.update(north(shibuya, 10), [area], now: t0), isNotNull);
    d.update(north(shibuya, 200), [area], now: t0);
    expect(
      d.update(north(shibuya, 10), [area],
          now: t0.add(const Duration(minutes: 10))),
      isNull,
    );
    d.update(north(shibuya, 200), [area], now: t0);
    expect(
      d.update(north(shibuya, 10), [area],
          now: t0.add(const Duration(minutes: 31))),
      isNotNull,
    );
  });

  test('ignores inaccurate fixes', () {
    final d = ProximityDetector();
    expect(
      d.update(north(shibuya, 5), [area], accuracyMeters: 120, now: t0),
      isNull,
    );
    expect(
      d.update(north(shibuya, 5), [area], accuracyMeters: 10, now: t0),
      isNotNull,
    );
  });

  test('alerts only once for a cluster and picks the closest', () {
    final far = SmokingArea(
      id: 'osm:node/2',
      position: north(shibuya, 20),
      source: 'OpenStreetMap',
    );
    final d = ProximityDetector();
    final hit = d.update(north(shibuya, 5), [area, far], now: t0);
    expect(hit!.area.id, 'osm:node/1');
    expect(d.update(north(shibuya, 6), [area, far], now: t0), isNull);
  });
}
