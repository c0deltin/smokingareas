import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoking_areas/services/heading_math.dart';
import 'package:smoking_areas/services/heading_service.dart';
import 'package:smoking_areas/ui/user_location_marker.dart';

/// Orientation of a phone lying flat (screen up) and rotated by
/// [turnDegrees] around the vertical axis (counter-clockwise seen from above).
OrientationEvent flatEvent(double turnDegrees) {
  final h = turnDegrees * math.pi / 360;
  return OrientationEvent(
    quaternion: Quaternion(0, 0, math.sin(h), math.cos(h)),
    accuracy: -1,
    timestamp: 0,
  );
}

void main() {
  group('heading math', () {
    test('flat phone: heading of the top edge', () {
      // identity: top edge points north
      expect(headingFromRotationMatrix(1, 0, 0, 0, 1, 0, 0, 0, 1), 0);
      // top edge (device Y) pointing east: column 2 = (1, 0, 0)
      expect(headingFromRotationMatrix(0, 1, 0, -1, 0, 0, 0, 0, 1), 90);
    });

    test('upright phone (camera mode): heading of the camera', () {
      // device Y = up, device Z (screen normal) = west -> camera looks east
      expect(
        headingFromRotationMatrix(0, 0, -1, 1, 0, 0, 0, 1, 0),
        closeTo(90, 1e-9),
      );
    });

    test('tilting from flat to upright does not jump', () {
      // Phone facing north, tilted up by t (rotation about the device X axis).
      double? previous;
      for (var deg = 0; deg <= 90; deg += 5) {
        final t = deg * math.pi / 180;
        final c = math.cos(t), s = math.sin(t);
        // columns: X = (1,0,0), Y = (0,c,s), Z = (0,-s,c)
        final heading = headingFromRotationMatrix(1, 0, 0, 0, c, -s, 0, s, c)!;
        expect(angleDelta(0, heading).abs(), lessThan(1e-6), reason: '$deg°');
        previous = heading;
      }
      expect(previous, isNotNull);
    });

    test('agrees with the sensor library azimuth for a flat phone', () {
      for (final turn in [0.0, 30.0, 90.0, 135.0, 200.0, 359.0]) {
        final e = flatEvent(turn);
        final m = e.rotationMatrix;
        final mine =
            headingFromRotationMatrix(m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i)!;
        final lib = normalizeDegrees(e.eulerAngles.azimuth * 180 / math.pi);
        expect(angleDelta(lib, mine).abs(), lessThan(0.01), reason: '$turn');
      }
    });

    test('angle helpers handle the 0/360 wrap', () {
      expect(angleDelta(350, 10), closeTo(20, 1e-9));
      expect(angleDelta(10, 350), closeTo(-20, 1e-9));
      final s = AngleSmoother(factor: 0.5)..add(350);
      expect(s.add(10), closeTo(0, 1e-9), reason: 'not 180');
    });

    test('declination in Japan is applied west-positive', () {
      final tokyo = japanDeclinationWest(35.68, 139.77);
      expect(tokyo, inInclusiveRange(7, 8.5));
      expect(japanDeclinationWest(43.06, 141.35), inInclusiveRange(9, 10.5));
      expect(japanDeclinationWest(26.21, 127.68), inInclusiveRange(4, 5.5));
      expect(japanDeclinationWest(52.5, 13.4), 0, reason: 'outside Japan');
      // compass shows 0° (magnetic north) -> true heading ≈ 352°
      expect(trueHeading(0, tokyo), closeTo(360 - tokyo, 1e-9));
    });
  });

  group('HeadingService', () {
    late StreamController<OrientationEvent> events;
    late HeadingService service;
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      events = StreamController<OrientationEvent>();
      service = HeadingService(orientationStream: events.stream);
    });
    // Not awaited: close() only completes once the stream had a listener.
    tearDown(() {
      events.close();
    });

    test('compass events produce a true-north heading', () {
      service.updatePosition(35.68, 139.77);
      service.onOrientation(flatEvent(0));
      expect(service.source, HeadingSource.compass);
      expect(service.heading,
          closeTo(360 - japanDeclinationWest(35.68, 139.77), 1e-6));
    });

    test('GPS course is used while walking without compass', () {
      service.updateFromGps(course: 120, speed: 0.3);
      expect(service.heading, isNull, reason: 'standing still');
      service.updateFromGps(course: 120, speed: 1.4);
      expect(service.heading, 120);
      expect(service.source, HeadingSource.gps);
    });

    test('compass has priority over GPS course', () {
      service.updatePosition(0, 0); // no declination outside Japan
      service.onOrientation(flatEvent(0));
      service.updateFromGps(course: 120, speed: 2);
      expect(service.heading, closeTo(0, 1e-6));
    });

    test('small changes do not notify (no map repaint for sensor noise)', () {
      service.updatePosition(0, 0);
      var notified = 0;
      service.addListener(() => notified++);
      service.onOrientation(flatEvent(0));
      service.onOrientation(flatEvent(-1)); // 1° turn, smoothed
      expect(notified, 1);
    });
  });

  testWidgets('location marker paints a cone once a heading is known',
      (tester) async {
    final service = HeadingService(orientationStream: const Stream.empty());
    await tester.pumpWidget(MaterialApp(
      home: Center(child: UserLocationMarker(heading: service)),
    ));
    bool hasCone() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((p) => p.painter is HeadingConePainter);
    expect(hasCone(), isFalse);

    service.updateFromGps(course: 45, speed: 1.5);
    await tester.pump();
    expect(hasCone(), isTrue);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<HeadingConePainter>()
        .single;
    expect(painter.headingDegrees, 45);
  });
}
