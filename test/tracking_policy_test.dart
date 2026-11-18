import 'package:flutter_test/flutter_test.dart';
import 'package:smoking_areas/services/tracking_policy.dart';

void main() {
  const policy = TrackingPolicy();

  TrackingMode mode(TrackingMode current, double? nearest,
          {bool foreground = false, bool alerts = true}) =>
      policy.mode(
        foreground: foreground,
        alertsEnabled: alerts,
        current: current,
        nearestSmokingMeters: nearest,
      );

  test('the visible map always gets precise positions', () {
    expect(mode(TrackingMode.coarse, 5000, foreground: true),
        TrackingMode.precise);
    expect(mode(TrackingMode.off, null, foreground: true, alerts: false),
        TrackingMode.precise);
  });

  test('no tracking in the background without alerts', () {
    expect(mode(TrackingMode.precise, 10, alerts: false), TrackingMode.off);
  });

  test('coarse far from smoking areas, precise when one gets close', () {
    expect(mode(TrackingMode.precise, 2000), TrackingMode.coarse);
    expect(mode(TrackingMode.coarse, 2000), TrackingMode.coarse);
    expect(mode(TrackingMode.coarse, 350), TrackingMode.precise);
    expect(mode(TrackingMode.precise, double.infinity), TrackingMode.coarse);
  });

  test('hysteresis: no flipping between 400 and 600 m', () {
    expect(mode(TrackingMode.precise, 500), TrackingMode.precise);
    expect(mode(TrackingMode.coarse, 500), TrackingMode.coarse);
  });

  test('unknown surroundings keep the current precision', () {
    expect(mode(TrackingMode.precise, null), TrackingMode.precise);
    expect(mode(TrackingMode.coarse, null), TrackingMode.coarse);
    expect(mode(TrackingMode.off, null), TrackingMode.precise);
  });

  test('profiles: coarse saves battery, precise follows the alert radius', () {
    final coarse = TrackingPolicy.profile(TrackingMode.coarse, 30);
    expect(coarse.precise, isFalse);
    expect(coarse.distanceFilterMeters, 100);
    expect(coarse.interval, const Duration(seconds: 30));

    expect(TrackingPolicy.profile(TrackingMode.precise, 10).distanceFilterMeters, 5);
    expect(TrackingPolicy.profile(TrackingMode.precise, 30).distanceFilterMeters, 15);
    expect(TrackingPolicy.profile(TrackingMode.precise, 150).distanceFilterMeters, 15);
    expect(TrackingPolicy.profile(TrackingMode.precise, 30).precise, isTrue);
  });
}
