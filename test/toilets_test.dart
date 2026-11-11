import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/city.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/sources/official_opendata_source.dart';
import 'package:smoking_areas/sources/overpass_source.dart';
import 'package:smoking_areas/sources/smoking_area_source.dart';
import 'package:smoking_areas/ui/area_details_sheet.dart';

const _d = Distance();
const _p = LatLng(35.6909, 139.7003);

SmokingArea osm(String id, LatLng p, {bool toilet = false}) => SmokingArea(
      id: 'osm:node/$id',
      position: p,
      source: 'OpenStreetMap',
      tags: {'amenity': toilet ? 'toilets' : 'smoking_area'},
    );

SmokingArea official(String id, LatLng p, {bool toilet = false}) =>
    SmokingArea(
      id: 'x:$id',
      position: p,
      source: 'Bezirk',
      tags: {'official': 'yes', if (toilet) 'amenity': 'toilets'},
    );

class _Live extends SmokingAreaSource {
  _Live(this.result);
  final List<SmokingArea> result;
  int calls = 0;
  @override
  String get id => 'osm';
  @override
  String get displayName => 'osm';
  @override
  String get attribution => 'osm';
  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    calls++;
    return result;
  }
}

void main() {
  group('category', () {
    test('derived from amenity=toilets, with toilet attributes', () {
      final t = SmokingArea(
        id: 'osm:node/1',
        position: _p,
        source: 'OpenStreetMap',
        tags: const {
          'amenity': 'toilets',
          'wheelchair': 'yes',
          'changing_table': 'no',
        },
      );
      expect(t.category, SpotCategory.toilet);
      expect(t.title, 'Public toilet');
      expect(t.wheelchair, isTrue);
      expect(t.changingTable, isFalse);
      expect(osm('2', _p).category, SpotCategory.smoking);
    });

    test('Overpass query and parser include public toilets', () {
      final q = OverpassSource.buildQuery(
          const GeoBounds(south: 1, west: 2, north: 3, east: 4));
      expect(q, contains('"amenity"="toilets"'));
      expect(q, contains('private|no|customers|permit'));
      final areas = OverpassSource.parse('''
{"elements":[{"type":"node","id":5,"lat":35.68,"lon":139.76,
 "tags":{"amenity":"toilets","wheelchair":"yes"}}]}''');
      expect(areas.single.isToilet, isTrue);
    });
  });

  group('merge keeps categories apart', () {
    test('official toilet never absorbs a nearby smoking area', () {
      final out = SmokingAreaRepository.merge([
        official('t', _p, toilet: true),
        osm('s', _d.offset(_p, 5, 90)),
      ]);
      expect(out, hasLength(2));
    });

    test('official toilet merges with the OSM toilet at the same place', () {
      final out = SmokingAreaRepository.merge([
        official('t', _p, toilet: true),
        osm('t', _d.offset(_p, 10, 90), toilet: true),
        osm('s', _d.offset(_p, 3, 0)),
      ]);
      expect(out, hasLength(2));
      final t = out.firstWhere((a) => a.isToilet);
      expect(t.osmElement, 'node/t');
    });

    test('generic de-duplication ignores other categories', () {
      final out = SmokingAreaRepository.merge([
        osm('a', _p),
        SmokingArea(
          id: 'community:1',
          position: _d.offset(_p, 2, 0),
          source: 'Community',
          tags: const {'amenity': 'toilets'},
        ),
      ]);
      expect(out, hasLength(2));
    });
  });

  group('official snapshot', () {
    final source = OfficialOpenDataSource(
        loader: () =>
            File('assets/opendata/official_smoking_areas.json').readAsString());

    test('toilets exist wherever official smoking data exists', () async {
      final tokyo = await source.fetch(cityById('tokyo')!.bounds);
      final toiletDatasets = tokyo
          .where((a) => a.isToilet)
          .map((a) => a.tags['official:dataset'])
          .toSet();
      expect(
        toiletDatasets,
        containsAll([
          'tokyo_chiyoda_toilets',
          'tokyo_shinjuku_toilets',
          'tokyo_taito_toilets',
          'tokyo_toshima_toilets',
          'tokyo_koto_toilets',
        ]),
      );
      final okayama = await source.fetch(cityById('okayama')!.bounds);
      expect(okayama.where((a) => a.isToilet).length, greaterThan(50),
          reason: 'manually downloaded Okayama dataset');
      // Okayama station west exit: wheelchair + baby changing table.
      final station = okayama.firstWhere((a) => a.title.contains('岡山駅西口'));
      expect(station.wheelchair, isTrue);
      expect(station.changingTable, isTrue);
      final closed = okayama.where((a) => a.isTemporarilyClosed).toList();
      expect(closed, hasLength(2),
          reason: '「工事中のため、休止中」 is shown as temporarily closed');
      expect(closed.first.closedNote, contains('工事中'));
      final kyoto = await source.fetch(cityById('kyoto')!.bounds);
      expect(kyoto.where((a) => a.isToilet).length, greaterThan(100));
      expect(kyoto.where((a) => !a.isToilet), isNotEmpty);
    });

    test('toilet datasets get readable labels', () async {
      final ds = await source.datasets();
      final sumida = ds.firstWhere((d) => d.id == 'tokyo_sumida_toilets');
      expect(sumida.label, 'Tokyo, Sumida ward (open data)');
    });
  });

  test('cache without toilets (schema 1) is refreshed', () async {
    final tmp = Directory.systemTemp.createTempSync('toilet_cache');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dir = Directory('${tmp.path}/smoking_areas')..createSync();
    File('${dir.path}/tokyo.json').writeAsStringSync(jsonEncode({
      'fetchedAt': DateTime.now().toIso8601String(),
      'raw': {
        'osm': [osm('1', _p).toJson()],
      },
    }));
    final live = _Live([osm('1', _p), osm('2', _p, toilet: true)]);
    final repo = SmokingAreaRepository(
        sources: [live], cacheDirectory: () async => tmp);
    await repo.warmUp();
    expect(repo.allVisible, hasLength(1), reason: 'old cache shown at once');
    await repo.load(cityById('tokyo')!);
    expect(live.calls, 1, reason: 'schema-1 cache must be refreshed');
    expect(repo.allVisible.where((a) => a.isToilet), hasLength(1));
  });

  group('community toilets', () {
    late Directory tmp;
    late CommunityService service;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('toilet_community');
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
    tearDown(() => tmp.deleteSync(recursive: true));

    test('reported toilet is a toilet on the map and persists', () async {
      await service.reportSpot(
        position: _p,
        name: '',
        category: SpotCategory.toilet,
        wheelchair: true,
        changingTable: false,
        indoor: true, // ignored for toilets
      );
      final a = service.spotsAsAreas.single;
      expect(a.isToilet, isTrue);
      expect(a.title, 'Public toilet');
      expect(a.wheelchair, isTrue);
      expect(a.changingTable, isFalse);
      expect(a.isIndoor, isNull);

      final stored = (await LocalCommunityBackend(() async => tmp).spots()).single;
      expect(stored.category, 'toilet');
      expect(stored.wheelchair, isTrue);
    });
  });

  testWidgets('details sheet shows toilet attributes', (tester) async {
    final toilet = SmokingArea(
      id: 'osm:node/9',
      position: _p,
      source: 'OpenStreetMap',
      tags: const {'amenity': 'toilets', 'wheelchair': 'yes'},
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AreaDetailsSheet(area: toilet)),
    ));
    expect(find.text('Public toilet'), findsOneWidget);
    expect(find.text('Wheelchair accessible'), findsOneWidget);
    expect(find.text('Baby changing'), findsOneWidget);
    expect(find.text('Covered'), findsNothing);
    expect(find.byIcon(Icons.wc), findsOneWidget);
  });
}
