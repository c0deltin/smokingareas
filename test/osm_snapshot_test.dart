import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/services/snapshot_updater.dart';
import 'package:smoking_areas/sources/osm_snapshot_source.dart';
import 'package:smoking_areas/sources/overpass_source.dart';

String export(String version, int count) => jsonEncode({
      'format': 1,
      'generated': version,
      'elements': [
        for (var i = 1; i <= count; i++)
          {
            'type': 'node',
            'id': i,
            'lat': 35.69 + i * 0.001,
            'lon': 139.70,
            'tags': {
              'amenity': i.isEven ? 'toilets' : 'smoking_area',
              'name': 'Spot $i',
            },
          },
      ],
    });

void main() {
  late Directory tmp;
  late SnapshotStore store;
  late OsmSnapshotSource osm;
  var requests = <String>[];

  http.Client server(String served) => MockClient((req) async {
        requests.add(req.url.pathSegments.last);
        if (req.url.path.endsWith('osm-manifest.json')) {
          final d = jsonDecode(served) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({
                'format': 1,
                'generated': d['generated'],
                'count': (d['elements'] as List).length,
              }),
              200);
        }
        if (req.url.path.endsWith('osm_spots.json.gz')) {
          return http.Response.bytes(gzip.encode(utf8.encode(served)), 200);
        }
        return http.Response('not found', 404);
      });

  SnapshotUpdater updater(http.Client client) => SnapshotUpdater(
        store: store,
        source: osm,
        client: client,
        baseUri: Uri.parse('https://example.org/opendata/'),
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('osm');
    store = SnapshotStore(() async => tmp,
        fileName: 'osm_snapshot.json', metaName: 'osm-meta.json');
    osm = OsmSnapshotSource(store.read);
    requests = [];
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('without an export the live Overpass fallback stays active', () async {
    final live = OverpassSource(isFallbackActive: () => !osm.hasData);
    expect(await osm.fetch(SmokingAreaRepository.japan), isEmpty);
    expect(await osm.version(), '');
    expect(live.covers(cityById('tokyo')!.bounds), isTrue);
  });

  test('the downloaded export replaces live queries', () async {
    final r = await updater(server(export('2026-11-11T18:00:00Z', 4))).check();
    expect(r.updated, isTrue);
    expect(requests, ['osm-manifest.json', 'osm_spots.json.gz']);

    final areas = await osm.fetch(SmokingAreaRepository.japan);
    expect(areas, hasLength(4));
    expect(areas.where((a) => a.category == SpotCategory.toilet), hasLength(2));
    expect(areas.first.id, 'osm:node/1');
    expect(areas.first.sourceFingerprint, isNotNull);

    final live = OverpassSource(isFallbackActive: () => !osm.hasData);
    expect(live.covers(cityById('tokyo')!.bounds), isFalse);
  });

  test('same version: only the manifest is fetched', () async {
    await updater(server(export('2026-11-11T18:00:00Z', 4))).check(force: true);
    requests.clear();
    final r = await updater(server(export('2026-11-11T18:00:00Z', 4)))
        .check(force: true);
    expect(r.updated, isFalse);
    expect(requests, ['osm-manifest.json']);
  });

  test('a much smaller export is refused', () async {
    await updater(server(export('2026-11-11T18:00:00Z', 10))).check(force: true);
    final r = await updater(server(export('2026-11-18T18:00:00Z', 2)))
        .check(force: true);
    expect(r.status, SnapshotUpdateStatus.failed);
    expect(await osm.fetch(SmokingAreaRepository.japan), hasLength(10));
  });

  test('an element from an older live cache is shown once', () async {
    await updater(server(export('2026-11-11T18:00:00Z', 2))).check();
    // Cache of an earlier version with live OSM data (key "osm").
    final dir = Directory('${tmp.path}/smoking_areas')..createSync();
    final cached = SmokingArea(
      id: 'osm:node/1',
      position: const LatLng(35.691, 139.70),
      source: 'OpenStreetMap',
      name: 'Old name',
      tags: const {'amenity': 'smoking_area'},
    );
    File('${dir.path}/tokyo.json').writeAsStringSync(jsonEncode({
      'schema': SmokingAreaRepository.cacheSchema,
      'fetchedAt': DateTime.now().toIso8601String(),
      'raw': {
        'osm': [cached.toJson()],
      },
    }));
    final repo = SmokingAreaRepository(
      sources: [osm, OverpassSource(isFallbackActive: () => !osm.hasData)],
      cacheDirectory: () async => tmp,
    );
    await repo.warmUp();
    final spot = repo.allVisible.where((a) => a.id == 'osm:node/1');
    expect(spot, hasLength(1));
    expect(spot.single.name, 'Spot 1', reason: 'the export wins');
  });

  test('several data sets: updated when any of them was', () async {
    final both = DataUpdaters([
      _Fixed(SnapshotUpdateStatus.upToDate),
      _Fixed(SnapshotUpdateStatus.updated),
    ]);
    expect((await both.check()).updated, isTrue);
  });
}

class _Fixed implements DataUpdater {
  _Fixed(this.status);
  final SnapshotUpdateStatus status;
  @override
  Future<SnapshotUpdateResult> check({bool force = false}) async =>
      SnapshotUpdateResult(status);
}
