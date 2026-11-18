/// How precisely the position is tracked. Pure logic (no plugins), so the
/// battery strategy is testable.
enum TrackingMode {
  /// App visible, or a smoking area is close: precise and frequent updates.
  precise,

  /// In the background with the nearest smoking area far away: coarse
  /// (cell/Wi-Fi) positions every ~100 m – a fraction of the battery.
  coarse,

  /// In the background with alerts off: no tracking at all.
  off,
}

/// The location request for a [TrackingMode].
class TrackingProfile {
  const TrackingProfile({
    required this.precise,
    required this.distanceFilterMeters,
    required this.interval,
  });

  /// GPS accuracy (true) or network/balanced accuracy (false).
  final bool precise;

  /// Minimum movement between two updates.
  final int distanceFilterMeters;

  /// Android: target interval between updates.
  final Duration interval;
}

/// Battery strategy of the proximity alerts: GPS only where an alert can
/// actually be due.
///
/// * In the foreground the map needs a precise blue dot.
/// * In the background, precise tracking only within [nearMeters] of a
///   smoking area; further away coarse updates suffice. [farMeters] adds
///   hysteresis so the mode does not flip on GPS jitter.
/// * Background without alerts: tracking stops.
class TrackingPolicy {
  const TrackingPolicy({this.nearMeters = 400, this.farMeters = 600})
      : assert(farMeters > nearMeters);

  final double nearMeters;
  final double farMeters;

  TrackingMode mode({
    required bool foreground,
    required bool alertsEnabled,
    required TrackingMode current,
    double? nearestSmokingMeters,
  }) {
    if (foreground) return TrackingMode.precise;
    if (!alertsEnabled) return TrackingMode.off;
    final d = nearestSmokingMeters;
    // Unknown (no data loaded yet): stay precise rather than miss an alert.
    if (d == null) {
      return current == TrackingMode.coarse
          ? TrackingMode.coarse
          : TrackingMode.precise;
    }
    if (current == TrackingMode.coarse) {
      return d < nearMeters ? TrackingMode.precise : TrackingMode.coarse;
    }
    return d > farMeters ? TrackingMode.coarse : TrackingMode.precise;
  }

  /// Location request for [mode]; in precise mode the distance filter
  /// follows the alert radius (half of it, 5–15 m) so a small circle is
  /// not stepped over.
  static TrackingProfile profile(TrackingMode mode, double alertRadius) =>
      switch (mode) {
        TrackingMode.coarse => const TrackingProfile(
            precise: false,
            distanceFilterMeters: 100,
            interval: Duration(seconds: 30),
          ),
        _ => TrackingProfile(
            precise: true,
            distanceFilterMeters: (alertRadius / 2).clamp(5, 15).round(),
            interval: const Duration(seconds: 5),
          ),
      };
}
