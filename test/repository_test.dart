import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/city.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/sources/overpass_source.dart';
import 'package:smoking_areas/sources/smoking_area_source.dart';

class FakeSource extends SmokingAreaSource {
  FakeSource(this.result, {this.fail = false});
  final List<SmokingArea> result;
  bool fail;
  int calls = 0;

  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake';
  @override
  String get attribution => 'fake';

  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    calls++;
    if (fail) throw SourceException('offline');
    return result;
  }
}

void main() {
  test('parses Overpass nodes and ways (center)', () {
    const body = '''
    {"elements":[
      {"type":"node","id":1,"lat":35.68,"lon":139.76,
       "tags":{"amenity":"smoking_area","name":"東京駅 喫煙所","covered":"yes"}},
      {"type":"way","id":2,"center":{"lat":35.69,"lon":139.70},
       "tags":{"amenity":"smoking_area","indoor":"room"}},
      {"type":"relation","id":3}
    ]}''';
    final areas = OverpassSource.parse(body);
    expect(areas, hasLength(2));
    expect(areas[0].id, 'osm:node/1');
    expect(areas[0].title, '東京駅 喫煙所');
    expect(areas[0].isCovered, isTrue);
    expect(areas[1].id, 'osm:way/2');
    expect(areas[1].isIndoor, isTrue);
    expect(areas[1].title, 'Raucherbereich');
  });

  test('query contains bbox and smoking tags', () {
    final q = OverpassSource.buildQuery(
        const GeoBounds(south: 1, west: 2, north: 3, east: 4));
    expect(q, contains('smoking_area'));
    expect(q, contains('1.00000,2.00000,3.00000,4.00000'));
    expect(q, contains('out center tags'));
  });

  test('every city is located in Japan and has a unique id', () {
    final ids = <String>{};
    for (final c in kCities) {
      expect(ids.add(c.id), isTrue, reason: c.id);
      expect(c.center.latitude, inInclusiveRange(24, 46), reason: c.id);
      expect(c.center.longitude, inInclusiveRange(122, 146), reason: c.id);
    }
    expect(cityForPosition(const LatLng(35.6895, 139.6917))?.id, 'tokyo');
    expect(cityForPosition(const LatLng(34.7025, 135.4959))?.id, 'osaka');
    expect(cityForPosition(const LatLng(48.137, 11.575)), isNull);
  });

  group('repository', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('sa_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    final area = SmokingArea(
      id: 'osm:node/1',
      position: const LatLng(35.68, 139.76),
      source: 'OpenStreetMap',
    );

    test('caches on disk and falls back to cache when offline', () async {
      final source = FakeSource([area]);
      final city = kCities.first;
      final repo1 = SmokingAreaRepository(
          sources: [source], cacheDirectory: () async => tmp);
      expect((await repo1.load(city)).areas, [area]);

      // New instance, fresh cache: no network call.
      final repo2 = SmokingAreaRepository(
          sources: [source], cacheDirectory: () async => tmp);
      final cached = await repo2.load(city);
      expect(cached.fromCache, isTrue);
      expect(source.calls, 1);

      // Forced refresh while offline: stale data instead of an error.
      source.fail = true;
      final offline = await repo2.load(city, forceRefresh: true);
      expect(offline.areas, [area]);
      expect(offline.errors, isNotEmpty);
    });

    test('throws if offline without cache', () async {
      final repo = SmokingAreaRepository(
          sources: [FakeSource([], fail: true)],
          cacheDirectory: () async => tmp);
      expect(repo.load(kCities.first), throwsA(isA<SourceException>()));
    });

    test('deduplicates nearby points from different sources', () {
      final other = SmokingArea(
        id: 'tokyo-opendata:42',
        position: const Distance().offset(area.position, 3, 90),
        source: 'Tokyo Open Data',
      );
      final distinct = SmokingArea(
        id: 'osm:node/9',
        position: const Distance().offset(area.position, 3, 90),
        source: 'OpenStreetMap',
      );
      final out =
          SmokingAreaRepository.deduplicate([area, area, other, distinct]);
      expect(out.map((a) => a.id), ['osm:node/1', 'osm:node/9']);
    });
  });
}
