import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';

void main() {
  testWidgets('details sheet shows community section and records votes',
      (tester) async {
    late CommunityService service;
    final tmp = Directory.systemTemp.createTempSync('community_ui');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth);
      await service.init();
    });

    final area = SmokingArea(
      id: 'osm:node/1',
      position: const LatLng(35.69, 139.70),
      source: 'OpenStreetMap',
      name: 'Testplatz',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AreaDetailsSheet(area: area, community: service),
      ),
    ));

    expect(find.text('Testplatz'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Noch keine Bewertung'), findsOneWidget);
    expect(find.text('Ja (0)'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Ja (0)'));
      // Let the file write of the local backend finish.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Ja (1)'), findsOneWidget);
    expect(service.myVote(area), isTrue);
  });
}
