import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/closure_policy.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/existence_policy.dart';
import 'package:smoking_areas/community/models.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/data/cities.dart';
import 'package:smoking_areas/models/data_fingerprint.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/sources/official_opendata_source.dart';

final t0 = DateTime(2026, 11, 11, 12);

/// One official entry as the bundled snapshot would contain it.
Future<SmokingArea> officialEntry({
  String hours = '24h',
  bool closed = false,
}) async {
  final source = OfficialOpenDataSource(
    loader: () async => jsonEncode({
      'generated': '2026-11-11',
      'sources': [
        {'id': 'tokyo_shinjuku', 'name': 'x', 'url': 'https://e.x', 'license': 'CC BY'},
      ],
      'areas': [
        {
          'id': 'tokyo_shinjuku:habc',
          'source': 'tokyo_shinjuku',
          'name': '新宿駅東口公衆喫煙所',
          'lat': 35.693,
          'lon': 139.7001,
          'hours': hours,
          if (closed) 'temporarily_closed': true,
        },
      ],
    }),
  );
  return (await source.fetch(cityById('tokyo')!.bounds)).single;
}

ExistenceVote vote(String user, bool exists, DateTime at, String? fp) =>
    ExistenceVote(
        spotId: 's', userId: user, exists: exists, createdAt: at, fingerprint: fp);

ClosureReport closure(bool closed, DateTime at, String? fp) => ClosureReport(
    spotId: 's', userId: 'u', closed: closed, createdAt: at, fingerprint: fp);

void main() {
  group('fingerprint', () {
    test('official entries get one that changes with their content', () async {
      final a = await officialEntry();
      final b = await officialEntry();
      final c = await officialEntry(hours: '7:00-22:00');
      expect(a.sourceFingerprint, isNotNull);
      expect(a.sourceFingerprint, b.sourceFingerprint);
      expect(a.sourceFingerprint, isNot(c.sourceFingerprint));
    });

    test('OSM fingerprint ignores tags added by the app', () {
      final osm = SmokingArea(
        id: 'osm:node/1',
        position: const LatLng(35.69, 139.70),
        source: 'OpenStreetMap',
        tags: const {'amenity': 'smoking_area', 'covered': 'yes'},
      ).withOsmFingerprint();
      final annotated = SmokingArea(
        id: osm.id,
        position: osm.position,
        source: osm.source,
        tags: {
          for (final e in osm.tags.entries)
            if (e.key != fingerprintTag) e.key: e.value,
          'aliases': 'community:1',
          'community:by': 'Me',
          'temporarily_closed': 'yes',
        },
      ).withOsmFingerprint();
      expect(annotated.sourceFingerprint, osm.sourceFingerprint);

      final edited = SmokingArea(
        id: osm.id,
        position: osm.position,
        source: osm.source,
        tags: const {'amenity': 'smoking_area', 'covered': 'no'},
      ).withOsmFingerprint();
      expect(edited.sourceFingerprint, isNot(osm.sourceFingerprint));
    });
  });

  group('ExistencePolicy with data versions', () {
    const policy = ExistencePolicy();
    final later = t0.add(const Duration(days: 400));

    test('votes for the current data version do not expire', () {
      final votes = [for (final u in ['a', 'b', 'c']) vote(u, false, t0, 'v1')];
      expect(policy.evaluate(votes, now: later, currentFingerprint: 'v1').hidden,
          isTrue);
    });

    test('a changed source entry restarts the evaluation', () {
      final votes = [for (final u in ['a', 'b', 'c']) vote(u, false, t0, 'v1')];
      final s = policy.evaluate(votes, now: t0, currentFingerprint: 'v2');
      expect(s.hidden, isFalse);
      expect(s.removals, 0);
    });

    test('votes without data version keep the 180-day expiry', () {
      final votes = [for (final u in ['a', 'b', 'c']) vote(u, false, t0, null)];
      expect(policy.evaluate(votes, now: later, currentFingerprint: 'v1').hidden,
          isFalse);
      expect(policy.evaluate(votes, now: t0).hidden, isTrue);
    });
  });

  group('ClosurePolicy with data versions', () {
    const policy = ClosurePolicy();
    final in30Days = t0.add(const Duration(days: 30));

    test('"open again" beats an official closure while the data is unchanged',
        () {
      final s = policy.evaluate([closure(false, t0, 'v1')],
          now: in30Days, currentFingerprint: 'v1', officiallyClosed: true);
      expect(s.reopenedReports, 1, reason: 'still active after 30 days');
    });

    test('"open again" ends when the official entry changes', () {
      final s = policy.evaluate([closure(false, t0, 'v1')],
          now: t0, currentFingerprint: 'v2', officiallyClosed: true);
      expect(s.reopenedReports, 0);
    });

    test('"closed" on an officially open spot still expires after 14 days', () {
      final reports = [closure(true, t0, 'v1')];
      expect(
          policy.evaluate(reports,
              now: t0.add(const Duration(days: 13)), currentFingerprint: 'v1')
              .closed,
          isTrue);
      expect(policy.evaluate(reports, now: in30Days, currentFingerprint: 'v1').closed,
          isFalse);
    });
  });

  group('end to end with the community service', () {
    late Directory tmp;
    late CommunityService service;
    late DateTime now;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('data_version');
      SharedPreferences.setMockInitialValues({});
      final backend = LocalCommunityBackend(() async => tmp);
      final auth = LocalAuthService(backend,
          prefs: await SharedPreferences.getInstance());
      await auth.init();
      now = t0;
      service = CommunityService(
          backend: backend,
          photos: LocalPhotoStorage(() async => tmp),
          auth: auth,
          clock: () => now);
      await service.init();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('spot reported gone stays hidden across data updates until the '
        'official entry changes', () async {
      final v1 = await officialEntry();
      for (final u in ['A', 'B', 'C']) {
        await service.createUser(u);
        await service.vote(v1, exists: false);
      }
      expect(service.isHidden(v1), isTrue);

      now = t0.add(const Duration(days: 400));
      final sameAgain = await officialEntry(); // next release, unchanged
      expect(service.isHidden(sameAgain), isTrue,
          reason: 'the community wins over the unchanged data set');

      final changed = await officialEntry(hours: '7:00-22:00');
      expect(service.isHidden(changed), isFalse,
          reason: 'the city updated the entry – evaluate again');
    });

    test('"open again" overrides a stale official closure until the entry '
        'changes', () async {
      final closedV1 = await officialEntry(closed: true);
      expect(service.annotate(closedV1).isTemporarilyClosed, isTrue);

      await service.reportClosure(closedV1, closed: false);
      now = t0.add(const Duration(days: 60));
      expect(service.annotate(await officialEntry(closed: true))
          .isTemporarilyClosed, isFalse,
          reason: 'still open after 60 days with unchanged data');

      final closedV2 = await officialEntry(closed: true, hours: 'new');
      expect(service.annotate(closedV2).isTemporarilyClosed, isTrue,
          reason: 'new official data – closure applies again');
    });
  });
}
