import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/community/auth_service.dart';
import 'package:smoking_areas/community/community_backend.dart';
import 'package:smoking_areas/community/community_service.dart';
import 'package:smoking_areas/community/photo_storage.dart';
import 'package:smoking_areas/models/smoking_area.dart';
import 'package:smoking_areas/services/smoking_area_repository.dart';
import 'package:smoking_areas/ui/spot_style.dart';

const _d = Distance();
const _p = LatLng(35.6909, 139.7003);
LatLng east(double m) => _d.offset(_p, m, 90);

SmokingArea report(String id, LatLng p,
        {bool toilet = false, Map<String, String> extra = const {}}) =>
    SmokingArea(
      id: 'community:$id',
      position: p,
      source: 'Community',
      name: 'Ecke am Bahnhof',
      tags: {
        'community': 'yes',
        'community:by': 'Me',
        if (toilet) 'amenity': 'toilets',
        ...extra,
      },
    );

SmokingArea official(String id, LatLng p,
        {Map<String, String> extra = const {}}) =>
    SmokingArea(
      id: 'tokyo_shinjuku:$id',
      position: p,
      source: 'Tokyo, Shinjuku ward',
      name: '新宿駅東口公衆喫煙所',
      tags: {'official': 'yes', 'opening_hours': '24/7', ...extra},
    );

SmokingArea osm(String id, LatLng p) => SmokingArea(
      id: 'osm:node/$id',
      position: p,
      source: 'OpenStreetMap',
      tags: const {'amenity': 'smoking_area'},
    );

void main() {
  group('user report becomes official / OSM', () {
    test('report next to an official entry is absorbed by it', () {
      final out = SmokingAreaRepository.merge(
          [report('1', east(12)), official('a', _p)]);
      expect(out, hasLength(1));
      final m = out.single;
      expect(m.id, 'tokyo_shinjuku:a');
      expect(m.isOfficial, isTrue);
      expect(m.title, '新宿駅東口公衆喫煙所');
      expect(m.position, _p, reason: 'official position wins');
      expect(m.allIds, contains('community:1'));
      expect(SpotMarker.fromArea(m).origin, SpotOrigin.official,
          reason: 'gold ring, not pink');
    });

    test('report next to an OSM point is absorbed instead of dropped', () {
      final out =
          SmokingAreaRepository.merge([report('1', east(3)), osm('9', _p)]);
      expect(out, hasLength(1));
      final m = out.single;
      expect(m.id, 'osm:node/9');
      expect(m.allIds, contains('community:1'));
      expect(m.tags['community:by'], 'Me', reason: 'reporter is kept');
      expect(SpotMarker.fromArea(m).origin, SpotOrigin.osm);
    });

    test('report merges with the official+OSM entry at the same place', () {
      final out = SmokingAreaRepository.merge(
          [official('a', _p), osm('9', east(5)), report('1', east(10))]);
      expect(out, hasLength(1));
      expect(out.single.allIds,
          containsAll(['tokyo_shinjuku:a', 'osm:node/9', 'community:1']));
    });

    test('user details only fill gaps', () {
      final out = SmokingAreaRepository.merge([
        official('a', _p, extra: const {'covered': 'no'}),
        report('1', east(5),
            extra: const {'covered': 'yes', 'access': 'customers'}),
      ]);
      final m = out.single;
      expect(m.isCovered, isFalse, reason: 'official value wins');
      expect(m.isPublic, isFalse, reason: 'gap filled by the user');
      expect(m.openingHours, '24/7');
    });

    test('user position beats a geocoded address', () {
      final out = SmokingAreaRepository.merge([
        official('a', _p, extra: const {'geocoded': 'yes'}),
        report('1', east(20)),
      ]);
      expect(out.single.position, east(20));
      expect(out.single.isApproximate, isFalse);
    });

    test('no merge across categories or beyond 25 m', () {
      expect(
          SmokingAreaRepository.merge(
              [official('a', _p), report('1', east(5), toilet: true)]),
          hasLength(2));
      expect(
          SmokingAreaRepository.merge([official('a', _p), report('1', east(40))]),
          hasLength(2));
    });

    test('1:1 – only the closest of two reports is absorbed', () {
      final out = SmokingAreaRepository.merge(
          [official('a', _p), report('far', east(20)), report('near', east(4))]);
      expect(out, hasLength(2));
      final m = out.firstWhere((a) => a.isOfficial);
      expect(m.allIds, contains('community:near'));
      expect(out.where((a) => a.id == 'community:far'), hasLength(1));
    });
  });

  group('"No, report new" is respected', () {
    test('a report is never merged with a place the user rejected', () {
      final r = report('1', east(5),
          extra: const {'community:not_same_as': 'tokyo_shinjuku:a'});
      expect(SmokingAreaRepository.merge([official('a', _p), r]), hasLength(2));
    });

    test('rejection by alias also counts', () {
      final r = report('1', east(5),
          extra: const {'community:not_same_as': 'osm:node/9'});
      expect(
          SmokingAreaRepository.merge(
              [official('a', _p), osm('9', east(2)), r]),
          hasLength(2),
          reason: 'official+OSM entry carries the rejected OSM id');
    });

    test('it can still merge with another place that appears later', () {
      // Official at 0 m, report at 20 m, a new OSM point at 35 m: the OSM
      // point is too far from the official entry to merge with it, but
      // 15 m from the report.
      final r = report('1', east(20),
          extra: const {'community:not_same_as': 'tokyo_shinjuku:a'});
      final out =
          SmokingAreaRepository.merge([official('a', _p), osm('7', east(35)), r]);
      expect(out, hasLength(2));
      expect(out.firstWhere((a) => a.id == 'osm:node/7').allIds,
          contains('community:1'));
    });
  });

  group('community data moves along', () {
    late Directory tmp;
    late CommunityService service;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('report_merge');
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

    test('the rejection is stored with the report', () async {
      await service.reportSpot(
          position: east(5), name: 'Neu', notSameAs: {'tokyo_shinjuku:a'});
      final area = service.spotsAsAreas.single;
      expect(area.tags['community:not_same_as'], 'tokyo_shinjuku:a');
      final stored =
          (await LocalCommunityBackend(() async => tmp).spots()).single;
      expect(stored.notSameAs, ['tokyo_shinjuku:a']);
      expect(SmokingAreaRepository.merge([official('a', _p), area]),
          hasLength(2));
    });

    test('rating, photo and "gone" votes follow the report into the '
        'official entry', () async {
      final spot = await service.reportSpot(position: east(10), name: 'Ecke');
      final reported = service.spotsAsAreas.single;
      await service.rate(reported, 5, comment: 'sauber');
      final photo = File('${tmp.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      await service.addPhoto(reported, photo);
      for (final u in ['A', 'B', 'C']) {
        await service.createUser(u);
        await service.vote(reported, exists: false);
      }

      final repo = SmokingAreaRepository(
          sources: const [], cacheDirectory: () async => tmp);
      repo.setCommunity(
        spots: [official('a', _p), ...service.spotsAsAreas],
        isHidden: service.isHidden,
        annotate: service.annotate,
      );
      final merged = SmokingAreaRepository.merge(
          [official('a', _p), ...service.spotsAsAreas]).single;
      expect(merged.allIds, contains(spot.id));
      expect(service.ratingFor(merged).average, 5);
      expect(service.photosFor(merged), hasLength(1));
      expect(service.isHidden(merged), isTrue,
          reason: '3 "gone" votes on the report still count');
      expect(repo.allVisible, isEmpty);
    });
  });
}
