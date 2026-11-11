import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/services/snapshot_updater.dart';
import 'package:smoking_areas/sources/official_opendata_source.dart';

String snapshot(String version, int count, {int format = 1}) => jsonEncode({
      'format': format,
      'generated': version,
      'sources': [
        {'id': 'tokyo_x', 'name': 'x', 'url': 'https://e.x', 'license': 'CC BY'},
      ],
      'areas': [
        for (var i = 0; i < count; i++)
          {
            'id': 'tokyo_x:h$i',
            'source': 'tokyo_x',
            'name': 'Spot $i',
            'lat': 35.69 + i * 0.001,
            'lon': 139.70,
          },
      ],
    });

Map<String, dynamic> manifestFor(String json) {
  final d = jsonDecode(json) as Map<String, dynamic>;
  return {
    'format': d['format'],
    'generated': d['generated'],
    'count': (d['areas'] as List).length,
  };
}

void main() {
  late Directory tmp;
  late SnapshotStore store;
  late OfficialOpenDataSource source;
  final bundled = snapshot('2026-11-11', 10);
  var requests = <String>[];

  /// Fake GitHub release: serves [manifest] and the gzip of [served].
  http.Client server({
    required String served,
    Map<String, dynamic>? manifest,
    int status = 200,
    List<int>? rawSnapshot,
  }) =>
      MockClient((req) async {
        requests.add(req.url.pathSegments.last);
        if (status != 200) return http.Response('error', status);
        if (req.url.path.endsWith('opendata-manifest.json')) {
          return http.Response(jsonEncode(manifest ?? manifestFor(served)), 200);
        }
        return http.Response.bytes(
            rawSnapshot ?? gzip.encode(utf8.encode(served)), 200);
      });

  SnapshotUpdater updater(http.Client client, {DateTime? now}) =>
      SnapshotUpdater(
        store: store,
        source: source,
        client: client,
        baseUri: Uri.parse('https://example.org/opendata/'),
        clock: now == null ? null : () => now,
      );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('snapshots');
    store = SnapshotStore(() async => tmp);
    source = OfficialOpenDataSource(
        loader: store.preferNewer(() async => bundled));
    requests = [];
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('version is read without parsing the whole file', () {
    expect(snapshotVersion(bundled), '2026-11-11');
  });

  test('newer data is downloaded, validated and used', () async {
    final newer = snapshot('2026-11-20T03:00:00Z', 12);
    final r = await updater(server(served: newer)).check();
    expect(r.updated, isTrue);
    expect(r.version, '2026-11-20T03:00:00Z');
    expect(await source.version(), '2026-11-20T03:00:00Z');
    expect(await source.allAreas(), hasLength(12));
  });

  test('same version: only the manifest is fetched', () async {
    final r = await updater(server(served: bundled)).check();
    expect(r.status, SnapshotUpdateStatus.upToDate);
    expect(requests, ['opendata-manifest.json']);
  });

  test('checks at most once a day unless forced', () async {
    final now = DateTime(2026, 11, 20, 12);
    final u = updater(server(served: bundled), now: now);
    await u.check();
    expect((await u.check()).status, SnapshotUpdateStatus.skipped);
    expect((await u.check(force: true)).status, SnapshotUpdateStatus.upToDate);
  });

  group('bad downloads never replace the data', () {
    Future<void> expectRejected(http.Client client) async {
      final r = await updater(client).check();
      expect(r.status, SnapshotUpdateStatus.failed, reason: r.error);
      expect(await store.read(), isNull);
      expect(await source.version(), '2026-11-11');
    }

    test('count does not match the manifest', () async {
      final newer = snapshot('2026-11-20T03:00:00Z', 12);
      await expectRejected(server(
          served: newer, manifest: {...manifestFor(newer), 'count': 99}));
    });

    test('suspiciously small (less than half the current data)', () async {
      await expectRejected(
          server(served: snapshot('2026-11-20T03:00:00Z', 3)));
    });

    test('corrupt gzip', () async {
      await expectRejected(server(
          served: snapshot('2026-11-20T03:00:00Z', 12),
          rawSnapshot: [1, 2, 3, 4]));
    });

    test('server error', () async {
      await expectRejected(server(served: bundled, status: 503));
    });
  });

  test('a format this app does not understand is ignored', () async {
    final future = snapshot('2027-01-01T00:00:00Z', 12, format: 2);
    final r = await updater(server(served: future)).check();
    expect(r.status, SnapshotUpdateStatus.upToDate);
    expect(requests, ['opendata-manifest.json']);
  });

  test('the bundled snapshot wins when it is newer (app update)', () async {
    await store.write(snapshot('2026-11-01', 10));
    expect(await source.version(), '2026-11-11');
  });

  test('repository shows the new data without a restart', () async {
    final repo = SmokingAreaRepository(
        sources: [source], cacheDirectory: () async => tmp);
    await repo.warmUp();
    expect(repo.areasIn(cityById('tokyo')!.bounds), hasLength(10));

    final r = await updater(
            server(served: snapshot('2026-11-20T03:00:00Z', 12)))
        .check();
    expect(r.updated, isTrue);
    await repo.reloadBundled();
    expect(repo.areasIn(cityById('tokyo')!.bounds), hasLength(12));
  });
}
