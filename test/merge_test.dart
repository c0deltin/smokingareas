import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/city.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/sources/official_opendata_source.dart';
import 'package:smoking_areas/sources/smoking_area_source.dart';

const _d = Distance();
final _shinjuku = const LatLng(35.6930, 139.7001);

SmokingArea osm(String id, LatLng p, {Map<String, String> tags = const {}}) =>
    SmokingArea(
      id: 'osm:node/$id',
      position: p,
      source: 'OpenStreetMap',
      tags: {'amenity': 'smoking_area', ...tags},
    );

SmokingArea official(String id, LatLng p, {bool geocoded = false}) =>
    SmokingArea(
      id: 'tokyo_shinjuku:$id',
      position: p,
      source: 'Bezirk Shinjuku',
      name: '新宿駅東口公衆喫煙所',
      tags: {
        'official': 'yes',
        'opening_hours': '終日',
        if (geocoded) 'geocoded': 'yes',
      },
    );

class _FakeSource extends SmokingAreaSource {
  _FakeSource(this.id, this.result);
  @override
  final String id;
  List<SmokingArea> result;
  bool fail = false;
  int calls = 0;
  @override
  String get displayName => id;
  @override
  String get attribution => id;
  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    calls++;
    if (fail) throw SourceException('offline');
    return result;
  }
}

void main() {
  group('merge', () {
    test('official + nearby OSM point become one marker', () {
      final o = official('1', _shinjuku);
      final x = osm('9', _d.offset(_shinjuku, 15, 90), tags: {'covered': 'yes'});
      final out = SmokingAreaRepository.merge([x, o]);
      expect(out, hasLength(1));
      final m = out.single;
      expect(m.id, o.id);
      expect(m.position, o.position, reason: 'precise official position wins');
      expect(m.title, '新宿駅東口公衆喫煙所');
      expect(m.isCovered, isTrue, reason: 'OSM attributes are kept');
      expect(m.osmElement, 'node/9');
      expect(m.source, contains('OpenStreetMap'));
    });

    test('geocoded official entry takes the surveyed OSM position', () {
      final o = official('1', _shinjuku, geocoded: true);
      final xPos = _d.offset(_shinjuku, 40, 0);
      final out = SmokingAreaRepository.merge([o, osm('9', xPos)]);
      expect(out, hasLength(1));
      expect(out.single.position, xPos);
      expect(out.single.isApproximate, isFalse);
    });

    test('precise official entry and distant OSM point stay separate', () {
      final out = SmokingAreaRepository.merge([
        official('1', _shinjuku),
        osm('9', _d.offset(_shinjuku, 40, 0)),
      ]);
      expect(out, hasLength(2));
    });

    test('matching is 1:1 – two booths next to each other stay two', () {
      final a = official('1', _shinjuku);
      final b = official('2', _d.offset(_shinjuku, 12, 90));
      final x = osm('9', _d.offset(_shinjuku, 2, 90));
      final out = SmokingAreaRepository.merge([a, b, x]);
      expect(out.map((e) => e.id), unorderedEquals([a.id, b.id]));
      expect(out.firstWhere((e) => e.id == a.id).osmElement, 'node/9');
      expect(out.firstWhere((e) => e.id == b.id).osmElement, isNull);
    });

    test('same id is only shown once', () {
      final x = osm('9', _shinjuku);
      expect(SmokingAreaRepository.merge([x, x]), hasLength(1));
    });
  });

  group('official snapshot', () {
    final file = File('assets/opendata/official_smoking_areas.json');
    final source =
        OfficialOpenDataSource(loader: () => file.readAsString());

    test('contains the important Tokyo districts, Kyoto and Osaka', () async {
      final tokyo = await source.fetch(cityById('tokyo')!.bounds);
      final datasets = tokyo.map((a) => a.tags['official:dataset']).toSet();
      expect(
        datasets,
        containsAll([
          'tokyo_chiyoda', // Kanda, Akihabara
          'tokyo_shinjuku',
          'tokyo_shibuya',
          'tokyo_toshima', // Ikebukuro
          'tokyo_taito',
          'tokyo_koto',
        ]),
      );
      expect(tokyo.every((a) => a.isOfficial), isTrue);
      expect(await source.fetch(cityById('kyoto')!.bounds), isNotEmpty);
      expect(await source.fetch(cityById('osaka')!.bounds), hasLength(greaterThan(100)));
    });

    test('Akihabara has official smoking areas near the station', () async {
      const akihabara = LatLng(35.6984, 139.7731);
      final all = await source.fetch(cityById('tokyo')!.bounds);
      final near = all.where((a) => _d(akihabara, a.position) < 600);
      expect(near.length, greaterThanOrEqualTo(3));
    });

    test('no two entries of one dataset share a position', () async {
      final all = <SmokingArea>[];
      for (final c in ['tokyo', 'osaka', 'kyoto']) {
        all.addAll(await source.fetch(cityById(c)!.bounds));
      }
      final seen = <String>{};
      for (final a in all) {
        final key = '${a.tags['official:dataset']}'
            '${a.latitude.toStringAsFixed(5)},${a.longitude.toStringAsFixed(5)}';
        expect(seen.add(key), isTrue, reason: 'duplicate marker: ${a.title}');
      }
    });
  });

  group('repository with official + live source', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('sa_merge'));
    tearDown(() => tmp.deleteSync(recursive: true));

    final city = cityById('tokyo')!;
    final off = OfficialOpenDataSource(
      loader: () async => '''
{"generated":"2026-11-09","sources":[{"id":"tokyo_shinjuku","name":"x","url":"https://example.org","license":"CC BY"}],
 "areas":[{"id":"tokyo_shinjuku:1","source":"tokyo_shinjuku","name":"A","lat":35.693,"lon":139.7001}]}''',
    );

    test('OSM offline on first start: official data shown, retried later',
        () async {
      final live = _FakeSource('osm', [osm('1', const LatLng(35.70, 139.70))])
        ..fail = true;
      final repo = SmokingAreaRepository(
          sources: [off, live], cacheDirectory: () async => tmp);
      final first = await repo.load(city);
      expect(first.areas.map((a) => a.id), ['tokyo_shinjuku:1']);
      expect(first.errors, isNotEmpty);

      live.fail = false;
      final second = await repo.load(city);
      expect(live.calls, 2, reason: 'partial result must not be cached as fresh');
      expect(second.areas, hasLength(2));
    });

    test('OSM offline later: cached OSM data of that source is kept',
        () async {
      final live = _FakeSource('osm', [osm('1', const LatLng(35.70, 139.70))]);
      final repo1 = SmokingAreaRepository(
          sources: [off, live], cacheDirectory: () async => tmp);
      expect((await repo1.load(city)).areas, hasLength(2));

      live.fail = true;
      final repo2 = SmokingAreaRepository(
          sources: [off, live], cacheDirectory: () async => tmp);
      final offline = await repo2.load(city, forceRefresh: true);
      expect(offline.areas, hasLength(2));
      expect(offline.fromCache, isTrue);
    });
  });
}
