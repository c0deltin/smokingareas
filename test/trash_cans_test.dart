import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/community/server_rows.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';
import 'package:smoking_areas/ui/report_spot_sheet.dart';

const _p = LatLng(35.6909, 139.7003);

void main() {
  group('category and waste types', () {
    test('trash cans are derived from amenity=waste_basket', () {
      const bin = SmokingArea(
        id: 'community:1',
        position: _p,
        source: 'Community',
        tags: {'amenity': 'waste_basket', 'waste': 'plastic_bottles;cans'},
      );
      expect(bin.category, SpotCategory.bin);
      expect(bin.title, 'Trash can');
      expect(bin.waste, {WasteType.cans, WasteType.bottles});
      expect(SpotCategory.tryParse('bin'), SpotCategory.bin);
      expect(SpotCategory.tryParse('vending_machine'), isNull);
    });

    test('waste values follow the OSM schema in a stable order', () {
      expect(WasteType.format({WasteType.bottles, WasteType.trash}),
          'trash;plastic_bottles');
      expect(WasteType.format(const {}), isNull);
      expect(WasteType.parse('trash; batteries'), {WasteType.trash});
      expect(WasteType.parse(null), isEmpty);
    });

    test('trash cans are never merged with other categories', () {
      final out = SmokingAreaRepository.merge([
        const SmokingArea(
            id: 'osm:node/1',
            position: _p,
            source: 'OpenStreetMap',
            tags: {'amenity': 'smoking_area'}),
        const SmokingArea(
            id: 'community:1',
            position: _p,
            source: 'Community',
            tags: {'community': 'yes', 'amenity': 'waste_basket'}),
      ]);
      expect(out.map((a) => a.category).toSet(),
          {SpotCategory.smoking, SpotCategory.bin});
    });

    test('server rows carry the waste column only when needed', () {
      final spot = CommunitySpot(
        id: 'community:1',
        position: _p,
        name: 'Bins',
        category: 'bin',
        waste: 'cans',
        createdBy: 'u',
        createdAt: DateTime(2026),
      );
      expect(ServerRows.spotInsert(spot)['waste'], 'cans');
      expect(ServerRows.spot({
        ...ServerRows.spotInsert(spot),
        'created_by': 'u',
        'created_at': '2026-01-01T00:00:00Z',
      }).waste, 'cans');
      final smoking = CommunitySpot(
        id: 'community:2',
        position: _p,
        name: 'Corner',
        createdBy: 'u',
        createdAt: DateTime(2026),
      );
      expect(ServerRows.spotInsert(smoking).containsKey('waste'), isFalse);
      expect(ServerRows.spotUpdate(smoking).containsKey('waste'), isFalse);
    });
  });

  group('community', () {
    late Directory tmp;
    late LocalCommunityBackend backend;
    late CommunityService service;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('trashcans');
      SharedPreferences.setMockInitialValues({});
      backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      service = CommunityService(
        backend: backend,
        photos: LocalPhotoStorage(() async => tmp),
        auth: auth,
      );
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('reported trash cans appear on the map with what they take',
        () async {
      final spot = await service.reportSpot(
        position: _p,
        name: '',
        category: SpotCategory.bin,
        indoor: true,
        wheelchair: true,
        waste: {WasteType.cans, WasteType.bottles},
      );
      expect(spot.name, 'Trash can');
      // Attributes of other categories are dropped.
      expect(spot.indoor, isNull);
      expect(spot.wheelchair, isNull);

      final area = service.spotsAsAreas.single;
      expect(area.category, SpotCategory.bin);
      expect(area.tags['amenity'], 'waste_basket');
      expect(area.waste, {WasteType.cans, WasteType.bottles});

      await service.updateSpot(spot.id,
          name: 'Bins', waste: {WasteType.trash});
      expect(service.spotsAsAreas.single.waste, {WasteType.trash});
    });

    test('spots of unknown categories are skipped', () async {
      await backend.addSpot(CommunitySpot(
        id: 'community:future',
        position: _p,
        name: 'From a newer app',
        category: 'vending_machine',
        createdBy: 'someone',
        createdAt: DateTime(2026),
      ));
      await service.init();
      expect(service.spotsAsAreas, isEmpty);
    });
  });

  testWidgets('details show what a trash can accepts', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AreaDetailsSheet(
          area: SmokingArea(
            id: 'community:1',
            position: _p,
            source: 'Community',
            name: 'Bins',
            tags: {
              'community': 'yes',
              'amenity': 'waste_basket',
              'waste': 'cans;plastic_bottles',
            },
          ),
        ),
      ),
    ));
    expect(find.text('Cans, PET bottles'), findsOneWidget);
    expect(find.text('Fee'), findsNothing);
    expect(find.text('Covered'), findsNothing);
  });

  testWidgets('report form asks what a trash can accepts', (tester) async {
    SpotReportInput? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showReportSpotSheet(context, SpotCategory.bin),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Report trash can'), findsOneWidget);
    expect(find.text('Smoking room'), findsNothing);
    await tester.tap(find.text('Cans'));
    await tester.pump();
    await tester.ensureVisible(find.text('Report'));
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(result?.category, SpotCategory.bin);
    expect(result?.waste, {WasteType.cans});
  });
}
