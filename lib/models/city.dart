import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Axis aligned geographic bounding box.
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Square-ish box spanning [radiusKm] around [center].
  factory GeoBounds.around(LatLng center, double radiusKm) {
    const kmPerDegLat = 111.32;
    final dLat = radiusKm / kmPerDegLat;
    final dLon =
        radiusKm / (kmPerDegLat * math.cos(center.latitude * math.pi / 180));
    return GeoBounds(
      south: center.latitude - dLat,
      west: center.longitude - dLon,
      north: center.latitude + dLat,
      east: center.longitude + dLon,
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  /// Overpass QL bbox order: south,west,north,east.
  String toOverpass() =>
      '${south.toStringAsFixed(5)},${west.toStringAsFixed(5)},'
      '${north.toStringAsFixed(5)},${east.toStringAsFixed(5)}';
}

/// A Japanese city that the app covers.
class City {
  const City({
    required this.id,
    required this.name,
    required this.nameJa,
    required this.prefecture,
    required this.center,
    required this.radiusKm,
    this.zoom = 13,
  });

  final String id;
  final String name;
  final String nameJa;
  final String prefecture;
  final LatLng center;

  /// Radius around [center] that is downloaded for this city.
  final double radiusKm;

  /// Initial map zoom when the city is selected.
  final double zoom;

  GeoBounds get bounds => GeoBounds.around(center, radiusKm);

  bool contains(LatLng p) => bounds.contains(p);
}
