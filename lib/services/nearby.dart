import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/smoking_area.dart';

/// A spot near the user: distance in metres and compass bearing (0 = north,
/// clockwise, 0–360°).
class NearbySpot {
  const NearbySpot(this.area, this.distanceMeters, this.bearing);

  final SmokingArea area;
  final double distanceMeters;
  final double bearing;
}

/// The [limit] spots of [categories] closest to [position], within
/// [radiusKm], nearest first. With [openAt] (wall-clock time in Japan),
/// temporarily closed places and places outside their opening hours are
/// left out. Pure (tested).
List<NearbySpot> nearbySpots(
  Iterable<SmokingArea> areas,
  LatLng position, {
  required Set<SpotCategory> categories,
  int limit = 20,
  double radiusKm = 2,
  DateTime? openAt,
}) {
  const distance = Distance();
  final box = GeoBounds.around(position, radiusKm);
  final out = <NearbySpot>[];
  for (final a in areas) {
    if (!categories.any(a.offers) || !box.contains(a.position)) continue;
    if (openAt != null && (a.isTemporarilyClosed || a.closedAt(openAt))) {
      continue;
    }
    final d = distance(position, a.position);
    if (d > radiusKm * 1000) continue;
    out.add(
      NearbySpot(a, d, (distance.bearing(position, a.position) + 360) % 360),
    );
  }
  out.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return out.length > limit ? out.sublist(0, limit) : out;
}
