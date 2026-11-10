import 'dart:math' as math;

/// Pure helpers for the "which way am I facing" indicator. No Flutter or
/// plugin dependencies, so they are unit-testable.

double _deg(double rad) => rad * 180 / math.pi;

/// Normalises an angle to `[0, 360)`.
double normalizeDegrees(double deg) {
  final d = deg % 360;
  return d < 0 ? d + 360 : d;
}

/// Signed smallest difference `to - from` in degrees, in `(-180, 180]`.
double angleDelta(double from, double to) {
  var d = normalizeDegrees(to) - normalizeDegrees(from);
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// Heading (degrees clockwise from north) of a device whose orientation is
/// given as row-major rotation matrix `[a b c; d e f; g h i]` mapping device
/// coordinates to world coordinates (x = east, y = north, z = up).
///
/// The direction is the sum of the horizontal projections of the device's top
/// edge (device Y axis) and of the back camera direction (device −Z axis):
/// lying flat the top edge dominates, held upright like a camera the camera
/// direction dominates, and in between both point the same way – so there is
/// no jump when the phone is tilted. Returns null if the direction cannot be
/// determined.
double? headingFromRotationMatrix(
  double a, double b, double c,
  double d, double e, double f,
  double g, double h, double i,
) {
  final east = b - c;
  final north = e - f;
  if (east.abs() < 1e-6 && north.abs() < 1e-6) return null;
  return normalizeDegrees(_deg(math.atan2(east, north)));
}

/// Approximate magnetic declination in Japan (degrees, **west positive**).
///
/// Linear fit to the GSI magnetic charts (about 5° W in Okinawa, 7–8° W
/// around Tokyo/Osaka, 9–10° W in Hokkaidō); accurate to roughly ±1.5°, which
/// is plenty for a direction cone. Outside Japan it returns 0.
double japanDeclinationWest(double latitude, double longitude) {
  if (latitude < 20 || latitude > 46 || longitude < 122 || longitude > 154) {
    return 0;
  }
  return 7.6 + 0.28 * (latitude - 35) + 0.05 * (longitude - 137);
}

/// Converts a magnetic heading to a true (geographic) heading.
double trueHeading(double magneticHeading, double declinationWest) =>
    normalizeDegrees(magneticHeading - declinationWest);

/// Exponential smoothing of angles that handles the 359° → 0° wrap.
class AngleSmoother {
  AngleSmoother({this.factor = 0.25});

  /// Weight of a new sample (0..1); smaller = smoother but slower.
  final double factor;
  double? _value;

  double? get value => _value;

  double add(double sample) {
    final current = _value;
    _value = current == null
        ? normalizeDegrees(sample)
        : normalizeDegrees(current + angleDelta(current, sample) * factor);
    return _value!;
  }

  void reset() => _value = null;
}
