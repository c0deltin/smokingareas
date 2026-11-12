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
import 'package:smoking_areas/ui/my_spots_sheet.dart';

void main() {
  late Directory tmp;
  late LocalCommunityBackend backend;
  late CommunityService service;
  var now = DateTime(2026, 11, 12, 10);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('myspots');
    SharedPreferences.setMockInitialValues({});
    backend = LocalCommunityBackend(() async => tmp);
    final auth = LocalAuthService(backend,
        prefs: await SharedPreferences.getInstance());
    await auth.init();
    now = DateTime(2026, 11, 12, 10);
    service = CommunityService(
      backend: backend,
      photos: LocalPhotoStorage(() async => tmp),
      auth: auth,
      clock: () => now,
    );
    await service.init();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('lists only own places, newest first', () async {
    await service.reportSpot(
        position: const LatLng(35.69, 139.70), name: 'Older');
    now = now.add(const Duration(hours: 1));
    await service.reportSpot(
        position: const LatLng(35.70, 139.70),
        name: 'Newer',
        category: SpotCategory.toilet);
    final me = service.currentUser!.id;
    await service.createUser('Other');
    await service.reportSpot(
        position: const LatLng(35.71, 139.70), name: 'Not mine');
    await service.switchUser(me);

    expect(service.mySpots.map((s) => s.name), ['Newer', 'Older']);
  });

  test('edit changes details but not position or category', () async {
    final spot = await service.reportSpot(
        position: const LatLng(35.69, 139.70),
        name: 'Corner',
        indoor: false,
        publicAccess: true);
    await service.updateSpot(spot.id,
        name: 'Corner behind the station',
        description: 'Ashtray',
        indoor: true,
        publicAccess: false,
        accessNote: 'Platform only');

    final edited = service.mySpots.single;
    expect(edited.name, 'Corner behind the station');
    expect(edited.description, 'Ashtray');
    expect(edited.indoor, isTrue);
    expect(edited.accessNote, 'Platform only');
    expect(edited.position, spot.position);
    expect(edited.category, 'smoking');
    // Stored, not only in memory.
    expect((await backend.spots()).single.name, 'Corner behind the station');
  });

  test('delete removes the place from the map', () async {
    final spot = await service.reportSpot(
        position: const LatLng(35.69, 139.70), name: 'Gone');
    await service.deleteSpot(spot.id);
    expect(service.mySpots, isEmpty);
    expect(service.spotsAsAreas, isEmpty);
    expect(await backend.spots(), isEmpty);
  });

  test('only the author can edit or delete', () async {
    final spot = await service.reportSpot(
        position: const LatLng(35.69, 139.70), name: 'Mine');
    await service.createUser('Other');
    expect(() => service.deleteSpot(spot.id), throwsStateError);
    expect(() => service.updateSpot(spot.id, name: 'Hijacked'),
        throwsStateError);
    expect(service.spotsAsAreas.single.name, 'Mine');
  });

  test('community data is reloaded when it is older than a minute', () async {
    // Another device adds a place directly in the backend.
    final other = CommunityService(
      backend: backend,
      photos: LocalPhotoStorage(() async => tmp),
      auth: service.auth,
      clock: () => now,
    );
    await other.init();
    await other.reportSpot(
        position: const LatLng(35.69, 139.70), name: 'From elsewhere');

    await service.refreshIfStale();
    expect(service.spotsAsAreas, isEmpty, reason: 'loaded just now');

    now = now.add(const Duration(minutes: 2));
    await service.refreshIfStale();
    expect(service.spotsAsAreas.single.name, 'From elsewhere');
  });

  testWidgets('the list shows the own places with their actions',
      (tester) async {
    await tester.runAsync(() => service.reportSpot(
        position: const LatLng(35.69, 139.70), name: 'Behind the station'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MySpotsView(community: service, onShow: (_) {})),
    ));
    expect(find.text('Behind the station'), findsOneWidget);
    expect(find.textContaining('Reported 12.11.2026'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Show on map'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('empty list explains how to report', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MySpotsView(community: service, onShow: (_) {})),
    ));
    expect(find.textContaining('not reported any places yet'), findsOneWidget);
  });
}
