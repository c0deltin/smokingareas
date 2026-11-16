import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/models/city.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/osm_tiles.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/services/snapshot_updater.dart';
import 'package:smoking_areas/sources/smoking_area_source.dart';

Map<String, dynamic> _node(int id, double lat, double lon,
        [String amenity = 'toilets']) =>
    {
      'type': 'node',
      'id': id,
      'lat': lat,
      'lon': lon,
      'tags': {'amenity': amenity},
      'p': '13',
    };

/// A tiles file as published by `update_osm.py`.
List<int> tilesFile(String generated, Map<String, List<Map<String, dynamic>>> tiles,
    {int? count}) {
  final total = tiles.values.fold(0, (a, b) => a + b.length);
  final lines = [
    jsonEncode({
      'format': 2,
      'generated': generated,
      'count': count ?? total,
      'tiles': tiles.length,
    }),
    for (final e in tiles.entries) '${e.key}\t${jsonEncode(e.value)}',
  ];
  return gzip.encode(utf8.encode('${lines.join('\n')}\n'));
}

final _tokyo = {
  '35_139': [_node(1, 35.68, 139.76), _node(2, 35.69, 139.70, 'smoking_area')],
  '34_133': [_node(3, 34.59, 133.77)], // Kurashiki
};

class _OsmCities extends SmokingAreaSource {
  int calls = 0;
  @override
  String get id => 'osm';
  @override
  String get displayName => 'OSM cities';
  @override
  String get attribution => 'osm';
  @override
  bool get isBundled => true;
  @override
  Future<List<SmokingArea>> fetch(GeoBounds bounds) async {
    calls++;
    return [
      const SmokingArea(
          id: 'osm:node/99',
          position: LatLng(35.6, 139.6),
          source: 'OpenStreetMap',
          tags: {'amenity': 'smoking_area'}),
      // Sapporo: no tile in the test data.
      const SmokingArea(
          id: 'osm:node/98',
          position: LatLng(43.06, 141.35),
          source: 'OpenStreetMap',
          tags: {'amenity': 'toilets'}),
    ];
  }
}

void main() {
  late Directory tmp;
  late OsmTileStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tiles');
    store = OsmTileStore(() async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('tile ids', () {
    expect(OsmTileStore.tileOf(const LatLng(35.68, 139.76)), '35_139');
    expect(
        OsmTileStore.tilesIn(
            const GeoBounds(south: 34.9, west: 139.5, north: 35.2, east: 140.1)),
        ['34_139', '34_140', '35_139', '35_140']);
  });

  test('installs a tiles file and loads single tiles', () async {
    final index =
        await store.install(Stream.value(tilesFile('2026-11-16T00:00:00Z', _tokyo)));
    expect(index.count, 3);
    expect(index.tiles, {'35_139': 2, '34_133': 1});
    expect(await store.version(), '2026-11-16T00:00:00Z');

    final areas = await store.load('35_139');
    expect(areas.map((a) => a.id), ['osm:node/1', 'osm:node/2']);
    expect(areas.first.category, SpotCategory.toilet);
    expect(areas.first.tags['data:fingerprint'], isNotNull);
    expect(await store.load('40_140'), isEmpty);

    // Read back by a new store (app restart).
    final again = OsmTileStore(() async => tmp);
    expect((await again.index())?.count, 3);
  });

  test('a broken file never replaces the installed tiles', () async {
    await store.install(Stream.value(tilesFile('2026-11-16T00:00:00Z', _tokyo)));
    await expectLater(
        store.install(Stream.value(
            tilesFile('2026-11-23T00:00:00Z', _tokyo, count: 10))),
        throwsFormatException);
    await expectLater(
        store.install(Stream.value(tilesFile('2026-11-23T00:00:00Z', _tokyo)),
            expectedVersion: '2026-11-30T00:00:00Z'),
        throwsFormatException);
    expect(await store.version(), '2026-11-16T00:00:00Z');
    expect(await store.load('34_133'), hasLength(1));
    // No temporary directories are left behind.
    final left = Directory('${tmp.path}/opendata/osm_tiles')
        .listSync()
        .map((e) => e.path.split('/').last);
    expect(left, ['current']);
  });

  test('bundled tiles are installed only when newer', () async {
    final v1 = tilesFile('2026-11-16T00:00:00Z', _tokyo);
    expect(await OsmTileStore.versionOf(Stream.value(v1)), '2026-11-16T00:00:00Z');
    expect(await installBundledTiles(store, () async => v1), isTrue);
    expect(await installBundledTiles(store, () async => v1), isFalse);
    expect(await installBundledTiles(store, () async => <int>[]), isFalse);
    expect(await installBundledTiles(store, () async => null), isFalse);
  });

  group('updater', () {
    http.Client server(Map<String, dynamic> manifest, List<int> data) =>
        MockClient((req) async {
          if (req.url.path.endsWith(OsmTileUpdater.manifestName)) {
            return http.Response(jsonEncode(manifest), 200);
          }
          if (req.url.path.endsWith(OsmTileUpdater.dataName)) {
            return http.Response.bytes(data, 200);
          }
          return http.Response('', 404);
        });

    test('downloads newer tiles and reports them', () async {
      var reloaded = 0;
      final updater = OsmTileUpdater(
        store: store,
        onUpdated: () async => reloaded++,
        client: server({
          'format': 2,
          'generated': '2026-11-16T00:00:00Z',
          'count': 3,
        }, tilesFile('2026-11-16T00:00:00Z', _tokyo)),
      );
      final r = await updater.check(force: true);
      expect(r.status, SnapshotUpdateStatus.updated);
      expect(reloaded, 1);
      expect(await store.version(), '2026-11-16T00:00:00Z');
      expect((await updater.check(force: true)).status,
          SnapshotUpdateStatus.upToDate);
      // At most once a day without force.
      expect((await updater.check()).status, SnapshotUpdateStatus.skipped);
    });

    test('keeps the data for formats it does not know', () async {
      final updater = OsmTileUpdater(
        store: store,
        client: server({
          'format': 3,
          'generated': '2026-11-16T00:00:00Z',
          'count': 3,
        }, tilesFile('2026-11-16T00:00:00Z', _tokyo)),
      );
      expect((await updater.check(force: true)).status,
          SnapshotUpdateStatus.upToDate);
      expect(await store.version(), '');
    });
  });

  group('repository', () {
    test('loads the tiles of a region instead of the city-only data',
        () async {
      await store.install(Stream.value(tilesFile('2026-11-16T00:00:00Z', _tokyo)));
      final cities = _OsmCities();
      final repo = SmokingAreaRepository(
        sources: [cities],
        cacheDirectory: () async => tmp,
        tiles: store,
      );
      await repo.warmUp();
      expect(repo.usesTiles, isTrue);
      // City data only where there are no tiles (Sapporo here).
      expect(repo.allVisible.map((a) => a.id), ['osm:node/98']);

      // Kurashiki – not one of the cities, but in the tiles.
      await repo.ensureRegion(
          GeoBounds.around(const LatLng(34.59, 133.77), 1));
      expect(repo.allVisible.map((a) => a.id).toSet(),
          {'osm:node/3', 'osm:node/98'});
      expect(repo.loadedTiles, ['34_133']);
    });

    test('keeps at most maxTiles, dropping the least recently used',
        () async {
      await store.install(Stream.value(tilesFile('2026-11-16T00:00:00Z', {
        ..._tokyo,
        '43_141': [_node(4, 43.06, 141.35)], // Sapporo
      })));
      final repo = SmokingAreaRepository(
          sources: const [],
          cacheDirectory: () async => tmp,
          tiles: store,
          maxTiles: 2);
      await repo.ensureRegion(GeoBounds.around(const LatLng(35.68, 139.76), 1));
      await repo.ensureRegion(GeoBounds.around(const LatLng(34.59, 133.77), 1));
      await repo.ensureRegion(GeoBounds.around(const LatLng(35.68, 139.76), 1));
      await repo.ensureRegion(GeoBounds.around(const LatLng(43.06, 141.35), 1));
      expect(repo.loadedTiles, ['35_139', '43_141']);
      expect(repo.allVisible.map((a) => a.id).toSet(),
          {'osm:node/1', 'osm:node/2', 'osm:node/4'});

      // Zoomed out over more tiles than maxTiles: nothing new is loaded.
      await repo.ensureRegion(
          const GeoBounds(south: 30, west: 128, north: 45, east: 146));
      expect(repo.loadedTiles, ['35_139', '43_141']);
    });

    test('without tiles the city-only data is used', () async {
      final cities = _OsmCities();
      final repo = SmokingAreaRepository(
        sources: [cities],
        cacheDirectory: () async => tmp,
        tiles: store,
      );
      await repo.warmUp();
      expect(repo.usesTiles, isFalse);
      expect(repo.allVisible.map((a) => a.id).toSet(),
          {'osm:node/99', 'osm:node/98'});

      // Tiles arrive (bundled install or update): the city data goes.
      await store.install(Stream.value(tilesFile('2026-11-16T00:00:00Z', _tokyo)));
      await repo.ensureRegion(GeoBounds.around(const LatLng(35.68, 139.76), 1));
      await repo.reloadTiles();
      expect(repo.usesTiles, isTrue);
      // Tokyo from the tiles; Sapporo (no tile) keeps its city data.
      expect(repo.allVisible.map((a) => a.id).toSet(),
          {'osm:node/1', 'osm:node/2', 'osm:node/98'});
    });
  });
}
