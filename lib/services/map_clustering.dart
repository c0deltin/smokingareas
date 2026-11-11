import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import '../models/smoking_area.dart';

/// One map symbol: a single spot or a bubble for several spots of one
/// category.
class MapCluster {
  MapCluster(this.category, this.areas, this.center);

  final SpotCategory category;
  final List<SmokingArea> areas;
  final LatLng center;

  bool get isSingle => areas.length == 1;

  /// Stable id for map markers: the spot id, or the grid cell of the bubble.
  String id = '';

  /// Smallest box containing all spots of the cluster.
  GeoBounds get bounds {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final a in areas) {
      s = math.min(s, a.latitude);
      n = math.max(n, a.latitude);
      w = math.min(w, a.longitude);
      e = math.max(e, a.longitude);
    }
    return GeoBounds(south: s, west: w, north: n, east: e);
  }
}

/// Grid-based clustering in screen space (Web Mercator, 256 px tiles), per
/// category. Only spots inside [visible] (plus [margin] of its size on each
/// side) are considered, so the map only ever holds the markers on screen.
///
/// From [singlesFromZoom] on every spot is shown on its own.
List<MapCluster> clusterAreas(
  Iterable<SmokingArea> areas, {
  required GeoBounds visible,
  required double zoom,
  double cellPixels = 60,
  double singlesFromZoom = 17,
  double margin = 0.25,
}) {
  final dLat = (visible.north - visible.south) * margin;
  final dLon = (visible.east - visible.west) * margin;
  final area = GeoBounds(
    south: visible.south - dLat,
    north: visible.north + dLat,
    west: visible.west - dLon,
    east: visible.east + dLon,
  );
  final inView = areas.where((a) => area.contains(a.position));

  if (zoom >= singlesFromZoom) {
    return [
      for (final a in inView)
        MapCluster(a.category, [a], a.position)..id = a.id,
    ];
  }

  // Grid of the integer zoom level, so bubbles (and their ids) stay put
  // while zooming within one level.
  final worldPixels = 256 * math.pow(2, zoom.floor());
  final cells = <String, List<SmokingArea>>{};
  for (final a in inView) {
    final x = (a.longitude + 180) / 360 * worldPixels;
    final y = mercatorY(a.latitude) * worldPixels;
    final key = '${a.category.name}:${(x / cellPixels).floor()}:'
        '${(y / cellPixels).floor()}';
    (cells[key] ??= []).add(a);
  }
  return [
    for (final MapEntry(:key, value: list) in cells.entries)
      if (list.length == 1)
        MapCluster(list.first.category, list, list.first.position)
          ..id = list.first.id
      else
        MapCluster(
          list.first.category,
          list,
          LatLng(
            list.map((a) => a.latitude).reduce((a, b) => a + b) / list.length,
            list.map((a) => a.longitude).reduce((a, b) => a + b) / list.length,
          ),
        )..id = 'cluster:${zoom.floor()}:$key',
  ];
}

/// Web Mercator y in 0..1 (0 = north edge).
double mercatorY(double latitude) {
  final lat = latitude.clamp(-85.05, 85.05) * math.pi / 180;
  return (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2;
}
