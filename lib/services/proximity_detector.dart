import 'package:latlong2/latlong.dart';

import '../models/smoking_area.dart';

/// A smoking area the user just came close to.
class ProximityHit {
  const ProximityHit(this.area, this.distanceMeters);
  final SmokingArea area;
  final double distanceMeters;
}

/// Pure (platform independent) logic that decides when to alert the user.
///
/// * An alert fires when the user gets within [alertRadiusMeters] of an area.
/// * The area is only re-armed once the user has moved further away than
///   [rearmRadiusMeters] (hysteresis, avoids alert spam from GPS jitter) and
///   at least [cooldown] has passed since the last alert for that area.
/// * Fixes with a worse accuracy than [maxAccuracyMeters] are ignored.
class ProximityDetector {
  ProximityDetector({
    double alertRadiusMeters = 30,
    double? rearmRadiusMeters,
    this.cooldown = const Duration(minutes: 30),
    this.maxAccuracyMeters = 50,
  }) {
    setRadius(alertRadiusMeters, rearmRadiusMeters: rearmRadiusMeters);
  }

  late double _alert;
  late double _rearm;

  double get alertRadiusMeters => _alert;
  double get rearmRadiusMeters => _rearm;

  /// Default re-arm distance: twice the alert radius, but at least 30 m more,
  /// so small radii do not re-trigger on GPS jitter.
  static double defaultRearm(double alert) =>
      alert * 2 > alert + 30 ? alert * 2 : alert + 30;

  /// Changes the alert radius (user setting). Already announced areas stay
  /// quiet until the user has left them.
  void setRadius(double alertRadiusMeters, {double? rearmRadiusMeters}) {
    _alert = alertRadiusMeters;
    _rearm = rearmRadiusMeters ?? defaultRearm(alertRadiusMeters);
    assert(_rearm >= _alert);
  }

  final Duration cooldown;
  final double maxAccuracyMeters;

  static const _distance = Distance();

  final Set<String> _inside = {};
  final Map<String, DateTime> _lastAlert = {};

  /// Returns the area to alert for (the closest newly entered one), or null.
  ProximityHit? update(
    LatLng position,
    Iterable<SmokingArea> areas, {
    double? accuracyMeters,
    DateTime? now,
  }) {
    if (accuracyMeters != null && accuracyMeters > maxAccuracyMeters) {
      return null;
    }
    final t = now ?? DateTime.now();

    final latMargin = _rearm / 111000 * 1.1;
    ProximityHit? best;
    final stillNear = <String>{};
    for (final area in areas) {
      // Cheap pre-filter before the exact distance (1° lat ≈ 111 km; the
      // longitude margin is generous enough for all of Japan).
      if ((area.latitude - position.latitude).abs() > latMargin ||
          (area.longitude - position.longitude).abs() > latMargin * 1.5) {
        continue;
      }
      final d = _distance(position, area.position);
      if (d <= rearmRadiusMeters) stillNear.add(area.id);
      if (d > alertRadiusMeters) continue;
      if (_inside.contains(area.id)) continue;
      final last = _lastAlert[area.id];
      if (last != null && t.difference(last) < cooldown) continue;
      if (best == null || d < best.distanceMeters) {
        best = ProximityHit(area, d);
      }
    }

    // Areas we left far enough behind are re-armed.
    _inside.retainAll(stillNear);

    // Mark every area currently within the alert radius as "inside" so that
    // one walk past a cluster of booths only produces a single alert.
    for (final area in areas) {
      if (!stillNear.contains(area.id)) continue;
      if (_distance(position, area.position) <= alertRadiusMeters) {
        _inside.add(area.id);
      }
    }

    if (best != null) _lastAlert[best.area.id] = t;
    return best;
  }

  void reset() {
    _inside.clear();
    _lastAlert.clear();
  }
}
