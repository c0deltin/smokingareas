import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/services/notification_service.dart';

void main() {
  test('notifications use the monochrome Ippuku icon, kept in release', () {
    const name = NotificationService.androidIcon;
    final drawable = File('android/app/src/main/res/drawable/$name.xml');
    expect(drawable.existsSync(), isTrue);
    // Status bar icons must be white on transparent.
    expect(drawable.readAsStringSync(), contains('#FFFFFFFF'));
    expect(File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
        contains('@drawable/$name'));
  });

  test('alert title is plain text without the old emoji', () {
    expect(NotificationService.nearbyTitle, 'Smoking area nearby');
  });

  test('alert payload carries id and position, old payloads still work', () {
    const target = NotificationTarget('osm:node/1', LatLng(34.59, 133.77));
    final back = NotificationTarget.parse(target.encode())!;
    expect(back.id, 'osm:node/1');
    expect(back.position, const LatLng(34.59, 133.77));

    final old = NotificationTarget.parse('osm:node/2')!;
    expect(old.id, 'osm:node/2');
    expect(old.position, isNull);
    expect(NotificationTarget.parse(null), isNull);
  });
}
