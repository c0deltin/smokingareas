import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/proximity_detector.dart';
import 'package:smoking_areas/services/proximity_monitor.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/ui/settings_sheet.dart';

const _p = LatLng(35.6909, 139.7003);
LatLng north(double m) => const Distance().offset(_p, m, 0);

final area = SmokingArea(id: 'osm:node/1', position: _p, source: 'OpenStreetMap');
final t0 = DateTime(2026, 11, 11, 12);

void main() {
  group('ProximityDetector radius', () {
    test('default stays 30 m alert / 60 m re-arm', () {
      final d = ProximityDetector();
      expect(d.alertRadiusMeters, 30);
      expect(d.rearmRadiusMeters, 60);
    });

    test('re-arm distance grows with the radius (at least +30 m)', () {
      expect(ProximityDetector.defaultRearm(10), 40);
      expect(ProximityDetector.defaultRearm(100), 200);
    });

    test('large radius alerts at 90 m (not cut off by the pre-filter)', () {
      final d = ProximityDetector()..setRadius(100);
      expect(d.update(north(90), [area], now: t0), isNotNull);
    });

    test('small radius only alerts right next to the spot', () {
      final d = ProximityDetector()..setRadius(10);
      expect(d.update(north(20), [area], now: t0), isNull);
      expect(d.update(north(8), [area], now: t0), isNotNull);
    });

    test('changing the radius applies to the next position', () {
      final d = ProximityDetector();
      expect(d.update(north(50), [area], now: t0), isNull);
      d.setRadius(60);
      expect(d.update(north(50), [area], now: t0), isNotNull);
    });
  });

  group('ProximityMonitor alert radius setting', () {
    late Directory tmp;
    late ProximityMonitor monitor;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = Directory.systemTemp.createTempSync('radius');
      monitor = ProximityMonitor(
        repository: SmokingAreaRepository(
            sources: const [], cacheDirectory: () async => tmp),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('is saved, clamped and passed to the detector', () async {
      expect(monitor.alertRadius, ProximityMonitor.defaultAlertRadius);
      await monitor.setAlertRadius(75);
      expect(monitor.alertRadius, 75);
      expect(monitor.detector.alertRadiusMeters, 75);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('alert_radius_m'), 75);

      await monitor.setAlertRadius(5000);
      expect(monitor.alertRadius, ProximityMonitor.maxAlertRadius);
      await monitor.setAlertRadius(1);
      expect(monitor.alertRadius, ProximityMonitor.minAlertRadius);
    });

    testWidgets('settings sheet shows and resets the radius', (tester) async {
      await tester.runAsync(() => monitor.setAlertRadius(80));
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: SettingsView(monitor: monitor))));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('80 m'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Reset to 30 m'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('30 m'), findsOneWidget);
      expect(monitor.alertRadius, 30);
    });
  });
}
